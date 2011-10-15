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
    int dim = this->path_solve_func(this->path, eased, solved);
    this->proxy_set_func(this->proxy, solved, dim);

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

/* ------------------ path ------------------ */

/* linear path */

void* path_linear_build(SV* path_args) {
    SDLx__Tween__Path__Linear this = safemalloc(sizeof(sdl_tween_path_linear));
    if(this == NULL) { warn("unable to create new struct for path"); }
    this->dim = extract_egde_points(path_args, this->from, this->to);
    return this;
}

void path_linear_free(void* thisp) {
    SDLx__Tween__Path__Linear this = (SDLx__Tween__Path__Linear) thisp;
    safefree(this);
}

int path_linear_solve(void* thisp, double t, double solved[4]) {
    SDLx__Tween__Path__Linear this = (SDLx__Tween__Path__Linear) thisp;
    int dim  = this->dim;
    int i;
    for (i = 0; i < dim; i++) {
        solved[i] = LERP(t, this->from[i], this->to[i]);
    }
    return dim;
}

/* sine path */

void* path_sine_build(SV* path_args) {
    SDLx__Tween__Path__Sine this = safemalloc(sizeof(sdl_tween_path_sine));
    if(this == NULL) { warn("unable to create new struct for path"); }
    this->dim = extract_egde_points(path_args, this->from, this->to);

    HV* args     = (HV*) SvRV(path_args);
    SV** amp_sv  = hv_fetch(args, "amp" , 3, 0);
    SV** freq_sv = hv_fetch(args, "freq", 4, 0);
    this->amp    = (double) SvNV(*amp_sv);
    this->freq   = 2 * PI * ((double) SvNV(*freq_sv));

    double n0 = this->from[1] - this->to[1];
    double n1 = this->to[0] - this->from[0];
    if (n0== 0 && n1 == 0) { n1 = 1; }
    double len = sqrt(n0 * n0 + n1 * n1);
    this->normal[0] = n0 / len;
    this->normal[1] = n1 / len;
    return this;
}

void path_sine_free(void* thisp) {
    SDLx__Tween__Path__Sine this = (SDLx__Tween__Path__Sine) thisp;
    safefree(this);
}

int path_sine_solve(void* thisp, double t, double solved[4]) {
    SDLx__Tween__Path__Sine this = (SDLx__Tween__Path__Sine) thisp;
    double n0   = this->to[0] - this->from[0];
    double n1   = this->to[1] - this->from[1];
    double sine = sin(t * this->freq) * this->amp;
    solved[0]   = this->from[0] + t * n0 + sine * this->normal[0];
    solved[1]   = this->from[1] + t * n1 + sine * this->normal[1];

    return this->dim;
}

/* ------------------ proxy ----------------- */

/* method proxy */

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

void proxy_method_set(void* thisp, double solved[4], int dim) {
    SDLx__Tween__Proxy__Method this = (SDLx__Tween__Proxy__Method) thisp;
    if (dim == 1) {
        SV* out;
        if (round) {
            int val = (int) solved[0];
            if (this->is_init) {
                if (val == this->last_value) { return; }
            } else {
                this->is_init = 1;
            }
            this->last_value = val;
            out = newSViv(val);
        } else {
            out = newSVnv(solved[0]);
        }
        
        dSP; ENTER; SAVETMPS;PUSHMARK(SP); EXTEND(SP, 2);
        XPUSHs(this->target);
        XPUSHs(sv_2mortal(out));
        PUTBACK;

        call_method(this->method, G_DISCARD);

        FREETMPS; LEAVE;

    } else {
        AV* out = newAV();
        av_extend(out, dim - 1);
        int i;
        for (i = 0; i < dim; i++) {
            av_store(out, i, newSVnv(solved[i]));
        }

        dSP; ENTER; SAVETMPS;PUSHMARK(SP); EXTEND(SP, 2);
        XPUSHs(this->target);
        XPUSHs(sv_2mortal(newRV_noinc((SV*) out)));
        PUTBACK;

        call_method(this->method, G_DISCARD);

        FREETMPS; LEAVE;
    }
}

/* array proxy */

void* proxy_array_build(SV* proxy_args) {
    SDLx__Tween__Proxy__Array this = safemalloc(sizeof(sdl_tween_proxy_array));
    if(this == NULL) { warn("unable to create new struct for proxy"); }
    HV* args   = (HV*) SvRV(proxy_args);
    SV** on_sv = hv_fetch(args, "on", 2, 0);
    SV* on_raw = *on_sv;
    AV* on     = (AV*) SvRV(on_raw);
    this->on   = on;
    SvREFCNT_inc(on);

    /* make sure all svs are floats not ints */
    /* why dont it do anything? 
    int i;
    int dim = av_len(on) + 1;
    for (i = 0; i < dim; i++) {
        SV** val_sv = av_fetch(on, i, 0);
        SvNOK_on(*val_sv);
    }
    */

    return this;
}

void proxy_array_free(void* thisp) {
    SDLx__Tween__Proxy__Array this = (SDLx__Tween__Proxy__Array) thisp;
    SvREFCNT_dec(this->on);
    safefree(this);
}

void proxy_array_set(void* thisp, double solved[4], int dim) {
    SDLx__Tween__Proxy__Array this = (SDLx__Tween__Proxy__Array) thisp;
    AV* on = this->on;
    int i;
    for (i = 0; i < dim; i++) {
        SV** val_sv = av_fetch(on, i, 0);
        SvNV_set(*val_sv, solved[i]);
    }
}

/* ------------------ utils ------------------ */

int extract_egde_points(SV* hash_ref, double from[4], double to[4]) {
    int dim;

    /* from and to could either be doubles or array ref of doubles */
    HV* args     = (HV*) SvRV(hash_ref);
    SV** from_sv = hv_fetch(args, "from", 4, 0);
    SV** to_sv   = hv_fetch(args, "to"  , 2, 0);
    SV* from_raw = *from_sv;
    SV* to_raw   = *to_sv;

    if (SvROK(from_raw) && SvTYPE(SvRV(from_raw)) == SVt_PVAV) {
        AV* from_arr = (AV*) SvRV(from_raw);
        AV* to_arr   = (AV*) SvRV(to_raw);
        dim          = av_len(from_arr) + 1;
        int i;
        for (i = 0; i < dim; i++) {
            SV** from_el = av_fetch(from_arr, i, 0);
            SV** to_el   = av_fetch(to_arr  , i, 0);
            from[i] = (double) SvNV(*from_el);
            to[i]   = (double) SvNV(*to_el);
        }
    } else {
        dim = 1;
        from[0] = (double) SvNV(from_raw);
        to[0]   = (double) SvNV(to_raw);
    }
    return dim;
}


