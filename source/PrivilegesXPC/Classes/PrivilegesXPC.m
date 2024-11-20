/*
    PrivilegesXPC.m
    Copyright 2024 SAP SE
     
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

#import "PrivilegesXPC.h"
#import "MTAgentConnection.h"
#import <os/log.h>

@interface PrivilegesXPC ()
@property (nonatomic, strong, readwrite) MTAgentConnection *agentConnection;
@end

@implementation PrivilegesXPC

- (void)connectWithAgentEndpointReply:(void(^)(NSXPCListenerEndpoint *endpoint))reply
{
    if (!_agentConnection) { _agentConnection = [[MTAgentConnection alloc] init]; }
    
    [_agentConnection connectToAgentWithExportedObject:nil
                                andExecuteCommandBlock:^{
        
        [[[self->_agentConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to agent: %{public}@", error);
            
        }] connectWithEndpointReply:^(NSXPCListenerEndpoint *endpoint) {
            
            reply(endpoint);
        }];
    }];
}

- (void)dealloc
{
    if (_agentConnection) { [_agentConnection invalidate]; }
}

@end
