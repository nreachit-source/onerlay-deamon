
typedef void* id;
typedef void* SEL;
extern id objc_getClass(const char*);
extern SEL sel_registerName(const char*);
extern id objc_msgSend(id, SEL, ...);

__attribute__((constructor))
static void init_tweak(void) {
    id str = objc_msgSend((id)objc_getClass("NSString"), sel_registerName("stringWithUTF8String:"), "Hello from ObjC tweak!");
    objc_msgSend((id)objc_getClass("NSLog"), sel_registerName("description"), str);
}
