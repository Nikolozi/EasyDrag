#import <Cocoa/Cocoa.h>

CGEventRef eventTapFunction(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon);

#define kEDLeftButtonAssignmentTag @"LeftButtonAssignmentTag"
#define kEDRightButtonAssignmentTag @"RightButtonAssignmentTag"
#define kEDDisableScrollInertiaAssignmentTag @"DisableScrollInertiaAssignmentTag"
#define kEDStartAtLogin @"StartAtLogin"
#define kEDCurrentlyEnabled @"CurrentlyEnabled"
#define kEDDoubleShiftTogglesEasyDrag @"DoubleShiftTogglesEasyDrag"
#define kEDShowHUDWindow @"ShowHUDWindow"

#define kEDHelpURL @"http://nikolozi.com/apps/EasyDrag/Help"
#define kEDCheckForUpdatesURL @"http://nikolozi.com/apps/EasyDrag"

enum {
    kEDfnKeyTag = 1,
    kEDControlKeyTag = 2,
    kEDLeftOptionTag = 3,
    kEDLeftCommandTag = 4,
    kEDRightOptionTag = 5,
    kEDRightCommandTag = 6,
    kEDF1KeyTag = 7,
    kEDF2KeyTag = 8,
    kEDF3KeyTag = 9,
    kEDF4KeyTag = 10,
    kEDGraveTag = 11,
    kEDEscapeTag = 12,
    kEDSpaceTag = 13,
    kEDCapsLockTag = 15,
    kEDShiftTag = 16,
    kEDNoneKeyTag = 99
};

enum {
   kEDLeftOptionMask = 0x80120,
   kEDRightOptionMask = 0x80140,
   kEDLeftCommandMask = 0x100108,
   kEDRightCommandMask = 0x100110,
   kEDControlMask = NSControlKeyMask,
   kEDFunctionMask = NSFunctionKeyMask,
   kEDShiftMask = NSShiftKeyMask,
   kEDCapsLockMask = NSAlphaShiftKeyMask
};

enum {
    kEDF1KeyCode = 122,
    kEDF2KeyCode = 120,
    kEDF3KeyCode = 103,
    kEDF4KeyCode = 111,
    kEDCapsLockKeyCode = 57,
    kEDGraveKeyCode = 50,
    kEDEscapeKeyCode = 53,
    kEDSpaceKeyCode = 49
};

typedef struct {
    BOOL isLeftPressed;
    BOOL isRightPressed;
    CGEventTimestamp lastLeftPressTimestamp;
    CGEventTimestamp secondToLastPressTimestamp;
    NSUInteger clickCount;
} EDMouseState;

@interface NKLZAppDelegate : NSObject <NSApplicationDelegate>

@property (unsafe_unretained) IBOutlet NSWindow *window;
@property (nonatomic) IBOutlet NSButton *startAtLoginCheckBox;
@property (nonatomic) IBOutlet NSPopUpButton *leftMouseAssignmentPopUpButton;
@property (nonatomic) IBOutlet NSPopUpButton *rightMouseAssignmentPopUpButton;
@property (nonatomic) IBOutlet NSPopUpButton *disableScrollInertiaAssignmentPopUpButton;
@property (nonatomic) IBOutlet NSButton *showHUDCheckbox;
@property (nonatomic) IBOutlet NSButton *doubleShiftTogglesEasyDragCheckbox;
@property (nonatomic) IBOutlet NSTextField *appVersionLabel;

@property (nonatomic) NSUserDefaults *userDefaults;

@property (nonatomic) CFMachPortRef machPortRef;
@property (nonatomic) CFRunLoopSourceRef eventSrc;
@property (nonatomic) CFRunLoopRef rl;

@property (nonatomic) EDMouseState mouseState;

@property (nonatomic) NSUInteger assignmentMaskForLeftButton;
@property (nonatomic) NSUInteger assignmentMaskForRightButton;
@property (nonatomic) NSUInteger assignmentKeyCodeForLeftButton;
@property (nonatomic) NSUInteger assignmentKeyCodeForRightButton;
@property (nonatomic) NSUInteger assignmentMaskForDisableScrollInertia;

@property BOOL appIsEnabled;
@property BOOL HUDWindowIsVisible;
@property BOOL doubleShiftTogglesEasyDrag;

- (void)addAppAsLoginItem;
- (void)removeAppFromLoginItem;

- (CGEventRef)leftDownMouseDragToPoint:(CGPoint)point;
- (CGEventRef)rightDownMouseDragToPoint:(CGPoint)point;
- (CGEventRef)leftPressAtPoint:(CGPoint)point withTimestamp:(CGEventTimestamp)timestamp;
- (CGEventRef)leftReleaseAtPoint:(CGPoint)point;
- (CGEventRef)rightPressAtPoint:(CGPoint)point;
- (CGEventRef)rightReleaseAtPoint:(CGPoint)point;

- (void)loadUserDefaults;
- (void)initAssignmentsForButton:(NSUInteger)buttonIndex withTag:(NSUInteger)tag;
- (void)setCorrectStatesForAssignableKeys;
- (void)setStatusMenuState;

- (IBAction)enabled:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)showHUDWindow:(id)sender;

//helper
+ (BOOL)isFKeyCode:(NSUInteger)code;

@end
