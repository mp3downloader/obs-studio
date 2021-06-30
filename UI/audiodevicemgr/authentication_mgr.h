//  authentication_mgr.h

#import <Cocoa/Cocoa.h>
#import <Security/Authorization.h>

typedef NS_ENUM(NSUInteger, AppleScriptExecuteStatus)
{
    AppleScriptExecuteStatusSuccess,
    AppleScriptExecuteStatusCancel,
    AppleScriptExecuteStatusError
};

@protocol AuthorizationUtilDelegate<NSObject>
- (void)authorizationDidFinish:(int)resultCode;
- (void)authorizationDidFail:(int)resultCode;
- (void)authorizationDidDeauthorize;
- (NSString *)authorizationGetPromptText;
@end


@interface AuthorizationUtil : NSObject
{
    id<AuthorizationUtilDelegate> _delegate;
}

+ (AuthorizationUtil*)sharedInstance;

- (id)delegate;
- (void)setDelegate:(id<AuthorizationUtilDelegate>)delegate;

- (BOOL)authRemovePath:(NSString*)path;
- (BOOL)authCopyPath:(NSString*)srcPath toPath:(NSString*)destPath;

- (AppleScriptExecuteStatus)runAppleScript:(NSString *)script errorDescription:(NSString **)errorDescription;

- (int)getPidOfProcess:(NSString *)theProcess;
- (int)getCoreAudioPid;
- (BOOL)killProcess:(NSString *)theProcess withSignal:(int)signal;


@end
