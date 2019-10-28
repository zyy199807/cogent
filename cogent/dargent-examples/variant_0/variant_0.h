// This file is generated by Cogent

#ifndef VARIANT_0_H__
#define VARIANT_0_H__

#include <cogent-defns.h>

enum {
    LET_TRUE = 1,
} ;
enum {
    LETBANG_TRUE = 1,
} ;
enum tag_t {
    TAG_ENUM_A,
    TAG_ENUM_B,
    TAG_ENUM_C,
    TAG_ENUM_D,
    TAG_ENUM_E,
} ;
typedef enum tag_t tag_t;
enum untyped_func_enum {
    FUN_ENUM_getVals,
    FUN_ENUM_putVals,
} ;
typedef enum untyped_func_enum untyped_func_enum;
typedef untyped_func_enum t48;
#define FUN_DISP_MACRO_dispatch_t48(a1, a2, a3)\
{\
    {\
        a1 = putVals(a3);\
    }\
}
typedef untyped_func_enum t49;
#define FUN_DISP_MACRO_dispatch_t49(a1, a2, a3)\
{\
    {\
        a1 = getVals(a3);\
    }\
}
struct t1 {
    unsigned int data[5U];
} ;
typedef struct t1 t1;
struct t2 {
    tag_t tag;
    u8 A;
} ;
typedef struct t2 t2;
struct t8 {
    tag_t tag;
    u8 A;
    u16 B;
    u32 C;
    u64 D;
    bool_t E;
} ;
typedef struct t8 t8;
struct t25 {
    t2 a;
    t8 b;
} ;
typedef struct t25 t25;
struct t26 {
    t1 *p1;
    t25 p2;
} ;
typedef struct t26 t26;
static inline t26 getVals(t1 *);
static inline t1 *putVals(t1 *);
static inline t1 *dispatch_t48(untyped_func_enum a2, t1 *a3)
{
    return putVals(a3);
}
static inline t26 dispatch_t49(untyped_func_enum a2, t1 *a3)
{
    return getVals(a3);
}
typedef t1 Simple;
typedef t1 *getVals_arg;
typedef t26 getVals_ret;
typedef t1 *putVals_arg;
typedef t1 *putVals_ret;
#endif


