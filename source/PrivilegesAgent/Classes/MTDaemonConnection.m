/*
    MTDaemonConnection.m
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

#import "MTDaemonConnection.h"
#import "Constants.h"

@interface MTDaemonConnection ()
@property (atomic, strong, readwrite) NSXPCConnection *connection;
@property (atomic, strong, readwrite) NSXPCListenerEndpoint *listenerEndpoint;
@property (nonatomic, strong, readwrite) NSTimer *xpcTimeoutTimer;
@end


@implementation MTDaemonConnection

- (void)connectToDaemonAndExecuteCommandBlock:(void(^)(void))commandBlock
{
    if (!_connection) {
        
        _connection = [[NSXPCConnection alloc] initWithMachServiceName:kMTDaemonMachServiceName
                                                               options:NSXPCConnectionPrivileged
        ];
        [_connection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(PrivilegesDaemonProtocol)]];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        [_connection setInvalidationHandler:^{
          
            [self->_connection setInvalidationHandler:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                os_log(OS_LOG_DEFAULT, "SAPCorp: Daemon connection invalidated");
                self->_connection = nil;
            });
        }];
        
        [_connection setInterruptionHandler:^{
         
            [self->_connection setInterruptionHandler:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                os_log(OS_LOG_DEFAULT, "SAPCorp: Daemon connection interrupted");
                self->_connection = nil;
            });
        }];
#pragma clang diagnostic pop
        
        [_connection resume];
    }
        
    // and execute the command block
    commandBlock();
    
    dispatch_async(dispatch_get_main_queue(), ^{
    
        self->_xpcTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:60
                                                                 repeats:NO
                                                                   block:^(NSTimer *timer) {
            [self invalidate];
        }];
    });
}

- (void)invalidate
{
    if (_connection) { [_connection invalidate]; }
}

@end
