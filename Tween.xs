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
    path_spiral_##kind,   \
    path_polyline_##kind, \
    path_fade_##kind,     \
    path_rgba_##kind,

static void* (*path_build_table[7]) (SV*) = {
    PATH_FUNCS(build)
};

static void (*path_free_table[7]) (void*) = {
    PATH_FUNCS(free)
};

static int (*path_solve_table[7]) (void*, double, double[4]) = {
    PATH_FUNCS(solve)
};

/* ------------------------------ proxy ------------------------------- */

#define PROXY_FUNCS(kind) \
    proxy_method_##kind,  \
    proxy_array_##kind

static void* (*proxy_build_table[2]) (SV*) = {
    PROXY_FUNCS(build)
};

static void (*proxy_free_table[2]) (void*) = {
    PROXY_FUNCS(free)
};

static void (*proxy_set_table[2]) (void*, double[4], int dim) = {
    PROXY_FUNCS(set)
};

/* ------------------------------ tween ------------------------------- */

MODULE = SDLx::Tween		PACKAGE = SDLx::Tween		PREFIX = SDLx__Tween_

BOOT:
    boot_SDLx__Tween__Tail(aTHX_ cv);

PROTOTYPES: DISABLE

INCLUDE: const-xs.inc


#define SELF_TO_THIS \
    AV*         self_arr    = (AV*) SvRV(self);                          \
    SV**        self_arr_v  = av_fetch(self_arr, 0, 0);                  \
    SDLx__Tween this        = (SDLx__Tween) SvIV((SV*)SvRV(*self_arr_v))

SDLx__Tween
SDLx__Tween_new_struct(register_cb, unregister_cb, complete_cb, duration, forever, repeat, bounce, ease, path, path_args, proxy, proxy_args)
    SV*    register_cb
    SV*    unregister_cb
    SV*    complete_cb
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
        SV* complete_cb_clone   = newSVsv(complete_cb);

        this->ease_func = ease_table[ease];

        this->path_build_func = path_build_table[path];
        this->path_free_func  = path_free_table[path];
        this->path_solve_func = path_solve_table[path];

        this->path = this->path_build_func(path_args);

        this->proxy_build_func = proxy_build_table[proxy];
        this->proxy_free_func  = proxy_free_table[proxy];
        this->proxy_set_func   = proxy_set_table[proxy];

        this->proxy = this->proxy_build_func(proxy_args);

        tween_build_struct(
            this,
            register_cb_clone,
            unregister_cb_clone,
            complete_cb_clone,
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
        AV*  self_arr    = (AV*) SvRV(self);
        SV** self_arr_v  = av_fetch(self_arr, 0, 0);
        if (self_arr_v == NULL) return;
        if (!SvOK(*self_arr_v)) return;
        SDLx__Tween this = (SDLx__Tween) SvIV((SV*)SvRV(*self_arr_v));

        SvREFCNT_dec(this->unregister_cb);
        SvREFCNT_dec(this->register_cb);
        SvREFCNT_dec(this->complete_cb);
        this->path_free_func(this->path);
        safefree(this);

Uint32
SDLx__Tween_get_cycle_start_time(SV* self)
    CODE:
        SELF_TO_THIS;
        RETVAL = this->cycle_start_time;
    OUTPUT:
        RETVAL

Uint32
SDLx__Tween_get_duration(SV* self)
    CODE:
        SELF_TO_THIS;
        RETVAL = this->duration;
    OUTPUT:
        RETVAL

void
SDLx__Tween_set_duration(SV* self, Uint32 new_duration, ...)
    CODE:
        /* TODO should do nothing on is_paused? */
        SELF_TO_THIS;
        Uint32 now = items == 3?
           (Uint32) SvIV(ST(2)):
           (Uint32) SDL_GetTicks();
        Uint32 old_duration    = this->duration;
        Uint32 paused          = this->total_pause_time;
        double ratio           = 1.0 - (double) new_duration / (double) old_duration;
        double elapsed         = now - this->cycle_start_time - paused;
        this->duration         = new_duration;
        this->cycle_start_time = this->cycle_start_time + paused + elapsed * ratio;
        this->total_pause_time = 0;
    OUTPUT:

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
        Uint32 cycle_start_time = items == 2?
           (Uint32) SvIV(ST(1)):
           (Uint32) SDL_GetTicks();
        tween_start(self, this, cycle_start_time);

void
SDLx__Tween_stop(SV* self)
    CODE:
        SELF_TO_THIS;
        tween_stop(self, this);

void
SDLx__Tween_pause(SV* self, ...)
    CODE:
        SELF_TO_THIS;
        SV* t_sv = ST(1);
        Uint32 t =
            SvIOK(t_sv)?
                (Uint32) SvIV(t_sv):
                (Uint32) SDL_GetTicks();
        tween_pause(self, this, t);

void
SDLx__Tween_resume(SV* self, ...)
    CODE:
        SELF_TO_THIS;
        SV* t_sv = ST(1);
        Uint32 t =
            SvIOK(t_sv)?
                (Uint32) SvIV(t_sv):
                (Uint32) SDL_GetTicks();
        tween_resume(self, this, t);

void
SDLx__Tween_tick(SV* self, Uint32 now)
    CODE:
        SELF_TO_THIS;
        tween_tick(self, this, now);


