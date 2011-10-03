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
 */

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

} sdl_tween;

typedef sdl_tween* SDLx__Tween;

extern double ease_linear        (double t);
extern double ease_swing         (double t);
extern double ease_out_bounce    (double t);
extern double ease_in_bounce     (double t);
extern double ease_in_out_bounce (double t);

typedef struct sdl_tween_path_linear_1D {

    double   from;
    double   to;
    double   (*solve_func) (double);

} sdl_tween_path_linear_1D;

typedef sdl_tween_path_linear_1D* SDLx__Tween__Path__Linear1D;
