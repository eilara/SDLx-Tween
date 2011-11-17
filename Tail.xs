#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "tailcee/tailcee.h"

MODULE = SDLx::Tween::Tail		PACKAGE = SDLx::Tween::Tail		PREFIX = SDLx__Tween__Tail_

PROTOTYPES: DISABLE

void
SDLx__Tween__Tail_foo()
    CODE:
        printf("foo!!!\n");

SDLx__Tween__Tail
SDLx__Tween__Tail_new_struct(register_cb, unregister_cb, speed, head, tail)
    SV*    register_cb
    SV*    unregister_cb
    float  speed
    SV*    head
    SV*    tail
    CODE:
        SDLx__Tween__Tail this = (SDLx__Tween__Tail) safemalloc(sizeof(sdl_tween_tail));
        if(this == NULL) { croak("unable to create new struct for SDLx::Tween::Tail"); }

        SV* register_cb_clone   = newSVsv(register_cb);
        SV* unregister_cb_clone = newSVsv(unregister_cb);

        build_structa(
            this,
            register_cb_clone,
            unregister_cb_clone,
            speed,
            head,
            tail
        );
        
        RETVAL = this;
    OUTPUT:
        RETVAL    
