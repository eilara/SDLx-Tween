#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "const-c.inc"

#include <tweencee/tweencee.h>

MODULE = SDLx::Tween		PACKAGE = SDLx::Tween		PREFIX = SDLx__Tween_

INCLUDE: const-xs.inc

void
SDLx__Tween_build_struct(this, register_cb, unregister_cb, tick_cb, duration, forever, repeat, bounce, ease)
    SV*    this
    SV*    register_cb
    SV*    unregister_cb
    SV*    tick_cb
    Uint32 duration
    bool   forever
    int    repeat
    bool   bounce
    int    ease
    CODE:
        SDLx__Tween self = safemalloc(sizeof(sdl_tween));
        if(self == NULL) {
            warn("unable to create new struct for SDLx::Tween");
        }
        SV* register_cb_clone   = newSVsv(register_cb);
        SV* unregister_cb_clone = newSVsv(unregister_cb);
        SV* tick_cb_clone       = newSVsv(tick_cb);

        // TODO static array access?
        double (*ease_func) (double) = ease == 0? ease_linear:
                                       ease == 1? ease_swing:
                                       ease == 2? ease_out_bounce:
                                       ease == 3? ease_in_bounce:
                                       ease == 4? ease_in_out_bounce:
                                                  ease_linear;

        build_struct(
            this, self,
            register_cb_clone,
            unregister_cb_clone,
            tick_cb_clone,
            duration,
            forever,
            repeat,
            bounce,
            ease_func
        );

void
SDLx__Tween_free_struct(SV* this)
    CODE:
        SDLx__Tween self = (SDLx__Tween)xs_object_magic_get_struct_rv(aTHX_ this);
        SvREFCNT_dec(self->unregister_cb);
        SvREFCNT_dec(self->tick_cb);
        SvREFCNT_dec(self->register_cb);
        safefree(self);

Uint32
SDLx__Tween_get_cycle_start_time(SV* this)
    CODE:
        SDLx__Tween self = (SDLx__Tween)xs_object_magic_get_struct_rv(aTHX_ this);
        RETVAL = self->cycle_start_time;
    OUTPUT:
        RETVAL

bool
SDLx__Tween_is_active(SV* this)
    CODE:
        SDLx__Tween self = (SDLx__Tween)xs_object_magic_get_struct_rv(aTHX_ this);
        RETVAL = self->is_active;
    OUTPUT:
        RETVAL

void
SDLx__Tween_start(SV* this, ...)
    CODE:
        SDLx__Tween self = (SDLx__Tween)xs_object_magic_get_struct_rv(aTHX_ this);
        SV* cycle_start_time_sv = ST(1);
        Uint32 cycle_start_time =
            SvIOK(cycle_start_time_sv)?
                (Uint32) SvIV(cycle_start_time_sv):
                (Uint32) SDL_GetTicks();
        start(this, self, cycle_start_time);

void
SDLx__Tween_stop(SV* this)
    CODE:
        SDLx__Tween self = (SDLx__Tween)xs_object_magic_get_struct_rv(aTHX_ this);
        stop(this, self);

void
SDLx__Tween_tick(SV* this, Uint32 now)
    CODE:
        SDLx__Tween self = (SDLx__Tween)xs_object_magic_get_struct_rv(aTHX_ this);
        tick(this, self, now);
