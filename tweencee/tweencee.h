#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "SDL/SDL.h"

/* all times duration deltas in ticks (1ms)
 *
 * TODO
 * should be using sv_setsv(SV*, SV*); to set SV* if it is already set
 * freeing a struct frees all SV*? need to clean 3 SV* callbacks
 * what is correct dance with stack when calling perl from xs?
 * how to use SDL.h portably?
 * when I push this SV* into stack for call_sv, should I mortalize it?
 * turn build_struct case into vector of func pointers
 * check stack size instead of using SvIOK in start
 * error checking in perl
 * "Floating point division with a constant or repeated division with the same value should of course be done by multiplying with the reciprocal"
 * final and initial ticks even if stopped externally with accurate init and final values from solver
 * call a perl cb, set a hash, method call, tick cb is what?
 */

/* ------------------------------ tween ------------------------------ */

typedef struct sdl_tween {

       SV*   register_cb;
       SV*   unregister_cb;
       SV*   tick_cb;

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

     void*   path; /* for path_solve_func to cast */
     void*   (*path_build_func ) (SV*);
      void   (*path_free_func  ) (void*);
    double   (*path_solve_func ) (void*, double);

} sdl_tween;

typedef sdl_tween* SDLx__Tween;

/* --------------------------- easing funcs -------------------------- */

double ease_linear        (double t);
double ease_swing         (double t);
double ease_out_bounce    (double t);
double ease_in_bounce     (double t);
double ease_in_out_bounce (double t);

/* ------------------------------ paths ------------------------------ */

typedef struct sdl_tween_path_linear_1D {

    double   from;
    double   to;

} sdl_tween_path_linear_1D;

typedef sdl_tween_path_linear_1D* SDLx__Tween__Path__Linear1D;

void*  path_linear_1D_build (SV* path_args);
void   path_linear_1D_free  (void* thisp);
double path_linear_1D_solve (void* thisp, double t);

