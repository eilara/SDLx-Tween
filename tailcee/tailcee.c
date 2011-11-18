#include <stdlib.h>
#include <math.h>
#include "SDL/SDL.h"
#include "./tailcee.h"

void tail_build_struct(
    SDLx__Tween__Tail this,
    SV*               register_cb,
    SV*               unregister_cb,
    double            speed,
    SV*               head,
    SV*               tail
) {
    this->register_cb      = register_cb;
    this->unregister_cb    = unregister_cb;
    this->speed            = speed;
    this->is_active        = 0;
    this->is_paused        = 0;
    this->last_tick        = 0;
    this->pause_start_time = 0;
    this->head             = (AV*) SvRV(head);
    this->tail             = (AV*) SvRV(tail);
    SV** tx_sv             = av_fetch(this->tail, 0, 0);
    SV** ty_sv             = av_fetch(this->tail, 1, 0);
    this->pos[0]           = (double) SvIV(*tx_sv);
    this->pos[1]           = (double) SvIV(*ty_sv);
}

void tail_start(SV* self, SDLx__Tween__Tail this, Uint32 cycle_start_time) {
    this->is_active = 1;
    this->last_tick = cycle_start_time;

    dSP; PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_sv(this->register_cb, G_DISCARD);
}

void tail_stop(SV* self, SDLx__Tween__Tail this) {
    if (!this->is_active) { return; }

    this->is_active = 0;

    dSP; PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_sv(this->unregister_cb, G_DISCARD);
}

void tail_pause(SV* self, SDLx__Tween__Tail this, Uint32 pause_time) {
    this->is_paused = 1;
    this->pause_start_time = pause_time;
}

void tail_resume(SV* self, SDLx__Tween__Tail this, Uint32 resume_time) {
    this->is_paused = 0;
    this->last_tick += resume_time - this->pause_start_time;
    this->pause_start_time = 0;
}

void tail_tick(SV* self, SDLx__Tween__Tail this, Uint32 now) {
    if (this->is_paused) { return; }

    Uint32 delta        = now - this->last_tick;
    SV** hx_sv          = av_fetch(this->head, 0, 0);
    SV** hy_sv          = av_fetch(this->head, 1, 0);
    double hx           = (double) SvIV(*hx_sv);
    double hy           = (double) SvIV(*hy_sv);
    double tx           = this->pos[0];
    double ty           = this->pos[1];
    double dir_x        = hx - tx;        
    double dir_y        = hy - ty;        
    double dist         = sqrt(dir_x*dir_x + dir_y*dir_y);

    if (dist <= 1) {
        tail_stop(self, this);
        return;
    }

    double ratio = this->speed * ((double) delta) /dist;
    double nx    = tx + dir_x * ratio;
    double ny    = ty + dir_y * ratio;
    this->pos[0] = nx;
    this->pos[1] = ny;
    SV** tx_sv   = av_fetch(this->tail, 0, 0);
    SV** ty_sv   = av_fetch(this->tail, 1, 0);

    SvIV_set(*tx_sv, (int) nx);
    SvIV_set(*ty_sv, (int) ny);
    this->last_tick = now;

    double ndir_x = hx - nx;        
    double ndir_y = hy - ny;        
    double ndist  = sqrt(ndir_x*ndir_x + ndir_y*ndir_y);
    if (ndist <= 1) {
        tail_stop(self, this);
        return;
    }
}


