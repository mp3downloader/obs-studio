//  authentication_mgr.h

#import <Cocoa/Cocoa.h>
#import <Security/Authorization.h>

typedef NS_ENUM(NSUInteger, AppleScriptExecuteStatus)
{
    AppleScriptExecuteStatusSuccess,
    AppleScriptExecuteStatusCancel,
    AppleScriptExecuteStatusError
};

@interface NSObject (AuthorizationUtilDelegate)
- (void)authorizationDidFinish:(int)resultCode;
- (void)authorizationDidFail:(int)resultCode;
- (void)authorizationDidDeauthorize;
- (NSString *)authorizationGetPromptText;
@end


@interface AuthorizationUtil : NSObject
{
    AuthorizationRef _authorizationRef;
    id _delegate;
}

+ (AuthorizationUtil*)sharedInstance;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (OSStatus)isAuthorizedForCommand:(NSString *)theCommand;
- (OSStatus)authorizeForCommand:(NSString *)theCommand;
- (void)deauthorize;

- (int)getPidOfProcess:(NSString *)theProcess;

- (OSStatus)executeCommand:(NSString *)cmdPath withArgs:(NSArray *)arguments;
- (OSStatus)executeCommandSynced:(NSString *)cmdPath withArgs:(NSArray *)arguments;

- (BOOL)killProcess:(NSString *)theProcess withSignal:(int)signal;
- (BOOL)authRemovePath:(NSString*)path;
- (BOOL)authCopyPath:(NSString*)srcPath toPath:(NSString*)destPath;

- (AppleScriptExecuteStatus)runAppleScript:(NSString *)script errorDescription:(NSString **)errorDescription;

@end
