--
-- Copyright 2016, NICTA
--
-- This software may be distributed and modified according to the terms of
-- the GNU General Public License version 2. Note that NO WARRANTY is provided.
-- See "LICENSE_GPLv2.txt" for details.
--
-- @TAG(NICTA_GPL)
--

{-# LANGUAGE LambdaCase #-}

module Cogent.TypeCheck.Subst where

import Cogent.Common.Types
import Cogent.Compiler (__impossible)
import Cogent.Surface
import Cogent.TypeCheck.Assignment
import Cogent.TypeCheck.Base
import qualified Cogent.TypeCheck.Row as Row 
import Cogent.Util

import qualified Data.IntMap as M
import qualified Data.Map as DM
import Data.Bifunctor (second)
import Data.Maybe
import Data.Monoid hiding (Alt)
import Prelude hiding (lookup)

data AssignResult = Type TCType
                  | Sigil (Sigil (Maybe DataLayoutExpr))
                  | Row (Row.Row TCType)
                  | Taken Taken
                  | Expr SExpr
                  deriving Show

newtype Subst = Subst (M.IntMap AssignResult)
              deriving Show

ofType :: Int -> TCType -> Subst
ofType i t = Subst (M.fromList [(i, Type t)])

ofRow :: Int -> Row.Row TCType -> Subst 
ofRow i t = Subst (M.fromList [(i, Row t)])

ofSigil :: Int -> Sigil (Maybe DataLayoutExpr) -> Subst 
ofSigil i t = Subst (M.fromList [(i, Sigil t)])

ofTaken :: Int -> Taken -> Subst 
ofTaken i tk = Subst (M.fromList [(i, Taken tk)])

ofExpr :: Int -> SExpr -> Subst
ofExpr i e = Subst (M.fromList [(i, Expr e)])

substToAssign :: Subst -> Assignment
substToAssign (Subst m) = Assignment . M.map unExpr $ M.filter isAssign m
  where isAssign (Expr _) = True; isAssign _ = False
        unExpr   (Expr x) = x   ; unExpr   _ = __impossible "unExpr"

null :: Subst -> Bool
null (Subst x) = M.null x

#if __GLASGOW_HASKELL__ < 803
instance Monoid Subst where
  mempty = Subst M.empty
  mappend (Subst a) (Subst b) = Subst (a <> b)
#else
instance Semigroup Subst where
  Subst a <> Subst b = Subst (a <> b)
instance Monoid Subst where
  mempty = Subst M.empty
#endif

apply :: Subst -> TCType -> TCType
apply (Subst f) (U x)
  | Just (Type t) <- M.lookup x f
  = apply (Subst f) t
  | otherwise
  = U x
apply (Subst f) t@(V (Row.Row m' (Just x)))
  | Just (Row (Row.Row m q)) <- M.lookup x f = apply (Subst f) (V (Row.Row (DM.union m m') q))
apply (Subst f) t@(R (Row.Row m' (Just x)) s)
  | Just (Row (Row.Row m q)) <- M.lookup x f = apply (Subst f) (R (Row.Row (DM.union m m') q) s)
apply (Subst f) t@(R r (Right x))
  | Just (Sigil s) <- M.lookup x f = apply (Subst f) (R r (Left s))
apply f (V x) = V (applyToRow f x)
apply f (R x s) = R (applyToRow f x) s
apply f (A x l s) = A (apply f x) (assign (substToAssign f) l) s
apply f (T x) = T (fmap (apply f) x)
apply f (Synonym n ts) = Synonym n (fmap (apply f) ts)

applyToRow :: Subst -> Row.Row TCType -> Row.Row TCType
applyToRow (Subst f) r = apply (Subst f) <$> Row.mapEntries (second (second substTk)) r
  where
    substTk :: Either Taken Int -> Either Taken Int
    substTk (Left tk)  = Left tk
    substTk (Right u) | Just (Taken tk) <- M.lookup u f = Left tk
                      | otherwise = Right u

applyAlts :: Subst -> [Alt TCPatn TCExpr] -> [Alt TCPatn TCExpr]
applyAlts = map . applyAlt

applyAlt :: Subst -> Alt TCPatn TCExpr -> Alt TCPatn TCExpr
applyAlt s = fmap (applyE s) . ffmap (fmap (apply s))

applyCtx :: Subst -> ErrorContext -> ErrorContext
applyCtx s (SolvingConstraint c) = SolvingConstraint (applyC s c)
applyCtx s (InExpression e t) = InExpression e (apply s t)
applyCtx s c = c

applyErr :: Subst -> TypeError -> TypeError
applyErr s (TypeMismatch t1 t2)     = TypeMismatch (apply s t1) (apply s t2)
applyErr s (RequiredTakenField f t) = RequiredTakenField f (apply s t)
applyErr s (TypeNotShareable t m)   = TypeNotShareable (apply s t) m
applyErr s (TypeNotEscapable t m)   = TypeNotEscapable (apply s t) m
applyErr s (TypeNotDiscardable t m) = TypeNotDiscardable (apply s t) m
applyErr s (PatternsNotExhaustive t ts) = PatternsNotExhaustive (apply s t) ts
applyErr s (UnsolvedConstraint c os) = UnsolvedConstraint (applyC s c) os
applyErr s (NotAFunctionType t) = NotAFunctionType (apply s t)
applyErr s e = e

applyWarn :: Subst -> TypeWarning -> TypeWarning
applyWarn s (UnusedLocalBind v) = UnusedLocalBind v
applyWarn _ w = w

applyC :: Subst -> Constraint -> Constraint
applyC s (a :< b) = apply s a :< apply s b
applyC s (a :=: b) = apply s a :=: apply s b
applyC s (a :& b) = applyC s a :& applyC s b
applyC s (a :@ c) = applyC s a :@ applyCtx s c
applyC s (Upcastable a b) = apply s a `Upcastable` apply s b
applyC s (Share t m) = Share (apply s t) m
applyC s (Drop t m) = Drop (apply s t) m
applyC s (Escape t m) = Escape (apply s t) m
#ifdef BUILTIN_ARRAYS
applyC s (Arith e) = Arith $ assign (substToAssign s) e
#endif
applyC s (Unsat e) = Unsat (applyErr s e)
applyC s (SemiSat w) = SemiSat (applyWarn s w)
applyC s Sat = Sat
applyC s (Exhaustive t ps) = Exhaustive (apply s t) ps
applyC s (Solved t) = Solved (apply s t)
applyC s (IsPrimType t) = IsPrimType (apply s t)

applyE :: Subst -> TCExpr -> TCExpr
applyE s (TE t e l) = TE (apply s t)
                         ( fmap (fmap (apply s))
                         $ ffmap (fmap (apply s))
                         $ fffmap (fmap (apply s))
                         $ ffffmap (apply s) e)
                         l

