/*
    MTSystemInfo.m
    Copyright 2016-2025 SAP SE
     
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
     
    http://www.apache.org/licenses/LICENSE-2.0
     
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

#import "MTSystemInfo.h"
#import <sys/sysctl.h>
#import <libproc.h>

@implementation MTSystemInfo

+ (NSString*)machineUUID
{
    NSString *returnValue = @"";
    
    // get the Platform Expert object
    io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
    
    if (platformExpert) {
        
        CFStringRef uuid = IORegistryEntryCreateCFProperty(platformExpert, CFSTR(kIOPlatformUUIDKey), kCFAllocatorDefault, kNilOptions);
        
        if (uuid) {
            
            returnValue = (__bridge NSString *)(uuid);
            CFRelease(uuid);
        }
        
        IOObjectRelease(platformExpert);
    }
    
    return returnValue;
}

+ (NSDate*)sessionStartDate
{
    NSDate *startDate = [NSDate distantFuture];
    
    size_t len = 4;
    int mib[len];
    struct kinfo_proc kp;
    
    if (sysctlnametomib("kern.proc.pid", mib, &len) == 0) {
        
        // get the loginwindow process
        NSRunningApplication *app = [[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.loginwindow"] firstObject];
        mib[3] = [app processIdentifier];
        len = sizeof(kp);
        
        if (sysctl(mib, 4, &kp, &len, NULL, 0) == 0) {
            
            struct timeval processStartTime = kp.kp_proc.p_un.__p_starttime;
            startDate = [NSDate dateWithTimeIntervalSince1970:processStartTime.tv_sec + processStartTime.tv_usec / 1e6];
        }
    }
    
    return startDate;
}

+ (BOOL)isExecutableFileAtURL:(NSURL*)url
{
    BOOL isExecutable = NO;
    
    if (url && [url isFileURL]) {
                
        NSDictionary *resourceValues = [url resourceValuesForKeys:[NSArray arrayWithObjects:NSURLIsPackageKey, NSURLIsExecutableKey, nil]
                                                            error:nil
        ];
        
        if (resourceValues && [[resourceValues objectForKey:NSURLIsPackageKey] boolValue]) {

            isExecutable = [[resourceValues objectForKey:NSURLIsExecutableKey] boolValue];
            
        } else {
            
            int status = access([[url path] UTF8String], X_OK);
            isExecutable = (status == -1) ? NO : YES;
        }
    }
    
    return isExecutable;
}

@end
