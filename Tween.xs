#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "const-c.inc"

#include <tweencee/tweencee.h>

/* ------------------------------ easing ----------------------------- */

static double (*ease_table[31]) (double) = {
    LinearInterpolation,
    QuadraticEaseIn,
    QuadraticEaseOut,
    QuadraticEaseInOut,
    CubicEaseIn,
    CubicEaseOut,
    CubicEaseInOut,
    QuarticEaseIn,
    QuarticEaseOut,
    QuarticEaseInOut,
    QuinticEaseIn,
    QuinticEaseOut,
    QuinticEaseInOut,
    SineEaseIn,
    SineEaseOut,
    SineEaseInOut,
    CircularEaseIn,
    CircularEaseOut,
    CircularEaseInOut,
    ExponentialEaseIn,
    ExponentialEaseOut,
    ExponentialEaseInOut,
    ElasticEaseIn,
    ElasticEaseOut,
    ElasticEaseInOut,
    BackEaseIn,
    BackEaseOut,
    BackEaseInOut,
    BounceEaseIn,
    BounceEaseOut,
    BounceEaseInOut
};

/* ------------------------------ path ------------------------------- */

#define PATH_FUNCS(kind)  \
    path_linear_##kind,   \
    path_sine_##kind,     \
    path_circular_##kind, \
    path_spiral_##kind

static void* (*path_build_table[5]) (SV*) = {
    PATH_FUNCS(build)
};

static void (*path_free_table[5]) (void*) = {
    PATH_FUNCS(free)
};

static int (*path_solve_table[5]) (void*, double, double[4]) = {
    PATH_FUNCS(solve)
};

/* ------------------------------ proxy ------------------------------- */

#define PROXY_FUNCS(kind) \
    proxy_method_##kind,  \
    proxy_array_##kind

static void* (*proxy_build_table[5]) (SV*) = {
    PROXY_FUNCS(build)
};

static void (*proxy_free_table[5]) (void*) = {
    PROXY_FUNCS(free)
};

static void (*proxy_set_table[5]) (void*, double[4], int dim) = {
    PROXY_FUNCS(set)
};

/* ------------------------------ tween ------------------------------- */



MODULE = SDLx::Tween		PACKAGE = SDLx::Tween		PREFIX = SDLx__Tween_

PROTOTYPES: DISABLE

INCLUDE: const-xs.inc

#define SELF_TO_THIS \
    SDLx__Tween this = (SDLx__Tween) SvIV((SV*)SvRV(self))

SDLx__Tween
SDLx__Tween_new_struct(register_cb, unregister_cb, duration, forever, repeat, bounce, ease, path, path_args, proxy, proxy_args)
    SV*    register_cb
    SV*    unregister_cb
    Uint32 duration
    bool   forever
    int    repeat
    bool   bounce
    int    ease
    int    path
    SV*    path_args
    int    proxy
    SV*    proxy_args
    CODE:
        SDLx__Tween this = (SDLx__Tween) safemalloc(sizeof(sdl_tween));
        if(this == NULL) { croak("unable to create new struct for SDLx::Tween"); }

        SV* register_cb_clone   = newSVsv(register_cb);
        SV* unregister_cb_clone = newSVsv(unregister_cb);

        this->ease_func = ease_table[ease];

        this->path_build_func = path_build_table[path];
        this->path_free_func  = path_free_table[path];
        this->path_solve_func = path_solve_table[path];

        this->path = this->path_build_func(path_args);

        this->proxy_build_func = proxy_build_table[proxy];
        this->proxy_free_func  = proxy_free_table[proxy];
        this->proxy_set_func   = proxy_set_table[proxy];

        this->proxy = this->proxy_build_func(proxy_args);

        build_struct(
            this,
            register_cb_clone,
            unregister_cb_clone,
            duration,
            forever,
            repeat,
            bounce
        );
        RETVAL = this;
    OUTPUT:
        RETVAL    

void
SDLx__Tween_DESTROY(SV* self)
    CODE:
        SELF_TO_THIS;
        SvREFCNT_dec(this->unregister_cb);
        SvREFCNT_dec(this->register_cb);
        this->path_free_func(this->path);
        safefree(this);

Uint32
SDLx__Tween_get_cycle_start_time(SV* self)
    CODE:
        SELF_TO_THIS;
        RETVAL = this->cycle_start_time;
    OUTPUT:
        RETVAL

bool
SDLx__Tween_is_active(SV* self)
    CODE:
        SELF_TO_THIS;
        RETVAL = this->is_active;
    OUTPUT:
        RETVAL

void
SDLx__Tween_start(SV* self, ...)
    CODE:
        SELF_TO_THIS;
        SV* cycle_start_time_sv = ST(1);
        Uint32 cycle_start_time =
            SvIOK(cycle_start_time_sv)?
                (Uint32) SvIV(cycle_start_time_sv):
                (Uint32) SDL_GetTicks();
        start(self, this, cycle_start_time);

void
SDLx__Tween_stop(SV* self)
    CODE:
        SELF_TO_THIS;
        stop(self, this);

void
SDLx__Tween_tick(SV* self, Uint32 now)
    CODE:
        SELF_TO_THIS;
        tick(self, this, now);


