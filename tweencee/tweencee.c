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

    double solved[4];
    this->path_solve_func(this->path, eased, solved);
    this->proxy_set_func(this->proxy, solved[0]);

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

    /* from and to could either be doubles or array ref of doubles */
    HV* args     = (HV*) SvRV(path_args);
    SV** from_sv = hv_fetch(args, "from", 4, 0);
    SV** to_sv   = hv_fetch(args, "to"  , 2, 0);
    SV* from_raw = *from_sv;
    SV* to_raw   = *to_sv;

    if (SvROK(from_raw) && SvTYPE(from_raw) == SVt_PVAV) {
        AV* from  = (AV*) SvRV(from_raw);
        AV* to    = (AV*) SvRV(to_raw);
        int dim   = av_len(from) + 1;
        this->dim = dim;
        int i;
        for (i = 0; i < dim; i++) {
            SV** from_el = av_fetch(from, i, 0);
            SV** to_el   = av_fetch(to  , i, 0);
            this->from[i] = (double) SvNV(*from_el);
            this->to[i]   = (double) SvNV(*to_el);
        }
    } else {
        this->dim = 1;
        this->from[0] = (double) SvNV(from_raw);
        this->to[0]   = (double) SvNV(to_raw);
    }

    return this;
}

void path_linear_1D_free(void* thisp) {
    SDLx__Tween__Path__Linear1D this = (SDLx__Tween__Path__Linear1D) thisp;
    safefree(this);
}

void path_linear_1D_solve(void* thisp, double t, double solved[]) {
    SDLx__Tween__Path__Linear1D this = (SDLx__Tween__Path__Linear1D) thisp;
    int dim  = this->dim;
    int i;
    for (i = 0; i < dim; i++) {
        solved[i] = LERP(t, this->from[i], this->to[i]);
    }
}

/* ------------------ proxy ----------------- */

void* proxy_method_build(SV* proxy_args) {
    SDLx__Tween__Proxy__Method this = safemalloc(sizeof(sdl_tween_proxy_method));
    if(this == NULL) { warn("unable to create new struct for proxy"); }

    HV* args       = (HV*) SvRV(proxy_args);
    SV** target_sv = hv_fetch(args, "target", 6, 0);
    SV** method_sv = hv_fetch(args, "method", 6, 0);
    SV** round_sv  = hv_fetch(args, "round" , 5, 0);
    this->method   = strdup((char*) SvPV_nolen(*method_sv));
    this->target   = newSVsv(*target_sv);
    this->round    = (bool) SvIV(*round_sv); 

    this->last_value = 0;
    this->is_init    = 0;

    return this;
}

void proxy_method_free(void* thisp) {
    SDLx__Tween__Proxy__Method this = (SDLx__Tween__Proxy__Method) thisp;
    SvREFCNT_dec(this->target);
    safefree(this->method);
    safefree(this);
}

void proxy_method_set(void* thisp, double inval) {
    SDLx__Tween__Proxy__Method this = (SDLx__Tween__Proxy__Method) thisp;
    SV* sv_value;

    if (round) {
        int val = (int) inval;

        if (this->is_init) {
            if (val == this->last_value) { return; }
        } else {
            this->is_init = 1;
        }

        this->last_value = val;
        sv_value = newSViv(val);
    } else {
        sv_value = newSVnv(inval);
    }

    dSP; ENTER; SAVETMPS; PUSHMARK (SP); EXTEND (SP, 2);
    XPUSHs(this->target);
    XPUSHs(sv_2mortal(sv_value));
    PUTBACK;

    call_method(this->method, G_DISCARD);

    FREETMPS; LEAVE;
}

