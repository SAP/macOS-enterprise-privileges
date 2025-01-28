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
#import "MTPrivilegesDaemon.h"
#import "Constants.h"

@interface Main : NSObject
@property (nonatomic, strong, readwrite) MTPrivilegesDaemon *privilegesDaemon;
@property (assign) BOOL shouldTerminate;
@end

@implementation Main

- (void)run
{
    os_log(OS_LOG_DEFAULT, "SAPCorp: Starting");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        self->_shouldTerminate = YES;
    });
    
    while (!_shouldTerminate || [_privilegesDaemon numberOfActiveXPCConnections] > 0) {
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:60]];
    }
    
    [_privilegesDaemon invalidateXPC];
    os_log(OS_LOG_DEFAULT, "SAPCorp: Exiting");
}

@end


int main(int argc, const char * argv[])
{
#pragma unused(argc)
#pragma unused(argv)
            
    @autoreleasepool {
            
        Main *m = [[Main alloc] init];
        m.privilegesDaemon = [[MTPrivilegesDaemon alloc] init];
        [m run];
    }
    
    return EXIT_SUCCESS;
}
