#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "SDL/SDL.h"

/* all times duration deltas in ticks (1ms)
 *
 * TODO
 * should be using sv_setsv(SV*, SV*); to set SV* if it is already set
 * freeing a struct frees all SV*? need to clean 3 SV* callbacks
 * start/stop should be in xs
 * what is correct dance with stack when calling perl from xs?
 * how to use SDL.h portably?
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

    double (*ease_func) (double);

} sdl_tween;

typedef sdl_tween* SDLx__Tween;

extern double ease_linear        (double t);
extern double ease_swing         (double t);
extern double ease_out_bounce    (double t);
extern double ease_in_bounce     (double t);
extern double ease_in_out_bounce (double t);


