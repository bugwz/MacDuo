#import <AppKit/AppKit.h>
NS_ASSUME_NONNULL_BEGIN
BOOL MDTBInstall(NSTouchBarItem *item);
void MDTBRemove(NSTouchBarItem *item);
BOOL MDTBPresent(NSTouchBar *bar, NSString *identifier);
void MDTBDismiss(NSTouchBar *bar);
NS_ASSUME_NONNULL_END
