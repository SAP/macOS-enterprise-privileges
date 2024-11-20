/*
    MTPrivilegesUser.m
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

#import "MTPrivilegesUser.h"
#import "MTAgentConnection.h"
#import "Constants.h"
#import <pwd.h>

@interface MTPrivilegesUser ()
@property (nonatomic, strong, readwrite) MTAgentConnection *agentConnection;
@property (nonatomic, strong, readwrite) NSString *userName;
@end

@implementation MTPrivilegesUser

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _userName = NSUserName();
        _agentConnection = [[MTAgentConnection alloc] init];
    }
    
    return self;
}

- (BOOL)hasAdminPrivileges
{
    return [MTIdentity getGroupMembershipForUser:[self userName] groupID:kMTAdminGroupID error:nil];
}

- (void)requestAdminPrivilegesWithReason:(NSString *)reason completionHandler:(void (^)(BOOL success))completionHandler
{
    [_agentConnection connectToAgentWithExportedObject:nil
                                andExecuteCommandBlock:^{
        
        [[[self->_agentConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to agent: %{public}@", error);
            if (completionHandler) { completionHandler(NO); }
            
        }] requestAdminRightsWithReason:reason completionHandler:^(BOOL success) {
           
            if (completionHandler) { completionHandler(success); }
        }];
    }];
}

- (void)revokeAdminPrivilegesWithCompletionHandler:(void (^)(BOOL success))completionHandler
{
    [_agentConnection connectToAgentWithExportedObject:nil
                                    andExecuteCommandBlock:^{
        
        [[[self->_agentConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to agent: %{public}@", error);
            if (completionHandler) { completionHandler(NO); }
            
        }] revokeAdminRightsWithCompletionHandler:^(BOOL success) {
          
            if (completionHandler) { completionHandler(success); }
        }];
    }];
}

- (void)authenticateWithCompletionHandler:(void(^)(BOOL success))completionHandler
{            
    [_agentConnection connectToAgentWithExportedObject:nil
                                andExecuteCommandBlock:^{
        
        [[[self->_agentConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to agent: %{public}@", error);
            if (completionHandler) { completionHandler(NO); }
            
        }] authenticateUserWithCompletionHandler:^(BOOL success) {
          
            if (completionHandler) { completionHandler(success); }
        }];
    }];
}

- (void)privilegesExpirationWithReply:(void (^)(NSDate *expire, NSUInteger remaining))reply
{
    [_agentConnection connectToAgentWithExportedObject:nil
                                andExecuteCommandBlock:^{
        
        [[[self->_agentConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to agent: %{public}@", error);
            if (reply) { reply(nil, 0); }
            
        }] expirationWithReply:^(NSDate *expires, NSUInteger remaining) {
         
            if (reply) { reply(expires, remaining); }
        }];
    }];
}

- (void)canExecuteFileAtURL:(NSURL*)url reply:(void (^)(BOOL canExecute))reply
{
    [_agentConnection connectToAgentWithExportedObject:nil
                                andExecuteCommandBlock:^{
        
        [[[self->_agentConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to agent: %{public}@", error);
            if (reply) { reply(NO); }
            
        }] isExecutableFileAtURL:url reply:^(BOOL isExecutable) {
         
            if (reply) { reply(isExecutable); }
        }];
    }];
}

@end
