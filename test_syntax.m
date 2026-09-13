
typedef void* id;
typedef void* SEL;
typedef struct { double x, y, width, height; } CGRect;
typedef struct { double x, y; } CGPoint;

@interface NSObject
+ (id)alloc;
- (id)init;
@end

@interface TestClass : NSObject
- (void)sayHello;
@end

@implementation TestClass
- (void)sayHello {
    // Hello
}
@end
