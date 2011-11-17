#include <stdlib.h>
#include <math.h>
#include "./tailcee.h"

void build_structa(
    SDLx__Tween__Tail this,
    SV*               register_cb,
    SV*               unregister_cb,
    float             speed,
    SV*               head,
    SV*               tail
) {
    this->register_cb      = register_cb;
    this->unregister_cb    = unregister_cb;
    this->speed            = speed;
    this->is_active        = 0;
    this->is_paused        = 0;
    this->pause_start_time = 0;
    this->total_pause_time = 0;
}



