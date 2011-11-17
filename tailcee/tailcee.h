#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "SDL/SDL.h"

typedef struct sdl_tween_tail {

       SV*   register_cb;
       SV*   unregister_cb;

     float   speed;

      bool   is_active;
      bool   is_paused;
    Uint32   pause_start_time;
    Uint32   total_pause_time;

       AV*   head;
       AV*   tail;

} sdl_tween_tail;
typedef sdl_tween_tail* SDLx__Tween__Tail;

