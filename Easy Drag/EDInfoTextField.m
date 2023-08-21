#import "EDInfoTextField.h"
#import "NKLZAppDelegate.h"

@interface EDInfoTextField ()
@property (assign, nonatomic) BOOL dragged;
@end

@implementation EDInfoTextField
@synthesize dragged = _dragged;

- (void)mouseDown:(NSEvent *)theEvent
{
   [self setTextColor:[NSColor grayColor]];
}

- (void)mouseUp:(NSEvent *)theEvent
{
   if(!_dragged) {
      NKLZAppDelegate *delegate = [NSApp delegate];
      [delegate showPreferences:self];
      [self setTextColor:[NSColor whiteColor]];
   }
   _dragged = NO;
}
 
- (void)mouseDragged:(NSEvent *)theEvent
{
   [self setTextColor:[NSColor whiteColor]];
   _dragged = YES;
}

@end
