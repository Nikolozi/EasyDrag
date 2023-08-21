#import "EDTextField.h"
#import "NKLZAppDelegate.h"

@interface EDTextField ()
@property (assign, nonatomic) BOOL dragged;
@end

@implementation EDTextField
@synthesize dragged = _dragged;

- (void)mouseUp:(NSEvent *)theEvent
{
   if(!_dragged) {
      NKLZAppDelegate *delegate = [NSApp delegate];
      [delegate enabled:self];
   }
   _dragged = NO;
}

- (void)mouseDragged:(NSEvent *)theEvent
{
   _dragged = YES;
}

@end
