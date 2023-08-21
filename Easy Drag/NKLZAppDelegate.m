#import <IOKit/hid/IOHIDManager.h>

#import "NKLZAppDelegate.h"
#import "EDHUDWindow.h"

@interface NKLZAppDelegate ()
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) IBOutlet NSMenu *statusMenu;
@property (strong, nonatomic) IBOutlet NSWindow *notificationWindow;
@property (strong, nonatomic) IBOutlet NSTextField *notificationLabel;

@property (strong, nonatomic) NSImage *statusIconImageOffState;
@property (strong, nonatomic) NSImage *statusIconImageOnState;
@end

@implementation NKLZAppDelegate

- (void)dealloc
{
   if(_eventSrc) CFRelease(_eventSrc);
   if(_machPortRef)  CFRelease(_machPortRef);
}

CFMutableDictionaryRef myCreateDeviceMatchingDictionary(UInt32 usagePage, UInt32 usage);
CFMutableDictionaryRef myCreateDeviceMatchingDictionary(UInt32 usagePage, UInt32 usage)
{
    CFMutableDictionaryRef ret = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                           0, &kCFTypeDictionaryKeyCallBacks,
                                                           &kCFTypeDictionaryValueCallBacks);
    if (!ret)
        return NULL;
    
    CFNumberRef pageNumberRef = CFNumberCreate(kCFAllocatorDefault,
                                               kCFNumberIntType, &usagePage );
    if (!pageNumberRef) {
        CFRelease(ret);
        return NULL;
    }
    
    CFDictionarySetValue(ret, CFSTR(kIOHIDDeviceUsagePageKey), pageNumberRef);
    CFRelease(pageNumberRef);
    
    CFNumberRef usageNumberRef = CFNumberCreate(kCFAllocatorDefault,
                                                kCFNumberIntType, &usage);
    if (!usageNumberRef) {
        CFRelease(ret);
        return NULL;
    }
    
    CFDictionarySetValue(ret, CFSTR(kIOHIDDeviceUsageKey), usageNumberRef);
    CFRelease(usageNumberRef);
    
    return ret;
}

void myHIDKeyboardCallback(void *context, IOReturn result, void *sender, IOHIDValueRef value);
void myHIDKeyboardCallback(void *context, IOReturn result, void *sender, IOHIDValueRef value)
{
    NKLZAppDelegate *delegate = [NSApp delegate];

    IOHIDElementRef elem = IOHIDValueGetElement(value);
    if (IOHIDElementGetUsagePage(elem) != 0x07) return;

    uint32_t keyCode = IOHIDElementGetUsage(elem);
    if(keyCode != kEDCapsLockKeyCode) return;

    long pressed = IOHIDValueGetIntegerValue(value);

    CGEventRef event = CGEventCreate(NULL);
    CGEventTimestamp timestamp = (CGEventTimestamp)([NSDate timeIntervalSinceReferenceDate]*1000000000);

    if([delegate assignmentKeyCodeForLeftButton] == kEDCapsLockKeyCode) {
        if(pressed == 1) event = [delegate leftPressAtPoint:CGEventGetLocation(event) withTimestamp:timestamp];
        else event = [delegate leftReleaseAtPoint:CGEventGetLocation(event)];
    }
    else if([delegate assignmentKeyCodeForRightButton] == kEDCapsLockKeyCode) { 
        if(pressed == 1) event = [delegate rightPressAtPoint:CGEventGetLocation(event)];
        else event = [delegate rightReleaseAtPoint:CGEventGetLocation(event)];
    }
    
    CGEventPost(kCGHIDEventTap, event);
}


#pragma mark - IBActions

- (IBAction)showPreferences:(id)sender
{
   [NSApp activateIgnoringOtherApps:YES];
   [_window makeKeyAndOrderFront:self];
}

- (IBAction)keyAssignmentChanged:(id)sender
{
   NSPopUpButton *popUpButton = sender;
   [self initAssignmentsForButton:[popUpButton tag] withTag:[popUpButton selectedTag]];
   [self setCorrectStatesForAssignableKeys];
}

- (IBAction)enabled:(id)sender
{
   _appIsEnabled = !_appIsEnabled;
   [_userDefaults setBool:_appIsEnabled forKey:kEDCurrentlyEnabled];
   [self setStatusMenuState];
}


- (IBAction)showHUDWindow:(id)sender
{
   if(sender == _showHUDCheckbox) {
      _HUDWindowIsVisible = ([_showHUDCheckbox state] == NSOnState);
   }
   else if ([sender isKindOfClass:[EDHUDWindow class]]) { //performClose called this
      _HUDWindowIsVisible = NO; 
      [_userDefaults setBool:NO forKey:kEDShowHUDWindow];
      [_showHUDCheckbox setState:NSOffState];
      return;
   }
   
   if(_HUDWindowIsVisible) {
      [_notificationWindow setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
      [_notificationWindow makeKeyAndOrderFront:self];
   }
   else {
      [_notificationWindow resignKeyWindow];
      [_notificationWindow orderOut:self];
      [_notificationWindow close];
   }
   
   [_userDefaults setBool:_HUDWindowIsVisible forKey:kEDShowHUDWindow];
   [_showHUDCheckbox setState:_HUDWindowIsVisible ? NSOnState : NSOffState];
}

- (IBAction)doubleShiftTogglesEasyDrag:(id)sender
{
   _doubleShiftTogglesEasyDrag = [_doubleShiftTogglesEasyDragCheckbox state] == NSOnState;
   [_userDefaults setBool:_doubleShiftTogglesEasyDrag forKey:kEDDoubleShiftTogglesEasyDrag];
}

- (IBAction)startAtLogin:(id)sender
{
   if([_startAtLoginCheckBox state] == NSOnState) {
      NSLog(@"Check startAtLogin");
      [self addAppAsLoginItem];
      [_userDefaults setBool:YES forKey:kEDStartAtLogin];
   }
   else {
      NSLog(@"Uncheck startAtLogin");
      [self removeAppFromLoginItem];
      [_userDefaults setBool:NO forKey:kEDStartAtLogin];
   }
}

#pragma mark - Add/Remove app to Login Items
- (void)addAppAsLoginItem
{
	NSString * appPath = [[NSBundle mainBundle] bundlePath];
	CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath]; 
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                           kLSSharedFileListSessionLoginItems, NULL);
	if (loginItems) {
		//Insert an item to the list.
		LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems,
                                                                   kLSSharedFileListItemLast, NULL, NULL,
                                                                   url, NULL, NULL);
		if (item){
			CFRelease(item);
      }
	}	
   
	CFRelease(loginItems);
}

- (void)removeAppFromLoginItem
{
	NSString * appPath = [[NSBundle mainBundle] bundlePath];
	CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
   
	if (loginItems) {
		UInt32 seedValue;
		NSArray  *loginItemsArray = (__bridge NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
		for(int i = 0; i < [loginItemsArray count]; i++) {
			LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)[loginItemsArray objectAtIndex:i];
			//Resolve the item with URL
			if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &url, NULL) == noErr) {
				NSString *urlPath = [(__bridge NSURL*)url path];
				if ([urlPath caseInsensitiveCompare:appPath] == NSOrderedSame) {
					LSSharedFileListItemRemove(loginItems, itemRef);
				}
			}
		}
	}
}

#pragma mark - Event Handling

- (CGEventRef)leftDownMouseDragToPoint:(CGPoint)point
{
   return CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDragged, point, kCGMouseButtonLeft);
}

- (CGEventRef)rightDownMouseDragToPoint:(CGPoint)point
{
   return CGEventCreateMouseEvent(NULL, kCGEventRightMouseDragged, point, kCGMouseButtonRight);
}

- (CGEventRef)leftPressAtPoint:(CGPoint)point withTimestamp:(CGEventTimestamp)timestamp
{
   CGEventRef event = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, point, kCGMouseButtonLeft);

       if(timestamp - _mouseState.secondToLastPressTimestamp < [NSEvent doubleClickInterval] * 1000000000 * 2 && _mouseState.clickCount == 2) {
          _mouseState.clickCount = 3;
          //NSLog(@"Triple click");
       } else if(timestamp - _mouseState.lastLeftPressTimestamp < [NSEvent doubleClickInterval] * 1000000000 && _mouseState.clickCount == 1) {
          _mouseState.clickCount = 2;
          //NSLog(@"Double click");
       } else {
          _mouseState.clickCount = 1;
       }

   
   CGEventSetIntegerValueField(event, kCGMouseEventClickState, _mouseState.clickCount);
   _mouseState.secondToLastPressTimestamp  = _mouseState.lastLeftPressTimestamp;
   _mouseState.lastLeftPressTimestamp  = timestamp;
   _mouseState.isLeftPressed = YES;
   return event;
}

- (CGEventRef)leftReleaseAtPoint:(CGPoint)point
{
   CGEventRef event = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, point, kCGMouseButtonLeft);
   CGEventSetIntegerValueField(event, kCGMouseEventClickState, _mouseState.clickCount);
   _mouseState.isLeftPressed = NO;
   return event;
}

- (CGEventRef)rightPressAtPoint:(CGPoint)point
{
   CGEventRef event = CGEventCreateMouseEvent(NULL, kCGEventRightMouseDown, point, kCGMouseButtonRight);
   CGEventSetIntegerValueField(event, kCGMouseEventClickState, 1);
   _mouseState.isRightPressed = YES;
   return event;
}

- (CGEventRef)rightReleaseAtPoint:(CGPoint)point
{
   CGEventRef event = CGEventCreateMouseEvent(NULL, kCGEventRightMouseUp, point, kCGMouseButtonRight);
   CGEventSetIntegerValueField(event, kCGMouseEventClickState, 1);
   _mouseState.isRightPressed = NO;
   return event;
}

CGEventRef eventTapFunction(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
   //if([[NSEvent eventWithCGEvent:event] type] != NSMouseMoved)
   //NSLog(@"Event type - %ul  actual reported - %ul event: %@", CGEventGetType(event), type, [NSEvent eventWithCGEvent:event]);

   NKLZAppDelegate *delegate = (__bridge NKLZAppDelegate *)refcon;
   
   //If tap is disabled for some reason re-enable it
   if(type == kCGEventTapDisabledByTimeout) {
      NSLog(@"kCGEventTapDisabledByTimeout");
      CGEventTapEnable(delegate.machPortRef, true);
   } else if(type == kCGEventTapDisabledByUserInput) {
      NSLog(@"kCGEventTapDisabledByUserInput");
      CGEventTapEnable(delegate.machPortRef, true);
   } else if(type == kCGEventNull) {
      NSLog(@"kCGEventNull");
   }
   
   CGEventFlags flags = CGEventGetFlags(event);
   CGKeyCode keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
   
   //If shift double-pressed toggle Easy Drag
   if(delegate.doubleShiftTogglesEasyDrag) {
      static CGEventTimestamp lastShiftReleasedTimestamp = 0;
      static BOOL lastReleaseWasShift = NO;
      if (type == kCGEventFlagsChanged) {
         if ((flags & kEDShiftMask) != 0) {
            lastReleaseWasShift = YES;
         } else if(lastReleaseWasShift) { //i.e. Releasing
            lastReleaseWasShift = NO;
            CGEventTimestamp shiftPressedTimestamp = CGEventGetTimestamp(event); //Release time
            if(shiftPressedTimestamp - lastShiftReleasedTimestamp < [NSEvent doubleClickInterval]*1000000000) {
               //NSLog(@"Toggle Easy Drag");
               lastShiftReleasedTimestamp = 0;
               lastReleaseWasShift = NO;
               [delegate enabled:delegate];
            }
            else {
               lastShiftReleasedTimestamp = shiftPressedTimestamp;
            }
         }
      } else if (type == kCGEventKeyDown) {
         lastShiftReleasedTimestamp = 0;
         lastReleaseWasShift = NO;
      }
   }
   
   if(!delegate.appIsEnabled) {
      return event;
   }

   BOOL leftDown = delegate->_mouseState.isLeftPressed;
   BOOL rightDown = delegate->_mouseState.isRightPressed;
    NSUInteger assignedLeftMask = [delegate assignmentMaskForLeftButton]; //Test for zero and return if zero
    NSUInteger assignedRightMask = [delegate assignmentMaskForRightButton];
    NSUInteger assignedLeftKeyCode = [delegate assignmentKeyCodeForLeftButton];
    NSUInteger assignedRightKeyCode = [delegate assignmentKeyCodeForRightButton];
    NSUInteger assignedMaskDisableScrollInertia = [delegate assignmentMaskForDisableScrollInertia];
    
   //If Fn key is not assigned to anything it can be used to toggle the assigned key functionality to it's orginal function
   //Except F1-F12, system takes care of that
    if((assignedLeftMask != kEDFunctionMask) &&
       (assignedRightMask != kEDFunctionMask) &&
       (assignedMaskDisableScrollInertia != kEDFunctionMask) &&
      ((flags & kEDFunctionMask) != 0) && 
      ![NKLZAppDelegate isFKeyCode:keyCode]) {
      CGEventSetFlags(event, flags & (~kEDFunctionMask));
      return event;
   }
   switch (type) {
      case kCGEventFlagsChanged:
         if(assignedLeftMask != 0 && (flags & assignedLeftMask) == assignedLeftMask && !leftDown) {
            event = [delegate leftPressAtPoint:CGEventGetLocation(event) withTimestamp:CGEventGetTimestamp(event)];
         } else if(assignedLeftMask != 0 && (flags & assignedLeftMask) != assignedLeftMask && leftDown) {
            event = [delegate leftReleaseAtPoint:CGEventGetLocation(event)];
         } else if(assignedRightMask != 0 && (flags & assignedRightMask) == assignedRightMask && !rightDown) {
            event = [delegate rightPressAtPoint:CGEventGetLocation(event)];
         } else if(assignedRightMask != 0 && (flags & assignedRightMask) != assignedRightMask && rightDown) {
            event = [delegate rightReleaseAtPoint:CGEventGetLocation(event)];
         }
         break;
      case kCGEventKeyDown:
         if(assignedLeftKeyCode != 0 && keyCode == assignedLeftKeyCode) {
            if(!leftDown) {
               //NSLog(@"Left down");
               event = [delegate leftPressAtPoint:CGEventGetLocation(event) withTimestamp:CGEventGetTimestamp(event)];
            } else {
               event = NULL; //Eliminte key repeats
            }
         } else if(assignedRightKeyCode != 0 && keyCode == assignedRightKeyCode) {
            if(!rightDown) {
               //NSLog(@"Right down");
               event = [delegate rightPressAtPoint:CGEventGetLocation(event)];
            } else {
               event = NULL; //Eliminte key repeats
            }
         }
         break;
      case kCGEventKeyUp:
         if(assignedLeftKeyCode != 0 && keyCode == assignedLeftKeyCode) {
            //NSLog(@"Left up");
            event = [delegate leftReleaseAtPoint:CGEventGetLocation(event)];
         } else if(assignedRightKeyCode != 0 && keyCode == assignedRightKeyCode) {
            //NSLog(@"Right up");
            event = [delegate rightReleaseAtPoint:CGEventGetLocation(event)];
         }
         break;
      case kCGEventMouseMoved:
         //Reset mouse click count as the mouse has moved
         delegate->_mouseState.secondToLastPressTimestamp  = 0;
         delegate->_mouseState.lastLeftPressTimestamp  = 0;
         if(leftDown) {
            //NSLog(@"Left drag");
            event = [delegate leftDownMouseDragToPoint:CGEventGetLocation(event)];
         } else if(rightDown) {
            //NSLog(@"Right drag");
            event = [delegate rightDownMouseDragToPoint:CGEventGetLocation(event)];
         }
         break;
       case kCGEventScrollWheel:
       {
           NSEvent *nsEvent = [NSEvent eventWithCGEvent:event];
           if([nsEvent respondsToSelector:@selector(momentumPhase)]) {
               static BOOL momentumDecayed = YES;
               NSUInteger scrollInertiaBypassFlagMask = delegate->_assignmentMaskForDisableScrollInertia;
               if (scrollInertiaBypassFlagMask == 0) break; //i.e. not assigned
               
               BOOL bypassFlagIsOn = (flags & scrollInertiaBypassFlagMask) == scrollInertiaBypassFlagMask;

               if(([nsEvent momentumPhase] != NSEventPhaseNone) && bypassFlagIsOn) {
                   momentumDecayed = NO;
                   event = NULL; //Eliminate inertia
               } else if ([nsEvent momentumPhase] == NSEventPhaseNone) {
                   momentumDecayed = YES;
               } else if (!momentumDecayed) {
                   event = NULL; //Eliminate inertia
               }
           }
           break;
       }
         
      default:
         break;
   }
   return event;

}

- (void)eventThread:(id)object
{
    self.machPortRef =  CGEventTapCreate(kCGHIDEventTap,
                                        kCGTailAppendEventTap,
                                        kCGEventTapOptionDefault,
                                        CGEventMaskBit(kCGEventFlagsChanged) |
                                        CGEventMaskBit(kCGEventMouseMoved)   |
                                        CGEventMaskBit(kCGEventScrollWheel)  |
                                        CGEventMaskBit(kCGEventKeyUp)        |
                                        CGEventMaskBit(kCGEventKeyDown),
                                        (CGEventTapCallBack)eventTapFunction,
                                        (__bridge void *)(self));
    if (self.machPortRef == NULL) {
        NSLog(@"CGEventTapCreate failed!");
    } else {
        self.eventSrc = CFMachPortCreateRunLoopSource(NULL, self.machPortRef, 0);
        if ( self.eventSrc == NULL ) {
            NSLog(@"No event run loop src?");
        } else {
            CFRunLoopRef runLoop =  CFRunLoopGetCurrent(); 
            CFRunLoopAddSource(runLoop, self.eventSrc, kCFRunLoopDefaultMode);
            
            //Caps Lock detection
            IOHIDManagerRef hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
            CFMutableDictionaryRef keyboard = myCreateDeviceMatchingDictionary(0x01, 6);
            CFMutableDictionaryRef keypad = myCreateDeviceMatchingDictionary(0x01, 7);
            CFMutableDictionaryRef matchesList[] = { keyboard, keypad };
            CFArrayRef matches = CFArrayCreate(kCFAllocatorDefault, (const void **)matchesList, 2, NULL);
            IOHIDManagerSetDeviceMatchingMultiple(hidManager, matches);
            IOHIDManagerRegisterInputValueCallback(hidManager, myHIDKeyboardCallback, NULL);
            IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
            IOHIDManagerOpen(hidManager, kIOHIDOptionsTypeNone);
            
            CFRunLoopRun();
        }
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{    
    //Reset mouse state
    _mouseState.isLeftPressed = NO;
    _mouseState.isRightPressed = NO;
    _mouseState.lastLeftPressTimestamp = 0;
    _mouseState.secondToLastPressTimestamp = 0;
    _mouseState.clickCount = 1;

    [self loadUserDefaults];

    //Load version Number
    NSDictionary *appInfo = [[NSBundle mainBundle] infoDictionary];
    _appVersionLabel.stringValue = [NSString stringWithFormat:@"%@ %@", appInfo[@"CFBundleDisplayName"], appInfo[@"CFBundleShortVersionString"]];
    
    //Status Menu
    _statusIconImageOffState = nil;
    _statusIconImageOnState = nil;
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.menu = self.statusMenu;
    [self setStatusMenuState];
    _statusItem.highlightMode = YES;

    //Events thread
    [NSThread detachNewThreadSelector:@selector(eventThread:) toTarget:self withObject:nil];
}

- (void)loadUserDefaults
{
    _userDefaults = [[NSUserDefaults alloc] init];
    NSMutableDictionary *defaultsDictionary = [[NSMutableDictionary alloc] initWithCapacity:4];
    [defaultsDictionary setObject:[NSNumber numberWithBool:NO] forKey:kEDStartAtLogin];
    [defaultsDictionary setObject:[NSNumber numberWithBool:YES] forKey:kEDDoubleShiftTogglesEasyDrag];
    [defaultsDictionary setObject:[NSNumber numberWithBool:YES] forKey:kEDCurrentlyEnabled];
    [defaultsDictionary setObject:[NSNumber numberWithBool:YES] forKey:kEDShowHUDWindow];
    [defaultsDictionary setObject:[NSNumber numberWithInteger:kEDfnKeyTag] forKey:kEDLeftButtonAssignmentTag];
    [defaultsDictionary setObject:[NSNumber numberWithInteger:kEDNoneKeyTag] forKey:kEDRightButtonAssignmentTag];
    [_userDefaults registerDefaults:defaultsDictionary];

    //Actual loading
    _appIsEnabled = [_userDefaults boolForKey:kEDCurrentlyEnabled];
    _HUDWindowIsVisible = [_userDefaults boolForKey:kEDShowHUDWindow];
    [self showHUDWindow:self];
    [self initAssignmentsForButton:0
                           withTag:[_userDefaults integerForKey:kEDLeftButtonAssignmentTag]];
    [self initAssignmentsForButton:1
                           withTag:[_userDefaults integerForKey:kEDRightButtonAssignmentTag]];
    [self initAssignmentsForButton:2
                           withTag:[_userDefaults integerForKey:kEDDisableScrollInertiaAssignmentTag]];
    [self.leftMouseAssignmentPopUpButton selectItemWithTag:[_userDefaults integerForKey:kEDLeftButtonAssignmentTag]];
    [self.rightMouseAssignmentPopUpButton selectItemWithTag:[_userDefaults integerForKey:kEDRightButtonAssignmentTag]];
    [self setCorrectStatesForAssignableKeys];
    self.startAtLoginCheckBox.state = [_userDefaults boolForKey:kEDStartAtLogin] ? NSOnState : NSOffState;
    _doubleShiftTogglesEasyDrag = [_userDefaults boolForKey:kEDDoubleShiftTogglesEasyDrag];
    _doubleShiftTogglesEasyDragCheckbox.state = _doubleShiftTogglesEasyDrag ?  NSOnState : NSOffState;
}

//0 is leftbutton, 1 is a right button
- (void)initAssignmentsForButton:(NSUInteger)buttonIndex withTag:(NSUInteger)tag
{
    NSUInteger assignmentMask = 0;
    NSUInteger assignmentKeyCode = 0;

    switch (tag) {
        case kEDfnKeyTag:
            assignmentMask = kEDFunctionMask;
            break;
        case kEDShiftTag:
            assignmentMask = kEDShiftMask;
            break;
        case kEDControlKeyTag:
            assignmentMask = kEDControlMask;
            break;
        case kEDLeftOptionTag:
            assignmentMask = kEDLeftOptionMask;
            break;
        case kEDLeftCommandTag:
            assignmentMask = kEDLeftCommandMask;
            break;
        case kEDRightOptionTag:
            assignmentMask = kEDRightOptionMask;
            break;
        case kEDRightCommandTag:
            assignmentMask = kEDRightCommandMask;
            break;
        case kEDCapsLockTag:
            assignmentKeyCode = kEDCapsLockKeyCode;
            break;
        case kEDF1KeyTag:
            assignmentKeyCode = kEDF1KeyCode;
            break;
        case kEDF2KeyTag:
            assignmentKeyCode = kEDF2KeyCode;
            break;
        case kEDF3KeyTag:
            assignmentKeyCode = kEDF3KeyCode;
            break;
        case kEDF4KeyTag:
            assignmentKeyCode = kEDF4KeyCode;
            break;
        case kEDGraveTag:
            assignmentKeyCode = kEDGraveKeyCode;
            break;
        case kEDEscapeTag:
            assignmentKeyCode = kEDEscapeKeyCode;
            break;
        case kEDSpaceTag:
            assignmentKeyCode = kEDSpaceKeyCode;
            break;
        case kEDNoneKeyTag:
            assignmentKeyCode = 0;
            break;

        default:
            NSLog(@"--------- Not a possible case!!");
            break;
    }

    if(buttonIndex == 0) { //left mouse button assignment
        self.assignmentKeyCodeForLeftButton = assignmentKeyCode;
        self.assignmentMaskForLeftButton = assignmentMask;
        [_userDefaults setInteger:tag forKey:kEDLeftButtonAssignmentTag];
    } else if(buttonIndex == 1) {  //right button
        self.assignmentKeyCodeForRightButton = assignmentKeyCode;
        self.assignmentMaskForRightButton = assignmentMask;
        [_userDefaults setInteger:tag forKey:kEDRightButtonAssignmentTag];
    } else if(buttonIndex == 2) {  //scroll inertia bypass
        self.assignmentMaskForDisableScrollInertia = assignmentMask;
        [_userDefaults setInteger:tag forKey:kEDDisableScrollInertiaAssignmentTag];
    }
}
    
- (void)setCorrectStatesForAssignableKeys
{
    //Disable some items so user can't make the same assignments for both mouse buttons
    for(NSMenuItem *menuItem in self.leftMouseAssignmentPopUpButton.itemArray) {
        [menuItem setEnabled:YES];
    }

    for(NSMenuItem *menuItem in self.rightMouseAssignmentPopUpButton.itemArray) {
        [menuItem setEnabled:YES];
    }

    for(NSMenuItem *menuItem in self.disableScrollInertiaAssignmentPopUpButton.itemArray) {
        [menuItem setEnabled:YES];
    }
   
    NSString *blankAssignmentTitle = [[self.leftMouseAssignmentPopUpButton.itemArray lastObject] title];
    
    NSString *selectedItemName = self.leftMouseAssignmentPopUpButton.selectedItem.title;
    if(![selectedItemName isEqualToString:blankAssignmentTitle]) {
        [[self.rightMouseAssignmentPopUpButton itemWithTitle:selectedItemName] setEnabled:NO];
        [[self.disableScrollInertiaAssignmentPopUpButton itemWithTitle:selectedItemName] setEnabled:NO];
    }
    
    selectedItemName = self.rightMouseAssignmentPopUpButton.selectedItem.title;
    if(![selectedItemName isEqualToString:blankAssignmentTitle]) {
        [[self.leftMouseAssignmentPopUpButton itemWithTitle:selectedItemName] setEnabled:NO];
        [[self.disableScrollInertiaAssignmentPopUpButton itemWithTitle:selectedItemName] setEnabled:NO];
    }
   
    selectedItemName = self.disableScrollInertiaAssignmentPopUpButton.selectedItem.title;
    if(![selectedItemName isEqualToString:blankAssignmentTitle]) {
        [[self.leftMouseAssignmentPopUpButton itemWithTitle:selectedItemName] setEnabled:NO];
        [[self.rightMouseAssignmentPopUpButton itemWithTitle:selectedItemName] setEnabled:NO];
    }
}

- (void)setStatusMenuState
{
   NSMenuItem *isEnabledStateDescription = [self.statusMenu itemAtIndex:0];
   NSMenuItem *isEnabledMenuItem = [self.statusMenu itemAtIndex:1];
   isEnabledStateDescription.title = _appIsEnabled ? @"Easy Drag: On" : @"Easy Drag: Off";
   isEnabledMenuItem.title = _appIsEnabled ? @"Turn Easy Drag Off" : @"Turn Easy Drag On";
    
    if(_appIsEnabled) {
        _notificationLabel.textColor = [NSColor whiteColor];
    } else {
        _notificationLabel.textColor = [NSColor grayColor];
    }
    
    if(_statusIconImageOffState == nil) {
        NSImage* statusIcon = [[NSImage alloc] initWithSize:NSMakeSize(18, 20)];
        [statusIcon lockFocus];
        NSMutableAttributedString *statusIconAttributedString = [[NSMutableAttributedString alloc] initWithString:@"⤴"];
        [statusIconAttributedString addAttribute:NSFontAttributeName
                                           value:[NSFont fontWithName:@"PilGi" size:19]
                                           range:NSMakeRange(0, 1)];
        [statusIconAttributedString addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(0, 1)];
        [statusIconAttributedString drawWithRect:NSMakeRect(0, 3, 18, 20) options:NSStringDrawingUsesFontLeading];
        [statusIcon unlockFocus];
        _statusIconImageOnState = statusIcon;
        
        statusIcon = [[NSImage alloc] initWithSize:NSMakeSize(18, 20)];
        [statusIcon lockFocus];
        statusIconAttributedString = [[NSMutableAttributedString alloc] initWithString:@"⤴"];
        [statusIconAttributedString addAttribute:NSFontAttributeName
                                           value:[NSFont fontWithName:@"PilGi" size:19]
                                           range:NSMakeRange(0, 1)];
        [statusIconAttributedString addAttribute:NSForegroundColorAttributeName value:[NSColor grayColor] range:NSMakeRange(0, 1)];
        [statusIconAttributedString drawWithRect:NSMakeRect(0, 3, 18, 20) options:NSStringDrawingUsesFontLeading];
        [statusIcon unlockFocus];
        _statusIconImageOffState = statusIcon;
    }
    
    NSImage* itemImage = _appIsEnabled ? _statusIconImageOnState : _statusIconImageOffState;
   
   [_statusItem setImage:itemImage];
}

- (IBAction)checkForUpdates:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kEDCheckForUpdatesURL]];
}


- (IBAction)openHelp:(id)sender
{
   [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kEDHelpURL]];
}

//helper functions
+ (BOOL)isFKeyCode:(NSUInteger)code
{
   switch (code) {
      case kEDF1KeyCode:
      case kEDF2KeyCode:
      case kEDF3KeyCode:
      case kEDF4KeyCode:
         return YES;
      default:
         return NO;
   }
}

@end
