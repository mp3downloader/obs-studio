/******************************************************************************
    Copyright (C) 2013 by Hugh Bailey <obs.jim@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
******************************************************************************/

#include <sstream>
#include <dlfcn.h>
#include <util/base.h>
#include <obs-config.h>
#include "platform.hpp"
#include "obs-app.hpp"

#include <unistd.h>

#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>

using namespace std;

bool isInBundle()
{
	NSRunningApplication *app = [NSRunningApplication currentApplication];
	return [app bundleIdentifier] != nil;
}

bool GetDataFilePath(const char *data, string &output)
{
	if (isInBundle()) {
		NSRunningApplication *app =
			[NSRunningApplication currentApplication];
		NSURL *bundleURL = [app bundleURL];
		NSString *path = [NSString
			stringWithFormat:@"Contents/Resources/data/obs-studio/%@",
					 [NSString stringWithUTF8String:data]];
		NSURL *dataURL = [bundleURL URLByAppendingPathComponent:path];
		output = [[dataURL path] UTF8String];
	} else {
		stringstream str;
		str << OBS_DATA_PATH "/obs-studio/" << data;
		output = str.str();
	}

	return !access(output.c_str(), R_OK);
}

bool InitApplicationBundle()
{
#ifdef OBS_OSX_BUNDLE
	static bool initialized = false;
	if (initialized)
		return true;

	try {
		NSBundle *bundle = [NSBundle mainBundle];
		if (!bundle)
			throw "Could not find main bundle";

		NSString *exe_path = [bundle executablePath];
		if (!exe_path)
			throw "Could not find executable path";

		NSString *path = [exe_path stringByDeletingLastPathComponent];

		if (chdir([path fileSystemRepresentation]))
			throw "Could not change working directory to "
			      "bundle path";

	} catch (const char *error) {
		blog(LOG_ERROR, "InitBundle: %s", error);
		return false;
	}

	return initialized = true;
#else
	return true;
#endif
}

string GetDefaultVideoSavePath()
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSURL *url = [fm URLForDirectory:NSMoviesDirectory
				inDomain:NSUserDomainMask
		       appropriateForURL:nil
				  create:true
				   error:nil];

	if (!url)
		return getenv("HOME");

	return url.path.fileSystemRepresentation;
}

vector<string> GetPreferredLocales()
{
	NSArray *preferred = [NSLocale preferredLanguages];

	auto locales = GetLocaleNames();
	auto lang_to_locale = [&locales](string lang) -> string {
		string lang_match = "";

		for (const auto &locale : locales) {
			if (locale.first == lang.substr(0, locale.first.size()))
				return locale.first;

			if (!lang_match.size() &&
			    locale.first.substr(0, 2) == lang.substr(0, 2))
				lang_match = locale.first;
		}

		return lang_match;
	};

	vector<string> result;
	result.reserve(preferred.count);

	for (NSString *lang in preferred) {
		string locale = lang_to_locale(lang.UTF8String);
		if (!locale.size())
			continue;

		if (find(begin(result), end(result), locale) != end(result))
			continue;

		result.emplace_back(locale);
	}

	return result;
}

bool IsAlwaysOnTop(QWidget *window)
{
	return (window->windowFlags() & Qt::WindowStaysOnTopHint) != 0;
}

void SetAlwaysOnTop(QWidget *window, bool enable)
{
	Qt::WindowFlags flags = window->windowFlags();

	if (enable)
		flags |= Qt::WindowStaysOnTopHint;
	else
		flags &= ~Qt::WindowStaysOnTopHint;

	window->setWindowFlags(flags);
	window->show();
}

typedef void (*set_int_t)(int);

void EnableOSXVSync(bool enable)
{
	static bool initialized = false;
	static bool valid = false;
	static set_int_t set_debug_options = nullptr;
	static set_int_t deferred_updates = nullptr;

	if (!initialized) {
		void *quartzCore = dlopen("/System/Library/Frameworks/"
					  "QuartzCore.framework/QuartzCore",
					  RTLD_LAZY);
		if (quartzCore) {
			set_debug_options = (set_int_t)dlsym(
				quartzCore, "CGSSetDebugOptions");
			deferred_updates = (set_int_t)dlsym(
				quartzCore, "CGSDeferredUpdates");

			valid = set_debug_options && deferred_updates;
		}

		initialized = true;
	}

	if (valid) {
		set_debug_options(enable ? 0 : 0x08000000);
		deferred_updates(enable ? 1 : 0);
	}
}

void EnableOSXDockIcon(bool enable)
{
	if (enable)
		[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
	else
		[NSApp setActivationPolicy:
				NSApplicationActivationPolicyProhibited];
}

/*
 * This custom NSApplication subclass makes the app compatible with CEF. Qt
 * also has an NSApplication subclass, but it doesn't conflict thanks to Qt
 * using arcane magic to hook into the NSApplication superclass itself if the
 * program has its own NSApplication subclass.
 */

@protocol CrAppProtocol
- (BOOL)isHandlingSendEvent;
@end

@interface OBSApplication : NSApplication <CrAppProtocol>
@property (nonatomic, getter=isHandlingSendEvent) BOOL handlingSendEvent;
@end

@implementation OBSApplication
- (void)sendEvent:(NSEvent *)event
{
	_handlingSendEvent = YES;
	[super sendEvent:event];
	_handlingSendEvent = NO;
}
@end

void InstallNSApplicationSubclass()
{
	[OBSApplication sharedApplication];
}

bool canRecordScreen()
{
    if (@available(macOS 10.15, *))
    {
        CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
        NSUInteger numberOfWindows = CFArrayGetCount(windowList);
        NSUInteger numberOfWindowsWithName = 0;
        for (int idx = 0; idx < numberOfWindows; idx++)
        {
            NSDictionary *windowInfo = (NSDictionary *)CFArrayGetValueAtIndex(windowList, idx);
            NSString *windowName = windowInfo[(id)kCGWindowName];
            if (windowName)
            {
                numberOfWindowsWithName++;
            }
            else
            {
                //no kCGWindowName detected -> not enabled
                break; //breaking early, numberOfWindowsWithName not increased
            }
        }
        CFRelease(windowList);
        return numberOfWindows == numberOfWindowsWithName;
    }
    return YES;
}

bool canAccessCamera()
{
    __block BOOL bCanAccess = NO;
    
    if (@available(macOS 10.14, *))
    {
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        
        switch (authStatus)
        {
            case AVAuthorizationStatusNotDetermined:
            {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                    if (granted)
                    {
                        bCanAccess = YES;
                    }
                    else
                    {
                        bCanAccess = NO;
                    }
                }];
                break;
            }
                
            case AVAuthorizationStatusAuthorized:
            {
                bCanAccess = YES;
                break;
            }
            case AVAuthorizationStatusDenied:
            {
                bCanAccess = NO;
                break;
            }
            case AVAuthorizationStatusRestricted:
            {
                bCanAccess = NO;
                break;
            }
                
            default:
                break;
        }
    }

    return bCanAccess;
}

bool canAccessMicroPhone()
{
    __block BOOL bCanAccess = NO;
    
    if (@available(macOS 10.14, *))
    {
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        switch (authStatus)
        {
            case AVAuthorizationStatusNotDetermined:
            {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted){
                    if (granted)
                    {
                        bCanAccess = YES;
                    }
                    else
                    {
                        bCanAccess = NO;
                    }
                }];
                break;
            }
            
            case AVAuthorizationStatusAuthorized:
            {
                bCanAccess = YES;
                break;
            }
            case AVAuthorizationStatusDenied:
            {
                bCanAccess = NO;
                break;
            }
            case AVAuthorizationStatusRestricted:
            {
                bCanAccess = NO;
                break;
            }
                
            default:
                break;
        }
    }
 
    return bCanAccess;
}


void OpenMicphoneAccessPreferences()
{
    NSString* strRUL = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone";

    NSURL* theURL = [NSURL URLWithString:strRUL];
    if(theURL)
    {
        [[NSWorkspace sharedWorkspace] openURL:theURL];
    }
}

void OpenCameraAccessPreferences()
{
    NSString* strRUL = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Camera";

    NSURL* theURL = [NSURL URLWithString:strRUL];
    if(theURL)
    {
        [[NSWorkspace sharedWorkspace] openURL:theURL];
    }
}

void OpenScreenCapturePreferneces()
{
    NSString* strRUL = @"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture";
    NSURL* theURL = [NSURL URLWithString:strRUL];
    if(theURL)
    {
        [[NSWorkspace sharedWorkspace] openURL:theURL];
    }
}

