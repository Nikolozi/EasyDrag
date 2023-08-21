#import "EDHUDWindow.h"
#import "NKLZAppDelegate.h"

@implementation EDHUDWindow

- (void)awakeFromNib
{
   [super awakeFromNib];
   [self setDelegate:self];
}

- (void)windowWillClose:(NSNotification *)notification
{
   NKLZAppDelegate *delegate = [NSApp delegate];
   [delegate showHUDWindow:self];
}

@end
