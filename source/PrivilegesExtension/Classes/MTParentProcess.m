/*
    MTParentProcess.m
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

#import "MTParentProcess.h"
#import <sys/sysctl.h>
#import <libproc.h>

@interface MTParentProcess ()
@property pid_t childPID;
@end

@implementation MTParentProcess

- (instancetype)initWithChildPID:(pid_t)pid
{
    self = [super init];
    
    if (self) {
        
        _childPID = pid;
        if (_childPID <= 0) { self = nil; }
    }
    
    return self;
}

- (MTProcess*)root
{
    pid_t pid = _childPID;
    pid_t parentPID = 0;
    
    while (pid > 1) {

        parentPID = pid;
        MTProcess *directParent = [self directParentOfPID:pid];

        if ([directParent pid] > 1) {
            
            pid = [directParent pid];

        } else {
            
            break;
        }
    }
    
    MTProcess *process = [[MTProcess alloc] initWithPID:parentPID];
    
    return process;
}

- (MTProcess*)parent
{
    return [self directParentOfPID:_childPID];
}

- (MTProcess*)directParentOfPID:(pid_t)pid
{
    struct kinfo_proc proc;
    pid_t parent = -1;
    
    if (pid > 1) {
        
        if ([self processInfoWithPID:pid proc:&proc]) {
            
            parent = proc.kp_eproc.e_ppid;
        }
    }
    
    MTProcess *process = [[MTProcess alloc] initWithPID:parent];
    
    return process;
}

- (BOOL)processInfoWithPID:(pid_t)pid proc:(struct kinfo_proc *)proc
{
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
    size_t size = sizeof(struct kinfo_proc);
    
    return sysctl(mib, 4, proc, &size, NULL, 0) == 0;
}

@end
