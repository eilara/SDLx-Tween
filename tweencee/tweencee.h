#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "SDL/SDL.h"
#include "easing.h"

/* all times duration deltas in ticks (1ms)
 *
 * should be using sv_setsv(SV*, SV*); to set SV* if it is already set
 * check stack size instead of using SvIOK in start
 * "Floating point division with a constant or repeated division with the same value should of course be done by multiplying with the reciprocal"
 * final and initial ticks even if stopped externally with accurate init and final values from solver
 */

/* ------------------------------ tween ------------------------------ */

typedef struct sdl_tween {

       SV*   register_cb;
       SV*   unregister_cb;

    Uint32   duration;
      bool   forever;
       int   repeat;
      bool   bounce;

      bool   is_reversed;
      bool   is_active;
    Uint32   cycle_start_time;
    Uint32   last_tick_time;
    Uint32   last_cycle_complete_time;

    double   (*ease_func) (double);

     void*   path;
     void*   (*path_build_func ) (SV*);
      void   (*path_free_func  ) (void*);
       int   (*path_solve_func ) (void*, double, double[]);

     void*   proxy;
     void*   (*proxy_build_func) (SV*);
      void   (*proxy_free_func ) (void*);
      void   (*proxy_set_func  ) (void*, double[], int);

} sdl_tween;

typedef sdl_tween* SDLx__Tween;

/* ------------------------------ path ------------------------------- */

typedef struct sdl_tween_path_linear {

    double  from[4];
    double  to[4];
    int     dim;

} sdl_tween_path_linear;

typedef sdl_tween_path_linear* SDLx__Tween__Path__Linear;

void*  path_linear_build (SV* path_args);
void   path_linear_free  (void* thisp);
int    path_linear_solve (void* thisp, double t, double solved[4]);


typedef struct sdl_tween_path_sine {

    double  from[4];
    double  to[4];
    double  amp;
    double  freq;
    double  normal[2];

} sdl_tween_path_sine;

typedef sdl_tween_path_sine* SDLx__Tween__Path__Sine;

void*  path_sine_build (SV* path_args);
void   path_sine_free  (void* thisp);
int    path_sine_solve (void* thisp, double t, double solved[4]);


typedef struct sdl_tween_path_circular {

    double  center[2];
    double  radius;
    double  begin_angle;
    double  end_angle;

} sdl_tween_path_circular;

typedef sdl_tween_path_circular* SDLx__Tween__Path__Circular;

void*  path_circular_build (SV* path_args);
void   path_circular_free  (void* thisp);
int    path_circular_solve (void* thisp, double t, double solved[4]);

/* ------------------------------ proxy ------------------------------- */

/* in = double, out = call method with double or distinct int if round is on */
typedef struct sdl_tween_proxy_method {

    SV*    target;
    char*  method;
    bool   round;
    int    last_value;
    bool   is_init;

} sdl_tween_proxy_method;

typedef sdl_tween_proxy_method* SDLx__Tween__Proxy__Method;

void*  proxy_method_build (SV* proxy_args);
void   proxy_method_free  (void* thisp);
void   proxy_method_set   (void* thisp, double solved[4], int dim);


/* in = double, out = set in array ref as double, no rounding */
typedef struct sdl_tween_proxy_array {

    AV*    on;

} sdl_tween_proxy_array;

typedef sdl_tween_proxy_array* SDLx__Tween__Proxy__Array;

void*  proxy_array_build (SV* proxy_args);
void   proxy_array_free  (void* thisp);
void   proxy_array_set   (void* thisp, double solved[4], int dim);

/* ------------------ utils ------------------ */

int extract_egde_points(SV* hash_ref, double from[], double to[]);
