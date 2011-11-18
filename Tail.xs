#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "tailcee/tailcee.h"

MODULE = SDLx::Tween::Tail		PACKAGE = SDLx::Tween::Tail		PREFIX = SDLx__Tween__Tail_

PROTOTYPES: DISABLE

#define SELF_TO_THIS                                                                 \
    AV*               self_arr    = (AV*) SvRV(self);                                \
    SV**              self_arr_v  = av_fetch(self_arr, 0, 0);                        \
    SDLx__Tween__Tail this        = (SDLx__Tween__Tail) SvIV((SV*)SvRV(*self_arr_v))

SDLx__Tween__Tail
SDLx__Tween__Tail_new_struct(register_cb, unregister_cb, speed, head, tail)
    SV*     register_cb
    SV*     unregister_cb
    double  speed
    SV*     head
    SV*     tail
    CODE:
        SDLx__Tween__Tail this = (SDLx__Tween__Tail) safemalloc(sizeof(sdl_tween_tail));
        if(this == NULL) { croak("unable to create new struct for SDLx::Tween::Tail"); }

        SV* register_cb_clone   = newSVsv(register_cb);
        SV* unregister_cb_clone = newSVsv(unregister_cb);

        tail_build_struct(
            this,
            register_cb_clone,
            unregister_cb_clone,
            speed,
            head,
            tail
        );
        
        RETVAL = this;
    OUTPUT:
        RETVAL

void
SDLx__Tween__Tail_DESTROY(SV* self)
    CODE:
        AV*  self_arr    = (AV*) SvRV(self);
        SV** self_arr_v  = av_fetch(self_arr, 0, 0);
        if (self_arr_v == NULL) return;
        if (!SvOK(*self_arr_v)) return;
        SDLx__Tween__Tail this = (SDLx__Tween__Tail) SvIV((SV*)SvRV(*self_arr_v));

        SvREFCNT_dec(this->unregister_cb);
        SvREFCNT_dec(this->register_cb);
        safefree(this);

bool
SDLx__Tween__Tail_is_active(SV* self)
    CODE:
        SELF_TO_THIS;
        RETVAL = this->is_active;
    OUTPUT:
        RETVAL

void
SDLx__Tween__Tail_start(SV* self, ...)
    CODE:
        SELF_TO_THIS;
        Uint32 cycle_start_time = items == 2?
           (Uint32) SvIV(ST(1)):
           (Uint32) SDL_GetTicks();
        tail_start(self, this, cycle_start_time);

void
SDLx__Tween__Tail_stop(SV* self)
    CODE:
        SELF_TO_THIS;
        tail_stop(self, this);

void
SDLx__Tween__Tail_pause(SV* self, ...)
    CODE:
        SELF_TO_THIS;
        SV* t_sv = ST(1);
        Uint32 t =
            SvIOK(t_sv)?
                (Uint32) SvIV(t_sv):
                (Uint32) SDL_GetTicks();
        tail_pause(self, this, t);

void
SDLx__Tween__Tail_resume(SV* self, ...)
    CODE:
        SELF_TO_THIS;
        SV* t_sv = ST(1);
        Uint32 t =
            SvIOK(t_sv)?
                (Uint32) SvIV(t_sv):
                (Uint32) SDL_GetTicks();
        tail_resume(self, this, t);

void
SDLx__Tween__Tail_tick(SV* self, Uint32 now)
    CODE:
        SELF_TO_THIS;
        tail_tick(self, this, now);

