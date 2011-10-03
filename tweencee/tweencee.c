#include <stdlib.h>
#include <math.h>
#include "./tweencee.h"

const double PI = 2 * acos(0.0);

void build_struct(
    SV*         self,
    SDLx__Tween this,
    SV*         register_cb,
    SV*         unregister_cb,
    SV*         tick_cb,
    Uint32      duration,
    bool        forever,
    int         repeat,
    bool        bounce,
    double      (*ease_func) (double)
) {
    this->register_cb   = register_cb;
    this->unregister_cb = unregister_cb;
    this->tick_cb       = tick_cb;
    this->duration      = duration;
    this->forever       = forever;
    this->repeat        = repeat;
    this->bounce        = bounce;
    this->ease_func     = ease_func;
    this->is_active     = 0;

    xs_object_magic_attach_struct(aTHX_ SvRV(self), this);
}

void start(SV* self, SDLx__Tween this, Uint32 cycle_start_time) {
    this->is_active                = 1;
    this->cycle_start_time         = cycle_start_time;
    this->last_tick_time           = cycle_start_time;
    this->last_cycle_complete_time = 0;
    this->is_reversed              = 0;

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_sv(this->register_cb, G_DISCARD);

    FREETMPS;
    LEAVE;
}

void stop(SV* self, SDLx__Tween this) {
    this->is_active                = 0;
    this->last_cycle_complete_time = this->cycle_start_time + this->duration;

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_sv(this->unregister_cb, G_DISCARD);

    FREETMPS;
    LEAVE;
}

void tick(SV* self, SDLx__Tween this, Uint32 now) {
    bool is_complete = 0;
    Uint32 duration  = this->duration;
    Uint32 dt        = now - this->last_tick_time;
    Uint32 elapsed   = now - this->cycle_start_time;

    if (elapsed >= duration) {
        is_complete = 1;
        elapsed     = duration;
    }

    double t_normal = (double) elapsed / duration;
    double eased    = this->ease_func(t_normal);
    if (this->is_reversed) {
        eased = 1 - eased;
    }

    this->last_tick_time = now;

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSViv(elapsed)));
    XPUSHs(sv_2mortal(newSViv(dt)));
    PUTBACK;

    call_sv(this->tick_cb, G_DISCARD);

    FREETMPS;
    LEAVE;

    if (!this->is_active) { return; } /* perl code could have stopped the tween */
    if (!is_complete    ) { return; }

    bool forever = this->forever;
    bool repeat  = this->repeat;

    if (!forever && repeat <= 1) {
        stop(self, this);
        return;
    }

    if (!forever)     { this->repeat = repeat - 1; }
    if (this->bounce) { this->is_reversed = !this->is_reversed; }

    this->cycle_start_time        += elapsed;
    this->last_tick_time           = this->cycle_start_time;
    this->last_cycle_complete_time = 0;
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

