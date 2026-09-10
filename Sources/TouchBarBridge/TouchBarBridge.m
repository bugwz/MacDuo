#import "TouchBarBridge.h"
#import <dlfcn.h>

// Undocumented APIs. Check all selectors and symbols before use; do not link
// DFRFoundation at load time so unsupported systems can still launch the app.
@interface NSTouchBarItem (MacDuoSystemTray)
+ (void)addSystemTrayItem:(NSTouchBarItem *)item;
+ (void)removeSystemTrayItem:(NSTouchBarItem *)item;
@end
@interface NSTouchBar (MacDuoSystemModal)
+ (void)presentSystemModalTouchBar:(NSTouchBar *)bar systemTrayItemIdentifier:(NSString *)identifier;
+ (void)dismissSystemModalTouchBar:(NSTouchBar *)bar;
@end

typedef void (*CloseBoxFunction)(BOOL);
static CloseBoxFunction closeBox;
typedef void (*PresenceFunction)(NSString *, BOOL);
static PresenceFunction presence(void) {
    static PresenceFunction function;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_LAZY | RTLD_LOCAL);
        if (handle) {
            function = (PresenceFunction)dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier");
            closeBox = (CloseBoxFunction)dlsym(handle, "DFRSystemModalShowsCloseBoxWhenFrontMost");
        }
        // Keep the handle alive for the lifetime of the function pointer.
    });
    return function;
}
BOOL MDTBInstall(NSTouchBarItem *item) {
    if (!presence() || ![NSTouchBarItem respondsToSelector:@selector(addSystemTrayItem:)] ||
        ![NSTouchBarItem respondsToSelector:@selector(removeSystemTrayItem:)] ||
        ![NSTouchBar respondsToSelector:@selector(presentSystemModalTouchBar:systemTrayItemIdentifier:)] ||
        ![NSTouchBar respondsToSelector:@selector(dismissSystemModalTouchBar:)]) return NO;
    @try {
        if (closeBox) closeBox(YES);
        [NSTouchBarItem addSystemTrayItem:item];
        presence()(item.identifier, YES);
        return YES;
    } @catch (NSException *exception) {
        MDTBRemove(item);
        return NO;
    }
}
void MDTBRemove(NSTouchBarItem *item) {
    @try {
        if (presence()) presence()(item.identifier, NO);
        if ([NSTouchBarItem respondsToSelector:@selector(removeSystemTrayItem:)])
            [NSTouchBarItem removeSystemTrayItem:item];
    } @catch (NSException *exception) { }
}
BOOL MDTBPresent(NSTouchBar *bar, NSString *identifier) {
    @try {
        if (![NSTouchBar respondsToSelector:@selector(presentSystemModalTouchBar:systemTrayItemIdentifier:)]) return NO;
        // Let AppKit select the placement. Do not force a private placement value
        // that can replace the system controls with an empty modal surface.
        [NSTouchBar presentSystemModalTouchBar:bar systemTrayItemIdentifier:identifier];
        return YES;
    } @catch (NSException *exception) { return NO; }
}
void MDTBDismiss(NSTouchBar *bar) {
    @try {
        if ([NSTouchBar respondsToSelector:@selector(dismissSystemModalTouchBar:)])
            [NSTouchBar dismissSystemModalTouchBar:bar];
    } @catch (NSException *exception) { }
}
