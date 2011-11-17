#include <stdlib.h>
#include <math.h>
#include "./tweencee.h"

#define LERP(T, A, B)  ( (A) + (T) * ((B) - (A)) )

static const double PI = 3.141592653589793238;

void build_struct(
    SDLx__Tween this,
    SV*         register_cb,
    SV*         unregister_cb,
    Uint32      duration,
    bool        forever,
    int         repeat,
    bool        bounce
) {
    this->register_cb      = register_cb;
    this->unregister_cb    = unregister_cb;
    this->duration         = duration;
    this->forever          = forever;
    this->repeat           = repeat;
    this->bounce           = bounce;
    this->is_active        = 0;
    this->is_paused        = 0;
    this->pause_start_time = 0;
    this->total_pause_time = 0;
}

void start(SV* self, SDLx__Tween this, Uint32 cycle_start_time) {
    this->is_active                = 1;
    this->cycle_start_time         = cycle_start_time;
    this->last_cycle_complete_time = 0;
    this->is_reversed              = 0;

    dSP; PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_sv(this->register_cb, G_DISCARD);
}

void stop(SV* self, SDLx__Tween this) {
    if (!this->is_active) { return; }

    this->is_active                = 0;
    this->last_cycle_complete_time = this->cycle_start_time + this->duration + this->total_pause_time;
    this->total_pause_time         = 0;

    dSP; PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_sv(this->unregister_cb, G_DISCARD);
}

void pause_tween(SV* self, SDLx__Tween this, Uint32 pause_time) {
    this->is_paused = 1;
    this->pause_start_time = pause_time;
}

void resume_tween(SV* self, SDLx__Tween this, Uint32 resume_time) {
    this->is_paused = 0;
    this->total_pause_time += resume_time - this->pause_start_time;
    this->pause_start_time = 0;
}

void tick(SV* self, SDLx__Tween this, Uint32 now) {
    if (this->is_paused) { return; }
    bool is_complete = 0;
    Uint32 duration  = this->duration;
    Uint32 elapsed   = now - this->cycle_start_time - this->total_pause_time;

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
    int dim = extract_egde_points(path_args, this->from, this->to);

    HV* args     = (HV*) SvRV(path_args);
    SV** amp_sv  = hv_fetch(args, "amp" , 3, 0);
    SV** freq_sv = hv_fetch(args, "freq", 4, 0);
    this->amp    = (double) SvNV(*amp_sv);
    this->freq   = 2.0 * PI * ((double) SvNV(*freq_sv));

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

    return 2;
}

/* circular path */

void* path_circular_build(SV* path_args) {
    SDLx__Tween__Path__Circular this = safemalloc(sizeof(sdl_tween_path_circular));
    if(this == NULL) { warn("unable to create new struct for path"); }

    HV* args            = (HV*) SvRV(path_args);
    SV** center_sv      = hv_fetch(args, "center"     ,  6, 0);
    SV** radius_sv      = hv_fetch(args, "radius"     ,  6, 0);
    SV** begin_angle_sv = hv_fetch(args, "begin_angle", 11, 0);
    SV** end_angle_sv   = hv_fetch(args, "end_angle"  ,  9, 0);
    this->radius        = (double) SvNV(*radius_sv);
    this->begin_angle   = (double) SvNV(*begin_angle_sv);
    this->end_angle     = (double) SvNV(*end_angle_sv);

    AV* center_arr      = (AV*) SvRV(*center_sv);
    SV** x              = av_fetch(center_arr, 0, 0);
    SV** y              = av_fetch(center_arr, 1, 0);
    this->center[0]     = (double) SvNV(*x);
    this->center[1]     = (double) SvNV(*y);

    return this;
}

void path_circular_free(void* thisp) {
    SDLx__Tween__Path__Circular this = (SDLx__Tween__Path__Circular) thisp;
    safefree(this);
}

int path_circular_solve(void* thisp, double t, double solved[4]) {
    SDLx__Tween__Path__Circular this = (SDLx__Tween__Path__Circular) thisp;

    double delta = this->end_angle - this->begin_angle;
    double angle = this->begin_angle + delta * t;
    solved[0]    = this->center[0] + this->radius * cos(angle);
    solved[1]    = this->center[1] + this->radius * sin(angle);

    return 2;
}

/* spiral path */

void* path_spiral_build(SV* path_args) {
    SDLx__Tween__Path__Spiral this = safemalloc(sizeof(sdl_tween_path_spiral));
    if(this == NULL) { warn("unable to create new struct for path"); }

    HV* args             = (HV*) SvRV(path_args);
    SV** center_sv       = hv_fetch(args, "center"      ,  6, 0);
    SV** begin_radius_sv = hv_fetch(args, "begin_radius", 12, 0);
    SV** end_radius_sv   = hv_fetch(args, "end_radius"  , 10, 0);
    SV** begin_angle_sv  = hv_fetch(args, "begin_angle" , 11, 0);
    SV** rotations_sv    = hv_fetch(args, "rotations"   ,  9, 0);
    this->begin_radius   = (double) SvNV(*begin_radius_sv);
    this->end_radius     = (double) SvNV(*end_radius_sv);
    this->begin_angle    = (double) SvNV(*begin_angle_sv);
    this->rotations      = (double) SvNV(*rotations_sv);
                        
    AV* center_arr       = (AV*) SvRV(*center_sv);
    SV** x               = av_fetch(center_arr, 0, 0);
    SV** y               = av_fetch(center_arr, 1, 0);
    this->center[0]      = (double) SvNV(*x);
    this->center[1]      = (double) SvNV(*y);

    return this;
}

void path_spiral_free(void* thisp) {
    SDLx__Tween__Path__Spiral this = (SDLx__Tween__Path__Spiral) thisp;
    safefree(this);
}

int path_spiral_solve(void* thisp, double t, double solved[4]) {
    SDLx__Tween__Path__Spiral this = (SDLx__Tween__Path__Spiral) thisp;
    double angle  = this->begin_angle + 2.0 * PI * this->rotations * t;
    double radius = this->begin_radius +
                    (this->end_radius - this->begin_radius) * t;
    solved[0]    = this->center[0] + radius * cos(angle);
    solved[1]    = this->center[1] + radius * sin(angle);

    return 2;
}

/* polyline path */

void* path_polyline_build(SV* path_args) {
    SDLx__Tween__Path__Polyline this = safemalloc(sizeof(sdl_tween_path_polyline));
    if(this == NULL) { warn("unable to create new struct for path"); }
    this->head = NULL;

    HV* args         = (HV*) SvRV(path_args);
    SV** segments_sv = hv_fetch(args, "segments", 8, 0);
    AV* segments_arr = (AV*) SvRV(*segments_sv);
    int segments_len = av_len(segments_arr) + 1;
    
    int i;
    for (i = 0; i < segments_len; i++) {
        SV** segment_sv = av_fetch(segments_arr, i, 0);
        AV* segment_parts = (AV*) SvRV(*segment_sv);
        sdl_tween_path_polyline_segment* segment = safemalloc(sizeof(sdl_tween_path_polyline_segment));

        if(segment == NULL) { warn("unable to create new struct for segment"); }
        segment->from[0]  = (double) SvNV(*av_fetch(segment_parts, 0, 0));
        segment->from[1]  = (double) SvNV(*av_fetch(segment_parts, 1, 0));
        segment->to[0]    = (double) SvNV(*av_fetch(segment_parts, 2, 0));
        segment->to[1]    = (double) SvNV(*av_fetch(segment_parts, 3, 0));
        segment->ratio    = (double) SvNV(*av_fetch(segment_parts, 4, 0));
        segment->progress = (double) SvNV(*av_fetch(segment_parts, 5, 0));

        if (this->head == NULL) {
            segment->next = NULL;
            segment->prev = NULL;
            this->head    = segment;
            this->current = segment;
        } else {
            this->current->next = segment;
            segment->prev       = this->current;
            this->current       = segment;
        }
    }
    this->current->next = NULL;
    this->tail          = this->current;
    this->current       = this->head;

    return this;
}

void path_polyline_free(void* thisp) {
    SDLx__Tween__Path__Polyline this = (SDLx__Tween__Path__Polyline) thisp;
    sdl_tween_path_polyline_segment* segment = this->head;
    while (segment != NULL) {
        sdl_tween_path_polyline_segment* segment_temp = segment;
        segment = segment->next;
        safefree(segment_temp);
    }
    safefree(this);
}

int path_polyline_solve(void* thisp, double t, double solved[4]) {
    SDLx__Tween__Path__Polyline this = (SDLx__Tween__Path__Polyline) thisp;

    sdl_tween_path_polyline_segment* segment = this->current;
    if (segment->next != NULL && t > segment->progress) {
        segment = segment->next;
        this->current = segment;
    } else if (segment->prev != NULL && t <= segment->prev->progress) {
        segment = segment->prev;
        this->current = segment;
    }

    sdl_tween_path_polyline_segment* prev = segment->prev;
    double t_ratio = (t - (prev == NULL? 0 :prev->progress)) / segment->ratio;
    solved[0] = LERP(t_ratio, segment->from[0], segment->to[0]);
    solved[1] = LERP(t_ratio, segment->from[1], segment->to[1]);

    return 2;
}

/* fade color path changes opacity of a color */

void* path_fade_build(SV* path_args) {
    SDLx__Tween__Path__Fade this = safemalloc(sizeof(sdl_tween_path_fade));
    if(this == NULL) { warn("unable to create new struct for path"); }

    HV* args       = (HV*) SvRV(path_args);
    SV** from_sv   = hv_fetch(args, "from", 4, 0);
    SV** to_sv     = hv_fetch(args, "to"  , 2, 0);
    Uint32 color   = (Uint32) SvIV(*from_sv);
    this->to       = (Uint8 ) SvIV(*to_sv);
    this->from     = (Uint8 ) color & 0xFF;
    color          =  color & 0xFFFFFF00;
    this->color[3] = (color & 0x000000FF);
    this->color[2] = (color & 0x0000FF00) >> 8;
    this->color[1] = (color & 0x00FF0000) >> 16;
    this->color[0] = (color & 0xFF000000) >> 24;
    return this;
}

void path_fade_free(void* thisp) {
    SDLx__Tween__Path__Fade this = (SDLx__Tween__Path__Fade) thisp;
    safefree(this);
}

int path_fade_solve(void* thisp, double t, double solved[4]) {
    SDLx__Tween__Path__Fade this = (SDLx__Tween__Path__Fade) thisp;
    double delta  = t * (double) (this->to - this->from);
    Uint8 opacity = ((double) this->from) + delta;
    solved[0]     = this->color[0];
    solved[1]     = this->color[1];
    solved[2]     = this->color[2];
    solved[3]     = opacity;
    return 4;
}

/* rgba linear tween on any of individual rgba components of color */

void* path_rgba_build(SV* path_args) {
    SDLx__Tween__Path__Linear this = safemalloc(sizeof(sdl_tween_path_linear));
    if(this == NULL) { warn("unable to create new struct for path"); }
    HV* args      = (HV*) SvRV(path_args);
    SV** from_sv  = hv_fetch(args, "from", 4, 0);
    SV** to_sv    = hv_fetch(args, "to"  , 2, 0);
    Uint32 from   = (Uint32) SvIV(*from_sv);
    Uint32 to     = (Uint32) SvIV(*to_sv);
    this->from[3] = (from & 0x000000FF);
    this->from[2] = (from & 0x0000FF00) >> 8;
    this->from[1] = (from & 0x00FF0000) >> 16;
    this->from[0] = (from & 0xFF000000) >> 24;
    this->to[3]   = (to   & 0x000000FF);
    this->to[2]   = (to   & 0x0000FF00) >> 8;
    this->to[1]   = (to   & 0x00FF0000) >> 16;
    this->to[0]   = (to   & 0xFF000000) >> 24;
    this->dim     = 4;
    return this;
}

void path_rgba_free(void* thisp) {
    path_linear_free(thisp);
}

int path_rgba_solve(void* thisp, double t, double solved[4]) {
    return path_linear_solve(thisp, t, solved);
}

/* ------------------ proxy ----------------- */

/* method proxy */

void* proxy_method_build(SV* proxy_args) {
    SDLx__Tween__Proxy__Method this = safemalloc(sizeof(sdl_tween_proxy_method));
    if(this == NULL) { warn("unable to create new struct for proxy"); }

    HV* args          = (HV*) SvRV(proxy_args);
    SV** target_sv    = hv_fetch(args, "target"    , 6, 0);
    SV** method_sv    = hv_fetch(args, "method"    , 6, 0);
    SV** round_sv     = hv_fetch(args, "round"     , 5, 0);
    SV** is_uint32_sv = hv_fetch(args, "is_uint32" , 9, 0);
    this->method      = strdup((char*) SvPV_nolen(*method_sv));

    /* weak ref to target */
    this->target      = newRV_noinc(SvRV(*target_sv));

    /* strong ref to target */
    /*this->target   = newSVsv(*target_sv);*/

    this->round       = (bool) SvIV(*round_sv); 
    this->is_uint32   = (bool) SvIV(*is_uint32_sv); 

    this->last_value  = 0;
    this->is_init     = 0;

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

    } else if (this->is_uint32) {
        Uint32 color = ((Uint8) solved[0] << 24) |
                       ((Uint8) solved[1] << 16) |
                       ((Uint8) solved[2] <<  8) |
                        (Uint8) solved[3];
        if (this->is_init) {
            if (color == this->last_uint32_value) { return; }
        } else {
            this->is_init = 1;
        }
        this->last_uint32_value = color;

        dSP; ENTER; SAVETMPS;PUSHMARK(SP); EXTEND(SP, 2);
        XPUSHs(this->target);
        XPUSHs(sv_2mortal(newSViv(color)));
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
/*    SvREFCNT_inc(on); */

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
/*    SvREFCNT_dec(this->on); */
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


