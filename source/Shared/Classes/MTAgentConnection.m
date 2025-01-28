/*
    MTAgentConnection.m
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

#import "MTAgentConnection.h"
#import "MTCodeSigning.h"
#import "Constants.h"

@interface MTAgentConnection ()
@property (atomic, strong, readwrite) NSXPCConnection *xpcServiceConnection;
@property (atomic, strong, readwrite) NSXPCConnection *connection;
@property (atomic, strong, readwrite) id remoteObjectProxy;
@property (atomic, strong, readwrite) NSXPCListenerEndpoint *listenerEndpoint;
@end

@implementation MTAgentConnection

- (void)connectToAgentWithExportedObject:(id)exportedObject
                  andExecuteCommandBlock:(void(^)(void))commandBlock
{
    // if we run from within a sandboxed app, we using our XPC Service
    // to initially connect to our agent. Otherwise we connect to the
    // agent directly.
    [MTCodeSigning sandboxStatusWithCompletionHandler:^(BOOL isSandboxed, NSError *error) {
        
        if (!error && isSandboxed) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // get the listener endpoint so we can talk to the agent directly
                [self getListenerEndpointWithCompletionHandler:^(NSXPCListenerEndpoint *endpoint, NSError *error) {
                    
                    if (endpoint) {
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            // connect to our agent
                            [self connectToAgentWithEndpoint:endpoint andExportObject:exportedObject];
                            
                            // and execute the command block
                            commandBlock();
                        });
                        
                    } else if (self->_delegate && [self->_delegate respondsToSelector:@selector(connection:didFailWithError:)]) {
                        [self->_delegate connection:[self connection] didFailWithError:error];
                    }
                    
                }];
            });
            
        } else {

            // try to directly connect to the agent
            [self connectToAgentDirectly];
                
            // and execute the command block
            commandBlock();
        }
    }];
}

- (void)getListenerEndpointWithCompletionHandler:(void (^) (NSXPCListenerEndpoint *endpoint, NSError *error))completionHandler;
{
    if (!_listenerEndpoint) {

        [self connectToXPCServiceWithRemoteObjectProxyReply:^(id remoteObjectProxy, NSError *error) {
           
            if (error) {
                
                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to XPC Service: %{public}@", error);
                if (completionHandler) { completionHandler(nil, error); }
                
            } else {
                
                [remoteObjectProxy connectWithAgentEndpointReply:^(NSXPCListenerEndpoint *endpoint) {
                    
                    if (completionHandler) { completionHandler(endpoint, nil); }
                }];
            }
        }];
        
    } else if (completionHandler) {
        
        completionHandler(_listenerEndpoint, nil);
    }
}

- (void)connectToXPCService
{
    assert([NSThread isMainThread]);

    if (!_xpcServiceConnection) {

        _xpcServiceConnection = [[NSXPCConnection alloc] initWithServiceName:kMTXPCServiceName];
        [_xpcServiceConnection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(PrivilegesXPCProtocol)]];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        [_xpcServiceConnection setInvalidationHandler:^{
            
            [self.xpcServiceConnection setInvalidationHandler:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.remoteObjectProxy = nil;
                self.listenerEndpoint = nil;
                self.xpcServiceConnection = nil;
                os_log(OS_LOG_DEFAULT, "SAPCorp: XPC Service connection invalidated");
            });
        }];
        
        [_xpcServiceConnection setInterruptionHandler:^{
            
            [self.xpcServiceConnection setInterruptionHandler:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.remoteObjectProxy = nil;
                self.listenerEndpoint = nil;
                self.xpcServiceConnection = nil;
                os_log(OS_LOG_DEFAULT, "SAPCorp: XPC Service connection interrupted");
            });
        }];
#pragma clang diagnostic pop
        
        [_xpcServiceConnection resume];
    }
}

- (void)connectToAgentDirectly
{
    if (!_connection) {
        
        _connection = [[NSXPCConnection alloc] initWithMachServiceName:kMTAgentMachServiceName
                                                               options:0
        ];
        [_connection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(PrivilegesAgentProtocol)]];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        [_connection setInvalidationHandler:^{
          
            [self->_connection setInvalidationHandler:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                os_log(OS_LOG_DEFAULT, "SAPCorp: Agent connection invalidated");
                self->_connection = nil;
            });
        }];
        
        [_connection setInterruptionHandler:^{
         
            [self->_connection setInterruptionHandler:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                os_log(OS_LOG_DEFAULT, "SAPCorp: Agent connection interrupted");
                self->_connection = nil;
            });
        }];
#pragma clang diagnostic pop

        [_connection resume];
    }
}

- (void)connectToAgentWithEndpoint:(NSXPCListenerEndpoint *)endpoint
                   andExportObject:(id)exportedObject
{
    assert([NSThread isMainThread]);
    
    if (!_connection && endpoint) {
        
        _connection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
        
        NSXPCInterface *remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(PrivilegesAgentProtocol)];
        [_connection setRemoteObjectInterface:remoteObjectInterface];
        if (exportedObject) { [_connection setExportedObject:exportedObject]; }
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        [_connection setInvalidationHandler:^{
        
            [self.connection setInvalidationHandler:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.remoteObjectProxy = nil;
                self.listenerEndpoint = nil;
                self.connection = nil;
                os_log(OS_LOG_DEFAULT, "SAPCorp: Agent connection invalidated");
            });
        }];
        
        [_connection setInterruptionHandler:^{
            
            [self.connection setInterruptionHandler:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.remoteObjectProxy = nil;
                self.listenerEndpoint = nil;
                self.connection = nil;
                os_log(OS_LOG_DEFAULT, "SAPCorp: Agent connection interrupted");
            });
        }];
#pragma clang diagnostic pop
        
        _remoteObjectProxy = [_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to agent: %{public}@", error);
            
            if (self->_delegate && [self->_delegate respondsToSelector:@selector(connection:didFailWithError:)]) {
                [self->_delegate connection:[self connection] didFailWithError:error];
            }
        }];
        
        [_connection resume];
    }
}

- (void)connectToXPCServiceWithRemoteObjectProxyReply:(void (^)(id remoteObjectProxy, NSError *error))reply
{
    [self connectToXPCService];
    id proxy = [_xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        reply(nil, error);
    }];
    
    if (proxy) { reply(proxy, nil); }
}

- (void)invalidate
{
    if (_connection) { [_connection invalidate]; }
    if (_xpcServiceConnection) { [_xpcServiceConnection invalidate]; }
}

@end
