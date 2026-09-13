
#include <stdio.h>

extern void NSLog(void *format, ...);

__attribute__((constructor))
static void init_tweak(void) {
    printf("Hello from tweak\n");
}
