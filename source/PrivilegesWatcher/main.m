/*
    main.m
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

#import <Foundation/Foundation.h>
#import "Constants.h"
#import <os/log.h>

@protocol PrivilegesWatcherDelegate <NSObject>
- (void)postNotification;
@end

void fsevents_callback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[])
{
    char **paths = eventPaths;
    id<PrivilegesWatcherDelegate> myDelegate = (__bridge id<PrivilegesWatcherDelegate>)clientCallBackInfo;

    if (myDelegate) {
        
        for (int i = 0; i < numEvents; i++) {
            
            NSString *eventPath = [NSString stringWithUTF8String:paths[i]];
            
            if ([[eventPath lastPathComponent] isEqualToString:@"admin.plist"]) {
                    
                dispatch_async(dispatch_get_main_queue(), ^{ [myDelegate postNotification]; });
                break;
            }
        }
    }
}

@interface Main : NSObject <PrivilegesWatcherDelegate>
@property (nonatomic, strong, readwrite) NSTimer *delayTimer;
@property (nonatomic, strong, readwrite) NSTimer *terminationTimer;
@property (assign) BOOL shouldTerminate;
@end

@implementation Main

- (void)run
{
    os_log(OS_LOG_DEFAULT, "SAPCorp: Starting");
    
    [self scheduleTerminationTimer];
    
    // post a notification so the PrivilegesAgent knows about the change
    [self postNotification];
    
    // monitor the admin group for further changes
    NSString *basePath = @"/var/db/dslocal/nodes/Default/groups";
    NSArray *pathsToWatch = [NSArray arrayWithObject:basePath];
    FSEventStreamContext cntxt = {0, (__bridge void *)(self), NULL, NULL, NULL};
    dispatch_queue_t queue = dispatch_queue_create("corp.sap.privileges.watcher.queue", DISPATCH_QUEUE_SERIAL);
    
    FSEventStreamRef stream = FSEventStreamCreate(
                                                  NULL,
                                                  &fsevents_callback,
                                                  &cntxt,
                                                  (__bridge CFArrayRef)pathsToWatch,
                                                  kFSEventStreamEventIdSinceNow,
                                                  0.1,
                                                  kFSEventStreamCreateFlagFileEvents
                                                  );
    
    if (stream) {
        
        FSEventStreamSetDispatchQueue(stream, queue);
        FSEventStreamStart(stream);
    }
    
    while (!_shouldTerminate) {
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:60]];
    }
    
    if (stream) {
        
        FSEventStreamStop(stream);
        FSEventStreamRelease(stream);
    }
    
    os_log(OS_LOG_DEFAULT, "SAPCorp: Exiting");
}

- (void)scheduleTerminationTimer
{
    if (_terminationTimer) {
        [_terminationTimer invalidate];
        _terminationTimer = nil;
    };
    
    _terminationTimer = [NSTimer scheduledTimerWithTimeInterval:30
                                                        repeats:YES
                                                          block:^(NSTimer *timer) {
        self->_shouldTerminate = YES;
    }];
}

- (void)postNotification
{
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kMTNotificationNameAdminGroupDidChange
                                                                   object:nil
                                                                 userInfo:nil
                                                                  options:NSNotificationDeliverImmediately | NSNotificationPostToAllSessions
    ];
    
    [self scheduleTerminationTimer];
}

@end

int main(int argc, const char * argv[])
{
#pragma unused(argc)
#pragma unused(argv)
    
    @autoreleasepool {
        
        Main *m = [[Main alloc] init];
        [m run];
    }
    
    return 0;
}
