/*
    MTProcess.m
    Copyright 2016-2026 SAP SE
     
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

#import "MTProcess.h"
#import <libproc.h>

@interface MTProcess ()
@property (assign) pid_t pid;
@end

@implementation MTProcess

- (instancetype)initWithPID:(pid_t)pid
{
    self = [super init];
    
    if (self) {
        
        if (pid > 1) {
            
            _pid = pid;
            
        } else {
            
            self = nil;
        }
    }
    
    return self;
}

- (NSString*)name
{
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
    
    int retval = proc_pidpath(
                              [self pid],
                              pathBuffer,
                              sizeof(pathBuffer)
                              );
     
    if (retval <= 0) { return nil; }
        
    NSString *commandPath = [NSString stringWithUTF8String:pathBuffer];
    
    return [commandPath lastPathComponent];
}

- (BOOL)isPlatformBinary
{
    SecCodeRef codeRef = NULL;
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:[self pid]]
                                                            forKey:(__bridge id)kSecGuestAttributePid];
    
    OSStatus status = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef)attributes, kSecCSDefaultFlags, &codeRef);
    if (status != errSecSuccess) { return NO; }
    
    SecRequirementRef requirement = NULL;
    status = SecRequirementCreateWithString(CFSTR("anchor apple"), kSecCSDefaultFlags, &requirement);

    if (status != errSecSuccess) {
        
        CFRelease(codeRef);
        return NO;
    }
    
    status = SecCodeCheckValidity(codeRef, kSecCSDefaultFlags, requirement);
    CFRelease(requirement);
    CFRelease(codeRef);
    
    return (status == errSecSuccess);
}

- (NSArray*)openFiles
{
    NSArray *openFiles = [MTProcessDetails openFilesWithPID:[self pid]];
    return openFiles;
}

- (NSArray*)arguments
{
    NSArray *arguments = [MTProcessDetails argumentsForPID:[self pid]];
    return arguments;
}

@end
