#import "authentication_mgr.h"

#include <sys/sysctl.h>
#include <pwd.h>
#import <Security/AuthorizationTags.h>


typedef struct kinfo_proc kinfo_proc;

static NSString* const kAudioShareProcessID = @"AudioShareProcessID";
static NSString* const kAudioShareProcessName = @"AudioShareProcessName";
static NSString* const kAudioShareProcessUserId = @"AudioShareProcessUserId";
static NSString* const kAudioShareProcessUserName = @"AudioShareProcessUserName";

static int getProcessList(kinfo_proc **processList, size_t *processCount)
{
    int                 nErr;
    kinfo_proc *        resultProcList;
    bool                bDone;
    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    size_t              length;
    
    *processCount = 0;
    resultProcList = NULL;
    bDone = false;
    
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
                bDone = true;
            }
            else if (nErr == ENOMEM)
            {
                free(resultProcList);
                resultProcList = NULL;
                nErr = 0;
            }
        }
    } while (nErr == 0 && ! bDone);
    
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
    _delegate = nil;
    return self;
}

- (void)dealloc
{
}

- (id)delegate
{
    return _delegate;
}

- (void)setDelegate:(id)delegate
{
    _delegate = delegate;
}

- (BOOL)authRemovePath:(NSString*)path
{
    BOOL result = NO;
    
	if (@available(macOS 10.13, *))
    {
        result = [self authRemovePathUsingAppleScript:path];
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


- (NSArray*)getProcessList
{
    kinfo_proc *processList = NULL;
    size_t processCount = 0;
    
    getProcessList(&processList, &processCount);
    
    NSMutableArray *processArray = [NSMutableArray arrayWithCapacity:0];
    for(int i = 0; i < processCount; i++)
    {
        struct kinfo_proc *aProcess = &processList[i];
        if(!aProcess)
            continue;
        
        NSMutableDictionary *processInfo = [NSMutableDictionary dictionaryWithCapacity:0];
        NSNumber *processID = [NSNumber numberWithInt:aProcess->kp_proc.p_pid];
        NSString *processName = [NSString stringWithFormat:@"%s", aProcess->kp_proc.p_comm];
        
        if(processID)
            [processInfo setObject:processID forKey:kAudioShareProcessID];
        
        if(processName)
            [processInfo setObject:processName forKey:kAudioShareProcessName];
        
        struct passwd *user = getpwuid(aProcess->kp_eproc.e_ucred.cr_uid);
        if(user)
        {
            NSNumber *userID = [NSNumber numberWithUnsignedInt:aProcess->kp_eproc.e_ucred.cr_uid];
            NSString *userName = [NSString stringWithFormat:@"%s", user->pw_name];
            
            if(userID)
                [processInfo setObject:userID forKey:kAudioShareProcessUserId];
            
            if(userName)
                [processInfo setObject:userName forKey:kAudioShareProcessUserName];
        }
        
        [processArray addObject:[NSDictionary dictionaryWithDictionary:processInfo]];
    }
    
    free(processList);
    processList = NULL;
    
    return [NSArray arrayWithArray:processArray];
}

- (int)getCoreAudioPid
{
    NSArray* processArray = [self getProcessList];
    if(!processArray || processArray.count<=0)
        return 0;
    
    NSDictionary* processInfo = nil;
    NSString* processName = nil;
    NSString* processOwner = nil;
    for(int i=0; i<processArray.count; i++)
    {
        processInfo = [processArray objectAtIndex:i];
        if(!processInfo)
            continue;
        
        processName = [processInfo objectForKey:kAudioShareProcessName];
        processOwner = [processInfo objectForKey:kAudioShareProcessUserName];
        
        if([[processName lowercaseString] isEqualToString:@"coreaudiod"] && [[processOwner lowercaseString] isEqualToString:@"_coreaudiod"])
            return [[processInfo objectForKey:kAudioShareProcessID] intValue];
    }
    
    return 0;
}


- (BOOL)killProcess:(NSString *)theProcess withSignal:(int)signal
{
    BOOL result = NO;
    
    if (@available(macOS 10.13, *))
    {
        result = [self killProcessUsingAppleScript:theProcess signal:signal];
    }
    
    return result;
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


@end
