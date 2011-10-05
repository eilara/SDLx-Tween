#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "const-c.inc"

#include <tweencee/tweencee.h>

static double (*ease_table[5]) (double) = {
    ease_linear,
    ease_swing,
    ease_out_bounce,
    ease_in_bounce,
    ease_in_out_bounce,
};

#define PATH_FUNCS(kind) \
    path_linear_1D_##kind

static void* (*path_build_table[5]) () = {
    PATH_FUNCS(build)
};

static void (*path_free_table[5]) (void*) = {
    PATH_FUNCS(free)
};

static double (*path_solve_table[5]) (void*, double) = {
    PATH_FUNCS(solve)
};

MODULE = SDLx::Tween		PACKAGE = SDLx::Tween		PREFIX = SDLx__Tween_

INCLUDE: const-xs.inc

void
SDLx__Tween_build_struct(self, register_cb, unregister_cb, tick_cb, duration, forever, repeat, bounce, ease, path)
    SV*    self
    SV*    register_cb
    SV*    unregister_cb
    SV*    tick_cb
    Uint32 duration
    bool   forever
    int    repeat
    bool   bounce
    int    ease
    int    path
    CODE:
        SDLx__Tween this = safemalloc(sizeof(sdl_tween));
        if(this == NULL) { warn("unable to create new struct for SDLx::Tween"); }

        SV* register_cb_clone   = newSVsv(register_cb);
        SV* unregister_cb_clone = newSVsv(unregister_cb);
        SV* tick_cb_clone       = newSVsv(tick_cb);

        this->ease_func = ease_table[ease];

        this->path_build_func = path_build_table[path];
        this->path_free_func  = path_free_table[path];
        this->path_solve_func = path_solve_table[path];

        this->path = this->path_build_func();

        build_struct(
            self, this,
            register_cb_clone,
            unregister_cb_clone,
            tick_cb_clone,
            duration,
            forever,
            repeat,
            bounce
        );

void
SDLx__Tween_free_struct(SV* self)
    CODE:
        SDLx__Tween this = (SDLx__Tween)xs_object_magic_get_struct_rv(aTHX_ self);
        SvREFCNT_dec(this->unregister_cb);
        SvREFCNT_dec(this->tick_cb);
        SvREFCNT_dec(this->register_cb);
        this->path_free_func(this->path);
        safefree(this);

Uint32
SDLx__Tween_get_cycle_start_time(SV* self)
    CODE:
        SDLx__Tween this = (SDLx__Tween)xs_object_magic_get_struct_rv(aTHX_ self);
        RETVAL = this->cycle_start_time;
    OUTPUT:
        RETVAL

bool
SDLx__Tween_is_active(SV* self)
    CODE:
        SDLx__Tween this = (SDLx__Tween)xs_object_magic_get_struct_rv(aTHX_ self);
        RETVAL = this->is_active;
    OUTPUT:
        RETVAL

void
SDLx__Tween_start(SV* self, ...)
    CODE:
        SDLx__Tween this = (SDLx__Tween)xs_object_magic_get_struct_rv(aTHX_ self);
        SV* cycle_start_time_sv = ST(1);
        Uint32 cycle_start_time =
            SvIOK(cycle_start_time_sv)?
                (Uint32) SvIV(cycle_start_time_sv):
                (Uint32) SDL_GetTicks();
        start(self, this, cycle_start_time);

void
SDLx__Tween_stop(SV* self)
    CODE:
        SDLx__Tween this = (SDLx__Tween)xs_object_magic_get_struct_rv(aTHX_ self);
        stop(self, this);

void
SDLx__Tween_tick(SV* self, Uint32 now)
    CODE:
        SDLx__Tween this = (SDLx__Tween)xs_object_magic_get_struct_rv(aTHX_ self);
        tick(self, this, now);


