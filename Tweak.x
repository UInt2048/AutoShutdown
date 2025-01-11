#include <Foundation/Foundation.h>
#include <syslog.h>

#define defaults [[NSUserDefaults alloc] initWithSuiteName:@"com.uint2048.autoshutdown"]
const NSTimeInterval SECONDS_AFTER_UNLOCK = 7200.0;

@interface FBSystemService : NSObject
+(id)sharedInstance;
-(void)shutdownAndReboot:(BOOL)reboot;
@end

%hook SBLockScreenViewControllerBase
    -(void)finishUIUnlockFromSource:(int)source {
        // Immediately get unlock date
        NSDate* currentDate = [NSDate date];
        [defaults setObject:currentDate forKey:@"lastUnlockDate"];
        syslog(LOG_ERR, "[AutoShutdown] New unlock date set!");
        
        // After a while has passed, see if the unlock date has changed, and do something if not
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SECONDS_AFTER_UNLOCK * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
            NSDate* unlockDate = [defaults objectForKey:@"lastUnlockDate"];
            NSDate* newDate = [unlockDate dateByAddingTimeInterval:SECONDS_AFTER_UNLOCK];
            NSComparisonResult result = [[NSDate date] compare:newDate];
            
            // If more than SECONDS_AFTER_UNLOCK have passed (that is, current time >= newDate)
            if (result != NSOrderedAscending) {
                [defaults setObject:[NSDate distantFuture] forKey:@"lastUnlockDate"];
                // Shutdown the device
                syslog(LOG_ERR, "[AutoShutdown] We are shutting down!");
                [[objc_getClass("FBSystemService") sharedInstance] shutdownAndReboot:NO];
            } else {
                syslog(LOG_ERR, "[AutoShutdown] Timer expired but it's not time to shut down!");
            }
        });
        
        // This method is supposed to finish the unlock animation, do it
        %orig(source);
    }
%end