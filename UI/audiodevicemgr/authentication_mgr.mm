#import "authentication_mgr.h"

#include <sys/sysctl.h>
#include <pwd.h>
#import <Security/AuthorizationTags.h>


typedef struct kinfo_proc kinfo_proc;

static NSString* const kAudioShareProcessID = @"AudioShareProcessID";
static NSString* const kAudioShareProcessName = @"AudioShareProcessName";
static NSString* const kAudioShareProcessUserId = @"AudioShareProcessUserId";
static NSString* const kAudioShareProcessUserName = @"AudioShareProcessUserName";

static int getBSDProcessList(kinfo_proc **processList, size_t *processCount)
{
    int                 nErr;
    kinfo_proc *        resultProcList;
    bool                done;
    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    size_t              length;
    
    *processCount = 0;
    resultProcList = NULL;
    done = false;
    
    do
    {
        length = 0;
        nErr = sysctl((int *) name, (sizeof(name) / sizeof(*name)) - 1, NULL, &length, NULL, 0);
        if(nErr == -1)
            nErr = errno;
        
        if(nErr == 0)
        {
            resultProcList = (kinfo_proc*)(malloc(length));
            if(resultProcList == NULL)
                nErr = ENOMEM;
        }
        
        if (nErr == 0)
        {
            nErr = sysctl((int *) name, (sizeof(name) / sizeof(*name)) - 1, resultProcList, &length, NULL, 0);
            if(nErr == -1)
                nErr = errno;
            
            if (nErr == 0)
            {
                done = true;
            }
            else if (nErr == ENOMEM)
            {
                free(resultProcList);
                resultProcList = NULL;
                nErr = 0;
            }
        }
    } while (nErr == 0 && ! done);
    
    if (nErr != 0 && resultProcList != NULL)
    {
        free(resultProcList);
        resultProcList = NULL;
    }
    
    *processList = resultProcList;
    if(nErr == 0)
        *processCount = length / sizeof(kinfo_proc);
    
    assert( (nErr == 0) == (*processList != NULL) );
    
    return nErr;
}

static int const kCancelAuthorizeError = -128;

@implementation AuthorizationUtil

+ (AuthorizationUtil *)sharedInstance
{
    static AuthorizationUtil *instance = nil;
    if(instance == nil)
    {
        instance = [[AuthorizationUtil alloc] init];
    }
    return instance;
}

- (id)init
{
    self = [super init];
    _authorizationRef = NULL;
    _delegate = nil;
    return self;
}

- (void)dealloc
{
    [self deauthorize];
}

- (id)delegate
{
    return _delegate;
}

- (void)setDelegate:(id)delegate
{
    _delegate = delegate;
}

- (OSStatus)isAuthorizedForCommand:(NSString *)theCommand
{
    AuthorizationItem items[1];
    AuthorizationRights rights;
    AuthorizationRights *authorizedRights;
    AuthorizationFlags flags;
    OSStatus err = 0;
    
    if (_authorizationRef == NULL)
    {
        rights.count = 0;
        rights.items = NULL;
        flags = kAuthorizationFlagDefaults;
        err = AuthorizationCreate(&rights, kAuthorizationEmptyEnvironment, flags, &_authorizationRef);
    }
    
    const char *command = theCommand.UTF8String;
    items[0].name = kAuthorizationRightExecute;
    items[0].value = (void*)command;
    items[0].valueLength = strlen(command);
    items[0].flags = 0;
    
    rights.count = 1;
    rights.items = items;
    
    flags = kAuthorizationFlagExtendRights;
    
    err = AuthorizationCopyRights(_authorizationRef, &rights, kAuthorizationEmptyEnvironment, flags, &authorizedRights);
    
    if (errAuthorizationSuccess == err)
    {
        AuthorizationFreeItemSet(authorizedRights);
    }

    return err;
}

- (void)deauthorize
{
    if (_authorizationRef)
    {
        AuthorizationFree(_authorizationRef, kAuthorizationFlagDestroyRights);
        _authorizationRef = NULL;
        if(_delegate && [_delegate respondsToSelector:@selector(authorizationDidDeauthorize)])
        {
            [_delegate authorizationDidDeauthorize];
        }
    }
}

- (OSStatus)elevatePrivilegeForCommand:(NSString *)theCommand
{
    AuthorizationItem items[1];
    AuthorizationRights rights;
    AuthorizationRights *authorizedRights;
    AuthorizationFlags flags;
    OSStatus err = 0;
    
    if (_authorizationRef == NULL)
    {
        rights.count = 0;
        rights.items = NULL;
        flags = kAuthorizationFlagDefaults;
        err = AuthorizationCreate(&rights, kAuthorizationEmptyEnvironment, flags, &_authorizationRef);
    }
    
    const char *command = theCommand.UTF8String;
    items[0].name = kAuthorizationRightExecute;
    items[0].value = (void*)command;
    items[0].valueLength = strlen(command);
    items[0].flags = 0;
    
    rights.count = 1;
    rights.items = items;
    
    flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights;
    
    NSString *promptText = @"System need your privilege to make changes.";
    if (_delegate && [_delegate respondsToSelector:@selector(authorizationGetPromptText)])
    {
        promptText = [_delegate authorizationGetPromptText];
    }
    
    AuthorizationItem dialogConfiguration[1] = {kAuthorizationEnvironmentPrompt, [promptText length], (char *) [promptText UTF8String], 0};
    
    AuthorizationEnvironment authorizationEnvironment = {0};
    authorizationEnvironment.items = dialogConfiguration;
    authorizationEnvironment.count = 1;
    
    err = AuthorizationCopyRights(_authorizationRef, &rights, &authorizationEnvironment, flags, &authorizedRights);
    
    if (errAuthorizationSuccess == err)
    {
        AuthorizationFreeItemSet(authorizedRights);
    }
    
    return err;
}

- (OSStatus)authorizeForCommand:(NSString *)theCommand
{
    OSStatus result = [self isAuthorizedForCommand:theCommand];
    if (result != errAuthorizationSuccess)
    {
        result = [self elevatePrivilegeForCommand:theCommand];
    }
    
    return result;
}

- (int)getPidOfProcess:(NSString *)theProcess
{
    FILE* outpipe = NULL;
    NSMutableData *outputData = [NSMutableData data];
    NSMutableData *tempData = [[NSMutableData alloc] initWithLength:512];
    NSString *commandOutput = nil;
    NSString *scannerOutput = nil;
    NSScanner *outputScanner = nil;
    NSScanner *intScanner = nil;
    int pid = 0;
    int len = 0;
    
    NSString *popenArgs = [[NSString alloc] initWithFormat:@"/bin/ps -axwwopid,command | grep \"%@\"", theProcess];

    outpipe = popen(popenArgs.UTF8String, "r");
    
    if (!outpipe)
    {
        NSBeep();
        return 0;
    }
    
    do
    {
        [tempData setLength:512];
        len = fread([tempData mutableBytes],1,512,outpipe);
        if(len > 0)
        {
            [tempData setLength:len];
            [outputData appendData:tempData];
        }
    } while (len == 512);
    
    pclose(outpipe);
    commandOutput = [[NSString alloc] initWithData:outputData encoding:NSASCIIStringEncoding];
    
    if ([commandOutput length] > 0)
    {
        outputScanner = [NSScanner scannerWithString:commandOutput];
        [outputScanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [outputScanner scanUpToString:theProcess intoString:&scannerOutput];
        
        if ([scannerOutput rangeOfString:@"grep"].length != 0)
        {
            return 0;
        }
        intScanner = [NSScanner scannerWithString:scannerOutput];
        [intScanner scanInt:&pid];
        if (pid)
        {
            return pid;
        }
        else
        {
            return 0;
        }
    }
    else
    {
        return 0;
    }
}

- (OSStatus)executeCommand:(NSString *)cmdPath withArgs:(NSArray *)arguments
{
    char* args[30];
    OSStatus err = 0;
    unsigned int i = 0;
    
    OSStatus retCode = [self authorizeForCommand:cmdPath];
    if (retCode != errAuthorizationSuccess)
    {
        return retCode;
    }
    
    if (arguments == nil || [arguments count] < 1)
    {
        err = AuthorizationExecuteWithPrivileges(_authorizationRef, [cmdPath fileSystemRepresentation], 0, NULL, NULL);
    }
    else
    {
        while (i < [arguments count] && i < 19)
        {
            args[i] = (char*)[[arguments objectAtIndex:i] UTF8String];
            i++;
        }
        args[i] = NULL;
        
        err = AuthorizationExecuteWithPrivileges(_authorizationRef, [cmdPath fileSystemRepresentation], 0, args, NULL);
    }
    return err;
}

- (OSStatus)executeCommandSynced:(NSString *)cmdPath withArgs:(NSArray *)arguments
{
    char* args[30];
    OSStatus err = 0;
    unsigned int i = 0;
    FILE* f;
    char buffer[1024];
    
    if ([self authorizeForCommand:cmdPath] != errAuthorizationSuccess)
    {
        return errAuthorizationCanceled;
    }
    
    if (arguments == nil || [arguments count] < 1)
    {
        err = AuthorizationExecuteWithPrivileges(_authorizationRef, [cmdPath fileSystemRepresentation], 0, NULL, &f);
    }
    else
    {
        while ( i < [arguments count] && i < 29)
        {
            args[i] = (char*)[[arguments objectAtIndex:i] UTF8String];
            i++;
        }
        args[i] = NULL;
        
        const char* dbg = [cmdPath fileSystemRepresentation];
        err = AuthorizationExecuteWithPrivileges(_authorizationRef,
                                                 [cmdPath fileSystemRepresentation], kAuthorizationFlagDefaults, args, &f);
    }
    
    if(err == errAuthorizationSuccess)
    {
        int bytesRead;
        if (f)
        {
            for (;;)
            {
                bytesRead = fread(buffer, 1, 1024, f);
                if (bytesRead < 1) break;
            }
            fflush(f);
            fclose(f);
        }
    }
    return err;
}

- (BOOL)killProcess:(NSString *)theProcess withSignal:(int)signal
{
    BOOL result = NO;
    
	if (@available(macOS 10.13, *))
    {
        result = [self killProcessUsingAppleScript:theProcess signal:signal];
    }
    else
    {
        result = [self killProcessUsingAuthorizationExecuteWithPrivileges:theProcess withSignal:signal];
    }
    
    return result;
}

- (BOOL)authRemovePath:(NSString*)path
{
    BOOL result = NO;
    
	if (@available(macOS 10.13, *))
    {
        result = [self authRemovePathUsingAppleScript:path];
    }
    else
    {
        result = [self authRemovePathUsingAuthorizationExecuteWithPrivileges:path];
    }
    
    return result;
}

- (BOOL)authCopyPath:(NSString*)srcPath toPath:(NSString*)destPath
{
    BOOL result = NO;
    
	if (@available(macOS 10.13, *))
    {
        result = [self authCopyPathUsingAppleScript:srcPath toPath:destPath];
    }
    else
    {
        result = [self authCopyPathUsingAuthorization:srcPath toPath:destPath];
    }
    
    return result;
}

- (AppleScriptExecuteStatus)runAppleScript:(NSString *)script errorDescription:(NSString **)errorDescription
{
    if (script.length <= 0)
    {
        return AppleScriptExecuteStatusError;
    }
    
    NSDictionary *error = nil;
    
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
    if ([appleScript executeAndReturnError:&error])
    {
        return AppleScriptExecuteStatusSuccess;
    }
    else
    {
        NSNumber *errorNumber = nil;
        if ([error valueForKey:NSAppleScriptErrorNumber])
        {
            errorNumber = (NSNumber *)[error valueForKey:NSAppleScriptErrorNumber];
            if ([errorNumber intValue] == kCancelAuthorizeError)
            {
                return AppleScriptExecuteStatusCancel;
            }
            else
            {
                if (errorDescription && [error valueForKey:NSAppleScriptErrorMessage])
                {
                    *errorDescription = (NSString *)[error valueForKey:NSAppleScriptErrorMessage];
                }
                
                return AppleScriptExecuteStatusError;
            }
        }
        
        return AppleScriptExecuteStatusError;
    }
}



- (NSArray*)getProcessList
{
    kinfo_proc *processList = NULL;
    size_t processCount = 0;
    
    getBSDProcessList(&processList, &processCount);
    
    NSMutableArray *processArray = [NSMutableArray arrayWithCapacity:0];
    for(int i = 0; i < processCount; i++)
    {
        struct kinfo_proc *currentProcess = &processList[i];
        if(!currentProcess)
            continue;
        
        NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithCapacity:0];
        NSNumber *processID = [NSNumber numberWithInt:currentProcess->kp_proc.p_pid];
        NSString *processName = [NSString stringWithFormat:@"%s",currentProcess->kp_proc.p_comm];
        
        if(processID)
            [entry setObject:processID forKey:kAudioShareProcessID];
        
        if(processName)
            [entry setObject:processName forKey:kAudioShareProcessName];
        
        struct passwd *user = getpwuid(currentProcess->kp_eproc.e_ucred.cr_uid);
        if(user)
        {
            NSNumber *userID = [NSNumber numberWithUnsignedInt:currentProcess->kp_eproc.e_ucred.cr_uid];
            NSString *userName = [NSString stringWithFormat:@"%s",user->pw_name];
            
            if(userID)
                [entry setObject:userID forKey:kAudioShareProcessUserId];
            
            if(userName)
                [entry setObject:userName forKey:kAudioShareProcessUserName];
        }
        
        [processArray addObject:[NSDictionary dictionaryWithDictionary:entry]];
    }
    
    free(processList);
    processList = NULL;
    
    return [NSArray arrayWithArray:processArray];
}

- (int)getCoreAudioPid
{
    NSArray* appsArray = [self getProcessList];
    if(!appsArray || appsArray.count<=0)
        return 0;
    
    NSDictionary* tmpApp = nil;
    NSString* appName = nil;
    NSString* appOwner = nil;
    for(int i=0; i<appsArray.count; i++)
    {
        tmpApp = [appsArray objectAtIndex:i];
        if(!tmpApp)
            continue;
        
        appName = [tmpApp objectForKey:kAudioShareProcessName];
        appOwner = [tmpApp objectForKey:kAudioShareProcessUserName];
        
        if([[appName lowercaseString] isEqualToString:@"coreaudiod"] && [[appOwner lowercaseString] isEqualToString:@"_coreaudiod"])
            return [[tmpApp objectForKey:kAudioShareProcessID] intValue];
    }
    
    return 0;
}

- (BOOL)killProcessUsingAppleScript:(NSString *)theProcess signal:(int)signal
{
    if (theProcess.length <= 0)
    {
        return NO;
    }
    
    NSString *pid = nil;
    NSString *sig = [NSString stringWithFormat:@"%d", signal];
    
    pid = [NSString stringWithFormat:@"%d",[self getPidOfProcess:theProcess]];
    
    if ([pid intValue] <= 0 && [theProcess isEqualToString:@"coreaudiod"])
    {
        pid = [NSString stringWithFormat:@"%d", [self getCoreAudioPid]];
    }
    
    if ([pid intValue] <= 0)
    {
        if([_delegate respondsToSelector:@selector(authorizationDidFail:)])
        {
            [_delegate authorizationDidFail:-1];
        }
        
        return NO;
    }
    
    NSString *promptText = @"System need your privilege to change.";
    if ([_delegate respondsToSelector:@selector(authorizationGetPromptText)])
    {
        promptText = [_delegate authorizationGetPromptText];
    }
    
    if( [pid intValue] > 0 )
    {
        NSString *killCoreaudio = [NSString stringWithFormat:@"do shell script \"/bin/kill -%@ %@ \" with prompt \"%@ \" with administrator privileges", sig, pid, promptText];
        
        AppleScriptExecuteStatus runAppleScriptResult = [[AuthorizationUtil sharedInstance] runAppleScript:killCoreaudio errorDescription:nil];
        
        if([_delegate respondsToSelector:@selector(authorizationDidFinish:)])
        {
            [_delegate authorizationDidFinish:runAppleScriptResult];
        }
        
        switch (runAppleScriptResult)
        {
            case AppleScriptExecuteStatusSuccess:
            {
                return YES;
            }
                break;
            case AppleScriptExecuteStatusCancel:
            case AppleScriptExecuteStatusError:
            {
                return NO;
            }
                break;
        }
    }
    
    return NO;
}

- (BOOL)killProcessUsingAuthorizationExecuteWithPrivileges:(NSString *)theProcess withSignal:(int)signal
{
    if (theProcess.length <= 0)
    {
        return NO;
    }
    
    NSString *pid;
    NSString *sig = [NSString stringWithFormat:@"%d", signal];
        
    pid = [NSString stringWithFormat:@"%d",[self getPidOfProcess:theProcess]];
    
    if ([pid intValue] <= 0 && [theProcess isEqualToString:@"coreaudiod"])
    {
        pid = [NSString stringWithFormat:@"%d", [self getCoreAudioPid]];
    }
    
    if( [pid intValue] > 0 )
    {
        OSStatus result = [self executeCommand:@"/bin/kill" withArgs:[NSArray arrayWithObjects:pid, sig, nil]];
        if(_delegate && [_delegate respondsToSelector:@selector(authorizationDidFinish:)])
            [_delegate authorizationDidFinish:result];
        if(errAuthorizationSuccess == result)
            return YES;
        return NO;
    }
    else
    {
        if(_delegate && [_delegate respondsToSelector:@selector(authorizationDidFail:)])
            [_delegate authorizationDidFail:-1];
        
        return NO;
    }
    return YES;
}

- (BOOL)authRemovePathUsingAuthorizationExecuteWithPrivileges:(NSString*)path
{
    if (path.length<=0 || ![[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        return NO;
    }
    NSString* command = @"/bin/rm";
    NSArray* arguments = [NSArray arrayWithObjects:@"-rf", path, nil];
    OSStatus result = [self authorizeForCommand:command];

    if(result == errAuthorizationCanceled)
    {
        NSLog(@"%s authorizeForCommand:rm failed", __FUNCTION__);
        return NO;
    }
    if(errAuthorizationSuccess != [self executeCommandSynced:command withArgs:arguments])
    {
        NSLog(@"%s, remove file failed", __FUNCTION__);
        return NO;
    }
    return YES;
}

- (BOOL)authCopyPathUsingAuthorization:(NSString *)srcPath toPath:(NSString *)destPath
{
    if (srcPath.length<=0 || destPath.length<=0 || ![[NSFileManager defaultManager] fileExistsAtPath:srcPath])
    {
        return NO;
    }
    
    NSString* command = @"/bin/cp";
    NSArray* arguments = [NSArray arrayWithObjects:@"-r", srcPath, destPath, nil];
    OSStatus result = [self authorizeForCommand:command];

    if(result == errAuthorizationCanceled)
    {
        NSLog(@"%s, authorizeForCommand: failed", __FUNCTION__);
        return NO;
    }
    if(errAuthorizationSuccess != [self executeCommandSynced:command withArgs:arguments])
    {
        NSLog(@"%s, authorizeForCommand: failed", __FUNCTION__);
        return NO;
    }
    return YES;
}

- (BOOL)authRemovePathUsingAppleScript:(NSString *)path
{
    if (path.length <= 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        return NO;
    }
    
    NSString *promptText = @"System need your privilege to make changes.";
    if ([_delegate respondsToSelector:@selector(authorizationGetPromptText)])
    {
        promptText = [_delegate authorizationGetPromptText];
    }
    
    NSString *removeScript = [NSString stringWithFormat:@"do shell script \"/bin/rm -rf '%@' \" with prompt \"%@ \" with administrator privileges", path, promptText];
    
    AppleScriptExecuteStatus status = [[AuthorizationUtil sharedInstance] runAppleScript:removeScript errorDescription:nil];
    
    switch (status)
    {
        case AppleScriptExecuteStatusSuccess:
        {
            return YES;
        }
        break;
        case AppleScriptExecuteStatusCancel:
        case AppleScriptExecuteStatusError:
        {
            return NO;
        }
        break;
    }
}

- (BOOL)authCopyPathUsingAppleScript:(NSString *)srcPath toPath:(NSString *)destPath
{
    if (srcPath.length <=0 || destPath.length <= 0 || ![[NSFileManager defaultManager] fileExistsAtPath:srcPath])
    {
        return NO;
    }
    
    NSString *promptText = @"System need your privilege to make changes.";
    if ([_delegate respondsToSelector:@selector(authorizationGetPromptText)])
    {
        promptText = [_delegate authorizationGetPromptText];
    }
    
    NSString *copyScript = [NSString stringWithFormat:@"do shell script \"/bin/cp -r '%@' '%@' \" with prompt \"%@ \" with administrator privileges", srcPath, destPath, promptText];
    
    AppleScriptExecuteStatus status = [[AuthorizationUtil sharedInstance] runAppleScript:copyScript errorDescription:nil];
    
    switch (status)
    {
        case AppleScriptExecuteStatusSuccess:
        {
            return YES;
        }
        break;
        case AppleScriptExecuteStatusCancel:
        case AppleScriptExecuteStatusError:
        {
            return NO;
        }
        break;
    }
}
@end
