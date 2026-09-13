#import "uikit_lite.h"
#include <stdio.h>
#include <unistd.h>

static void log_overlay(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    char buf[1024];
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    
    FILE *f = fopen("/var/mobile/Downloads/onerlay_tweak.log", "a");
    if (f) {
        fprintf(f, "[ONERLAY] %s\n", buf);
        fclose(f);
    }
    printf("[ONERLAY] %s\n", buf);
}

@class OverlayWindow;
@class OverlayViewController;

static OverlayWindow *g_overlayWindow = nil;
static OverlayViewController *g_overlayVC = nil;

@interface OverlayViewController : UIViewController
@property (nonatomic, retain) UIButton *floatingButton;
@property (nonatomic, retain) UIView *cardContainer;
@property (nonatomic, retain) UILabel *statusLabel;
@property (nonatomic, retain) UILabel *infoLabel;
@property (nonatomic, assign) BOOL isExpanded;
- (void)onButtonTapped;
- (void)onCloseTapped;
- (void)handlePan:(UIPanGestureRecognizer *)recognizer;
@end

@interface OverlayWindow : UIWindow
@end

@implementation OverlayWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (!g_overlayVC) return NO;
    
    // If card is expanded, handle touches on the card
    if (g_overlayVC.isExpanded && g_overlayVC.cardContainer && !g_overlayVC.cardContainer.hidden) {
        CGPoint cardPoint = [self convertPoint:point toView:g_overlayVC.cardContainer];
        if ([g_overlayVC.cardContainer pointInside:cardPoint withEvent:event]) {
            return YES;
        }
    }
    
    // If touch is on the floating button, handle touch
    if (g_overlayVC.floatingButton && !g_overlayVC.floatingButton.hidden) {
        CGPoint btnPoint = [self convertPoint:point toView:g_overlayVC.floatingButton];
        if ([g_overlayVC.floatingButton pointInside:btnPoint withEvent:event]) {
            return YES;
        }
    }
    
    // All other touches pass through to whatever app is running underneath!
    return NO;
}

@end

@implementation OverlayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    log_overlay("Screen detected: %.0f x %.0f (Scale: %.1fx)", screenBounds.size.width, screenBounds.size.height, screenScale);
    
    self.isExpanded = NO;
    
    // --------------------------------------------------------------------------
    // 1. Floating Action Button (Top Right of Screen)
    // --------------------------------------------------------------------------
    CGFloat btnSize = 56.0;
    CGFloat initialX = screenBounds.size.width - btnSize - 14.0;
    CGFloat initialY = 60.0;
    
    self.floatingButton = [UIButton buttonWithType:0];
    self.floatingButton.frame = (CGRect){ {initialX, initialY}, {btnSize, btnSize} };
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.06 green:0.08 blue:0.14 alpha:0.92];
    [self.floatingButton setTitle:[NSString stringWithUTF8String:"⚡"] forState:UIControlStateNormal];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.floatingButton.titleLabel setFont:[UIFont boldSystemFontOfSize:26.0]];
    
    self.floatingButton.layer.cornerRadius = btnSize / 2.0;
    self.floatingButton.layer.masksToBounds = NO;
    self.floatingButton.layer.borderWidth = 2.5;
    self.floatingButton.layer.borderColor = [[UIColor colorWithRed:0.0 green:0.80 blue:1.0 alpha:0.90] CGColor];
    self.floatingButton.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.floatingButton.layer.shadowOpacity = 0.50;
    self.floatingButton.layer.shadowRadius = 10.0;
    self.floatingButton.layer.shadowOffset = (CGSize){0, 4};
    
    [self.floatingButton addTarget:self action:@selector(onButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.floatingButton addGestureRecognizer:pan];
    
    [self.view addSubview:self.floatingButton];
    
    // --------------------------------------------------------------------------
    // 2. Expandable Info Card
    // --------------------------------------------------------------------------
    CGFloat cardWidth = 330.0;
    CGFloat cardHeight = 240.0;
    CGFloat cardX = (screenBounds.size.width - cardWidth) / 2.0;
    CGFloat cardY = 120.0;
    
    self.cardContainer = [[UIView alloc] initWithFrame:(CGRect){ {cardX, cardY}, {cardWidth, cardHeight} }];
    self.cardContainer.backgroundColor = [UIColor clearColor];
    self.cardContainer.layer.cornerRadius = 22.0;
    self.cardContainer.layer.masksToBounds = YES;
    self.cardContainer.alpha = 0.0;
    self.cardContainer.hidden = YES;
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = (CGRect){ {0, 0}, {cardWidth, cardHeight} };
    blurView.layer.cornerRadius = 22.0;
    blurView.layer.masksToBounds = YES;
    blurView.layer.borderWidth = 1.5;
    blurView.layer.borderColor = [[UIColor colorWithWhite:1.0 alpha:0.25] CGColor];
    [self.cardContainer addSubview:blurView];
    
    // Card Title
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:(CGRect){ {16, 16}, {cardWidth - 32, 24} }];
    titleLbl.text = [NSString stringWithUTF8String:"📱 iOS System Overlay Active"];
    titleLbl.font = [UIFont boldSystemFontOfSize:17.0];
    titleLbl.textColor = [UIColor whiteColor];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [blurView.contentView addSubview:titleLbl];
    
    // Main Approved Status Message
    self.statusLabel = [[UILabel alloc] initWithFrame:(CGRect){ {20, 48}, {cardWidth - 40, 56} }];
    self.statusLabel.text = [NSString stringWithUTF8String:"Hello, I am approved that overlay can work in iPhone."];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:16.0];
    self.statusLabel.textColor = [UIColor systemGreenColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    [blurView.contentView addSubview:self.statusLabel];
    
    // Screen & System Details
    self.infoLabel = [[UILabel alloc] initWithFrame:(CGRect){ {20, 110}, {cardWidth - 40, 60} }];
    char infoText[256];
    snprintf(infoText, sizeof(infoText),
             "Screen: %.0f × %.0f pt (%.0fx)\nSpringBoard PID: %d\nStatus: Floating Window Active",
             screenBounds.size.width, screenBounds.size.height, screenScale, getpid());
    self.infoLabel.text = [NSString stringWithUTF8String:infoText];
    self.infoLabel.font = [UIFont systemFontOfSize:13.0];
    self.infoLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.numberOfLines = 3;
    [blurView.contentView addSubview:self.infoLabel];
    
    // Minimize / Return Button
    UIButton *closeBtn = [UIButton buttonWithType:0];
    closeBtn.frame = (CGRect){ {30, 180}, {cardWidth - 60, 42} };
    closeBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.22 blue:0.30 alpha:0.95];
    [closeBtn setTitle:[NSString stringWithUTF8String:"Minimize / Return"] forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithRed:0.0 green:0.80 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    [closeBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:15.0]];
    closeBtn.layer.cornerRadius = 12.0;
    closeBtn.layer.borderWidth = 1.0;
    closeBtn.layer.borderColor = [[UIColor colorWithRed:0.0 green:0.80 blue:1.0 alpha:0.5] CGColor];
    [closeBtn addTarget:self action:@selector(onCloseTapped) forControlEvents:UIControlEventTouchUpInside];
    [blurView.contentView addSubview:closeBtn];
    
    [self.view addSubview:self.cardContainer];
    
    log_overlay("Overlay UI successfully built and ready.");
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    UIView *btn = self.floatingButton;
    CGPoint translation = [recognizer translationInView:self.view];
    
    btn.center = (CGPoint){ btn.center.x + translation.x, btn.center.y + translation.y };
    [recognizer setTranslation:(CGPoint){0, 0} inView:self.view];
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        CGRect screen = [[UIScreen mainScreen] bounds];
        CGFloat btnSize = btn.frame.size.width;
        CGFloat targetX = (btn.center.x < screen.size.width / 2.0) ? (btnSize / 2.0 + 12.0) : (screen.size.width - btnSize / 2.0 - 12.0);
        CGFloat targetY = btn.center.y;
        
        if (targetY < 50.0) targetY = 50.0;
        if (targetY > screen.size.height - 70.0) targetY = screen.size.height - 70.0;
        
        [UIView animateWithDuration:0.25 animations:^{
            btn.center = (CGPoint){ targetX, targetY };
        }];
    }
}

- (void)onButtonTapped {
    log_overlay("Floating button tapped! Expanding card.");
    self.isExpanded = YES;
    self.cardContainer.hidden = NO;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.cardContainer.alpha = 1.0;
        self.floatingButton.alpha = 0.35;
    }];
}

- (void)onCloseTapped {
    log_overlay("Card minimized.");
    [UIView animateWithDuration:0.25 animations:^{
        self.cardContainer.alpha = 0.0;
        self.floatingButton.alpha = 1.0;
    } completion:^(BOOL finished){
        self.isExpanded = NO;
        self.cardContainer.hidden = YES;
    }];
}

@end

static void init_overlay(void) {
    if (g_overlayWindow) return;
    
    log_overlay("Initializing OverlayWindow in SpringBoard...");
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    if (screenBounds.size.width <= 0) {
        log_overlay("Screen bounds not ready yet!");
        return;
    }
    
    g_overlayWindow = [[OverlayWindow alloc] initWithFrame:screenBounds];
    g_overlayWindow.windowLevel = 10000001.0;
    g_overlayWindow.backgroundColor = [UIColor clearColor];
    
    // Attach to active UIWindowScene on iOS 13-16:
    UIApplication *app = [UIApplication sharedApplication];
    if (app) {
        NSSet *scenes = [app connectedScenes];
        log_overlay("Found connectedScenes count: %lu", (unsigned long)[scenes count]);
        id anyScene = [scenes anyObject];
        if (anyScene) {
            g_overlayWindow.windowScene = anyScene;
            log_overlay("Attached g_overlayWindow.windowScene = %p", anyScene);
        }
    }
    
    g_overlayWindow.hidden = NO;
    g_overlayWindow.userInteractionEnabled = YES;
    
    g_overlayVC = [[OverlayViewController alloc] init];
    g_overlayWindow.rootViewController = g_overlayVC;
    [g_overlayWindow makeKeyAndVisible];
    
    log_overlay("OverlayWindow key and visible (windowLevel: %.0f)!", g_overlayWindow.windowLevel);
}

@interface HookHelper : NSObject
- (void)appLaunched:(NSNotification *)notif;
- (void)deferredInit;
@end

@implementation HookHelper
- (void)deferredInit {
    init_overlay();
}

- (void)appLaunched:(NSNotification *)notif {
    log_overlay("Received UIApplicationDidFinishLaunchingNotification!");
    [self performSelectorOnMainThread:@selector(deferredInit) withObject:nil waitUntilDone:NO];
}
@end

static HookHelper *g_helper = nil;

__attribute__((constructor))
static void tweak_entry(void) {
    log_overlay("=================================================");
    log_overlay("onerlay_tweak loaded into process PID: %d", getpid());
    log_overlay("=================================================");
    
    g_helper = [[HookHelper alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:g_helper
                                             selector:@selector(appLaunched:)
                                                 name:[NSString stringWithUTF8String:"UIApplicationDidFinishLaunchingNotification"]
                                               object:nil];
    
    [g_helper performSelectorOnMainThread:@selector(deferredInit) withObject:nil waitUntilDone:NO];
}
