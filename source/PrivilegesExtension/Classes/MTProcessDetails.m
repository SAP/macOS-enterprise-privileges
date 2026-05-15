/*
    MTProcessDetails.m
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

#import "MTProcessDetails.h"
#import <sys/sysctl.h>
#import <libproc.h>

@implementation MTProcessDetails : NSObject

+ (NSArray*)processList
{
    NSMutableArray *processList = [[NSMutableArray alloc] init];
    
    int numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    pid_t pids[numberOfProcesses];
    bzero(pids, sizeof(pids));
    proc_listpids(PROC_ALL_PIDS, 0, pids, (int)sizeof(pids));
    
    for (int i = 0; i < numberOfProcesses; ++i) {
        
        if (pids[i] == 0) { continue; }
        char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
        bzero(pathBuffer, PROC_PIDPATHINFO_MAXSIZE);
        proc_pidpath(pids[i], pathBuffer, sizeof(pathBuffer));
        
        if (strlen(pathBuffer) > 0) {
    
            NSString *processPath = [NSString stringWithUTF8String:pathBuffer];
            NSString *processName = [processPath lastPathComponent];
            NSNumber *processID = [NSNumber numberWithInt:pids[i]];
            
            if (processPath && processName && processID) {
                
                NSDictionary *processDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                             processID, @"pid",
                                             processName, @"name",
                                             processPath, @"path",
                                             nil
                ];
                [processList addObject:processDict];
            }
        }
    }
    
    return ([processList count] > 0) ? processList : nil;
}

+ (NSArray*)openFilesWithPID:(pid_t)pid
{
    NSMutableSet *openFiles = [NSMutableSet set];
    
    // get file descriptors
    int fdBufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
    if (fdBufferSize <= 0) { return nil; }

    struct proc_fdinfo *fdInfo = malloc(fdBufferSize);
    if (!fdInfo) { return nil; }

    fdBufferSize = proc_pidinfo(
                                pid,
                                PROC_PIDLISTFDS,
                                0,
                                fdInfo,
                                fdBufferSize
                                );
    if (fdBufferSize <= 0) {
        free(fdInfo);
        return nil;
    }

    int numberOfFDs = fdBufferSize / sizeof(struct proc_fdinfo);

    for (int i = 0; i < numberOfFDs; i++) {

        if (fdInfo[i].proc_fdtype == PROX_FDTYPE_VNODE) {
            
            struct vnode_fdinfowithpath pathInfo;
            int pathInfoSize = proc_pidfdinfo(
                                              pid,
                                              fdInfo[i].proc_fd,
                                              PROC_PIDFDVNODEPATHINFO,
                                              &pathInfo,
                                              sizeof(pathInfo)
                                              );
            
            if (pathInfoSize == sizeof(pathInfo)) {
                
                NSString *filePath = [NSString stringWithUTF8String:pathInfo.pvip.vip_path];
                if ([filePath length] > 0) { [openFiles addObject:filePath]; }
            }
        }
    }

    free(fdInfo);
    
    return [openFiles allObjects];
}

+ (BOOL)isPlatformBinaryWithPID:(pid_t)pid
{
    SecCodeRef codeRef = NULL;
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:pid]
                                                           forKey:(__bridge id)kSecGuestAttributePid
    ];
    
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

+ (NSArray*)argumentsForPID:(pid_t)pid
{
    int mib[3] = { CTL_KERN, KERN_PROCARGS2, pid };
    size_t size = 0;
    
    if (sysctl(mib, 3, NULL, &size, NULL, 0) == -1) { return nil; }

    char *buffer = malloc(size);
    if (!buffer) { return nil; }

    if (sysctl(mib, 3, buffer, &size, NULL, 0) == -1) {
        
        free(buffer);
        return nil;
    }

    NSMutableSet *arguments = [NSMutableSet set];

    int argc = 0;
    memcpy(&argc, buffer, sizeof(argc));

    char *p = buffer + sizeof(argc);
    char *end = buffer + size;

    while (p < end && *p != '\0') { p++; }
    while (p < end && *p == '\0') { p++; }

    for (int i = 0; i < argc && p < end; i++) {
        
        NSString *arg = [NSString stringWithUTF8String:p];
        
        if (arg) { [arguments addObject:arg]; }

        while (p < end && *p != '\0') { p++; }
        while (p < end && *p == '\0') { p++; }
    }

    free(buffer);

    return [arguments allObjects];
}

@end
