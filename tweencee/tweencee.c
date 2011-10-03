#include <stdlib.h>
#include <math.h>
#include "./tweencee.h"

const double PI = 2 * acos(0.0);

void build_struct(
    SV*         this,
    SDLx__Tween self,
    SV*         register_cb,
    SV*         unregister_cb,
    SV*         tick_cb,
    Uint32      duration,
    bool        forever,
    int         repeat,
    bool        bounce,
    double      (*ease_func) (double)
) {
    self->register_cb   = register_cb;
    self->unregister_cb = unregister_cb;
    self->tick_cb       = tick_cb;
    self->duration      = duration;
    self->forever       = forever;
    self->repeat        = repeat;
    self->bounce        = bounce;
    self->ease_func     = ease_func;
    self->is_active     = 0;

    xs_object_magic_attach_struct(aTHX_ SvRV(this), self);
}

void start(SV* this, SDLx__Tween self, Uint32 cycle_start_time) {
    self->is_active                = 1;
    self->cycle_start_time         = cycle_start_time;
    self->last_tick_time           = cycle_start_time;
    self->last_cycle_complete_time = 0;
    self->is_reversed              = 0;

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(this);
    PUTBACK;

    call_sv(self->register_cb, G_DISCARD);

    FREETMPS;
    LEAVE;
}

void stop(SV* this, SDLx__Tween self) {
    self->is_active                = 0;
    self->last_cycle_complete_time = self->cycle_start_time + self->duration;

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(this);
    PUTBACK;

    call_sv(self->unregister_cb, G_DISCARD);

    FREETMPS;
    LEAVE;
}

void tick(SV* this, SDLx__Tween self, Uint32 now) {
    bool is_complete = 0;
    Uint32 duration  = self->duration;
    Uint32 dt        = now - self->last_tick_time;
    Uint32 elapsed   = now - self->cycle_start_time;

    if (elapsed >= duration) {
        is_complete = 1;
        elapsed     = duration;
    }

    double t_normal = (double) elapsed / duration;
    double eased    = self->ease_func(t_normal);
    if (self->is_reversed) {
        eased = 1 - eased;
    }

    self->last_tick_time = now;

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSViv(elapsed)));
    XPUSHs(sv_2mortal(newSViv(dt)));
    PUTBACK;

    call_sv(self->tick_cb, G_DISCARD);

    FREETMPS;
    LEAVE;

    if (is_complete) {
        bool forever = self->forever;
        bool repeat  = self->repeat;
        if (forever || repeat > 1) {
            if (!forever)     { self->repeat = repeat - 1; }
            if (self->bounce) { self->is_reversed = !self->is_reversed; }
            self->cycle_start_time        += elapsed;
            self->last_tick_time           = self->cycle_start_time;
            self->last_cycle_complete_time = 0;
       } else {
            stop(this, self);
       }
    }
}

/* ------------------ easing functions ----------------- */

double ease_linear(double t) {
    return t;
}

double ease_swing(double t) {
    return 0.5 - 0.5 * cos(t * PI);
}

double ease_out_bounce(double t) {
    double p = 7.5625;
    double s = 2.75;
    return 
        t < 1.0/p ? s * pow(t, 2.0):
        t < 2.0/p ? s * pow(t - 1.500/p, 2.0) + 0.75:
        t < 2.5/p ? s * pow(t - 2.250/p, 2.0) + 0.9375:
                    s * pow(t - 2.625/p, 2.0) + 0.984375;
}

double ease_in_bounce(double t) {
    return 1 - ease_out_bounce(1.0 - t);
}

double ease_in_out_bounce(double t) {
    return
        t < 0.5?  in_bounce(2.0 * t    ) / 2.0:
                 out_bounce(2.0 * t - 1) / 2.0 + 0.5;
}

