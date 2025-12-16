/*
    MTParentProcess.m
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

#import "MTParentProcess.h"
#import <sys/proc_info.h>
#import <sys/sysctl.h>
#import <libproc.h>

@interface MTParentProcess ()
@property pid_t childPID;
@property pid_t parentPID;
@end

@implementation MTParentProcess

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _childPID = getpid();
    }
    
    return self;
}

- (instancetype)initWithChildPID:(pid_t)pid
{
    self = [super init];
    
    if (self) {
        
        _childPID = pid;
        if (_childPID <= 0) { self = nil; }
    }
    
    return self;
}

- (pid_t)pid
{
    if (_parentPID == 0) {
        
        pid_t pid = _childPID;
        pid_t parentPID = 0;
        
        while (pid > 1) {

            parentPID = pid;
            
            // get the next parent
            struct kinfo_proc proc;

            if ([self processInfoWithPID:pid proc:&proc]) {
                
                pid = proc.kp_eproc.e_ppid;

            } else {
                
                break;
            }
        }
        
        _parentPID = parentPID;
    }
    
    return _parentPID;
}

- (BOOL)processInfoWithPID:(pid_t)pid proc:(struct kinfo_proc *)proc
{
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
    size_t size = sizeof(struct kinfo_proc);
    
    return sysctl(mib, 4, proc, &size, NULL, 0) == 0;
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
    NSMutableArray *openedFiles = [[NSMutableArray alloc] init];
    
    // get file descriptors
    int fdBufferSize = proc_pidinfo([self pid], PROC_PIDLISTFDS, 0, NULL, 0);
    if (fdBufferSize <= 0) { return nil; }

    int numberOfFDs = fdBufferSize / sizeof(struct proc_fdinfo);
    struct proc_fdinfo *fdInfo = malloc(fdBufferSize);
    if (!fdInfo) { return nil; }

    fdBufferSize = proc_pidinfo(
                                [self pid],
                                PROC_PIDLISTFDS,
                                0,
                                fdInfo,
                                fdBufferSize
                                );
    if (fdBufferSize <= 0) {
        free(fdInfo);
        return nil;
    }

    for (int i = 0; i < numberOfFDs; i++) {

        if (fdInfo[i].proc_fdtype == PROX_FDTYPE_VNODE) {
            
            struct vnode_fdinfowithpath pathInfo;
            int pathInfoSize = proc_pidfdinfo(
                                              [self pid],
                                              fdInfo[i].proc_fd,
                                              PROC_PIDFDVNODEPATHINFO,
                                              &pathInfo,
                                              sizeof(pathInfo)
                                              );
            
            if (pathInfoSize == sizeof(pathInfo)) {
                
                NSString *filePath = [NSString stringWithUTF8String:pathInfo.pvip.vip_path];
                if (filePath) { [openedFiles addObject:filePath]; }
            }
        }
    }

    free(fdInfo);
    
    return openedFiles;
}

@end
