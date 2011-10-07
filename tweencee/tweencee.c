#include <stdlib.h>
#include <math.h>
#include "./tweencee.h"

#define LERP(T, A, B)  ( (A) + (T) * ((B) - (A)) )

// this throws warning:
// warning: initializer element is not constant
// because some compilers cannot run a func here?
// what to do? static block?
static const double PI = 2 * acos(0.0);

void build_struct(
    SV*         self,
    SDLx__Tween this,
    SV*         register_cb,
    SV*         unregister_cb,
    Uint32      duration,
    bool        forever,
    int         repeat,
    bool        bounce
) {
    this->register_cb   = register_cb;
    this->unregister_cb = unregister_cb;
    this->duration      = duration;
    this->forever       = forever;
    this->repeat        = repeat;
    this->bounce        = bounce;
    this->is_active     = 0;

    xs_object_magic_attach_struct(aTHX_ SvRV(self), this);
}

void start(SV* self, SDLx__Tween this, Uint32 cycle_start_time) {
    this->is_active                = 1;
    this->cycle_start_time         = cycle_start_time;
    this->last_tick_time           = cycle_start_time;
    this->last_cycle_complete_time = 0;
    this->is_reversed              = 0;

    dSP; PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_sv(this->register_cb, G_DISCARD);
}

void stop(SV* self, SDLx__Tween this) {
    this->is_active                = 0;
    this->last_cycle_complete_time = this->cycle_start_time + this->duration;

    dSP; PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_sv(this->unregister_cb, G_DISCARD);
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

    double solved = this->path_solve_func(this->path, eased);
    this->proxy_set_func(this->proxy, solved);

    this->last_tick_time = now;

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

/* ------------------ path ------------------ */

void* path_linear_1D_build(SV* path_args) {
    SDLx__Tween__Path__Linear1D this = safemalloc(sizeof(sdl_tween_path_linear_1D));
    if(this == NULL) { warn("unable to create new struct for path"); }

    HV* args     = (HV*) SvRV(path_args);
    SV** from_sv = hv_fetch(args, "from", 4, 0);
    SV** to_sv   = hv_fetch(args, "to"  , 2, 0);
    double from  = (double) SvNV(*from_sv);
    double to    = (double) SvNV(*to_sv);
    this->to     = to;
    this->from   = from;

    return this;
}

void path_linear_1D_free(void* thisp) {
    SDLx__Tween__Path__Linear1D this = (SDLx__Tween__Path__Linear1D) thisp;
    safefree(this);
}

double path_linear_1D_solve(void* thisp, double t) {
    SDLx__Tween__Path__Linear1D this = (SDLx__Tween__Path__Linear1D) thisp;
    return LERP(t, this->from, this->to);
}

/* ------------------ proxy ----------------- */

void* proxy_int_method_build(SV* proxy_args) {
    SDLx__Tween__Proxy__Int__Method this = safemalloc(sizeof(sdl_tween_proxy_int_method));
    if(this == NULL) { warn("unable to create new struct for proxy"); }

    HV* args       = (HV*) SvRV(proxy_args);
    SV** target_sv = hv_fetch(args, "target", 6, 0);
    SV** method_sv = hv_fetch(args, "method", 6, 0);
    this->method   = strdup((char*) SvPV_nolen(*method_sv));
    this->target   = newSVsv(*target_sv);

    this->last_value = 0;
    this->is_init    = 0;

    return this;
}

void proxy_int_method_free(void* thisp) {
    SDLx__Tween__Proxy__Int__Method this = (SDLx__Tween__Proxy__Int__Method) thisp;
    SvREFCNT_dec(this->target);
    safefree(this->method);
    safefree(this);
}

void proxy_int_method_set(void* thisp, double inval) {
    SDLx__Tween__Proxy__Int__Method this = (SDLx__Tween__Proxy__Int__Method) thisp;
    int val = (int) inval;

    if (this->is_init) {
        if (val == this->last_value) { return; }
    } else {
        this->is_init = 1;
    }

    this->last_value = val;

    dSP; PUSHMARK(SP);
    XPUSHs(this->target);
    XPUSHs(sv_2mortal(newSViv(val)));
    PUTBACK;

    call_method(this->method, G_DISCARD);
}

