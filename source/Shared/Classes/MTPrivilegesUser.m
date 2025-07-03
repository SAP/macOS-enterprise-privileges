/*
    MTPrivilegesUser.m
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

#import "MTPrivilegesUser.h"
#import "MTAgentConnection.h"
#import "Constants.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <pwd.h>

@interface MTPrivilegesUser ()
@property (nonatomic, strong, readwrite) MTAgentConnection *agentConnection;
@property (nonatomic, strong, readwrite) NSUserDefaults *userDefaults;
@property (nonatomic, strong, readwrite) NSUserDefaults *appGroupDefaults;
@property (nonatomic, strong, readwrite) NSString *userName;
@end

@implementation MTPrivilegesUser

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        // we need to make sure that we always get the real console user (even if
        // someone runs PrivilegesCLI with sudo, for example). So we use
        // SCDynamicStoreCopyConsoleUser instead of NSUserName().
        CFStringRef console_user = SCDynamicStoreCopyConsoleUser(NULL, NULL, NULL);
        
        _userName = CFBridgingRelease(console_user);
        _agentConnection = [[MTAgentConnection alloc] init];
        
        if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:kMTAppBundleIdentifier]) {
            _userDefaults = [NSUserDefaults standardUserDefaults];
        } else {
            _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppBundleIdentifier];
        }
        
        _appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
    }
    
    return self;
}

- (BOOL)hasAdminPrivileges
{
    NSError *error = nil;
    BOOL isMember = [MTIdentity groupMembershipForUser:[self userName] groupID:kMTAdminGroupID error:&error];
    
    if (error) {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to get group membership for user %{public}@: %{public}@", [self userName], error);
    }
    
    return isMember;
}

- (BOOL)hasUnexpectedPrivilegeState
{
    BOOL unexpectedState = [_appGroupDefaults boolForKey:kMTDefaultsUnexpectedPrivilegeStateKey];
        
    return unexpectedState;
}

- (void)setUnexpectedPrivilegeState:(BOOL)unexpectedState
{
    if (unexpectedState) {
        [_appGroupDefaults setBool:YES forKey:kMTDefaultsUnexpectedPrivilegeStateKey];
    } else {
        [_appGroupDefaults removeObjectForKey:kMTDefaultsUnexpectedPrivilegeStateKey];
    }
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

- (void)renewAdminPrivilegesWithCompletionHandler:(void (^)(BOOL success))completionHandler
{
    [_agentConnection connectToAgentWithExportedObject:nil
                                    andExecuteCommandBlock:^{
        
        [[[self->_agentConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to agent: %{public}@", error);
            if (completionHandler) { completionHandler(NO); }
            
        }] renewAdminRightsWithCompletionHandler:^(BOOL success) {
          
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

- (BOOL)useIsRestricted
{
    NSString *enforcedPrivileges = ([_userDefaults objectIsForcedForKey:kMTDefaultsEnforcePrivilegesKey]) ? [_userDefaults objectForKey:kMTDefaultsEnforcePrivilegesKey] : nil;
    id limitToUser = ([_userDefaults objectIsForcedForKey:kMTDefaultsLimitToUserKey]) ? [_userDefaults objectForKey:kMTDefaultsLimitToUserKey] : nil;
    id limitToGroup = ([_userDefaults objectIsForcedForKey:kMTDefaultsLimitToGroupKey]) ? [_userDefaults objectForKey:kMTDefaultsLimitToGroupKey] : nil;
    
    BOOL userRestricted = YES;
    BOOL groupRestricted = YES;
    
    if (limitToUser) {
        
        if ([limitToUser isKindOfClass:[NSString class]]) {
            
            userRestricted = ([limitToUser caseInsensitiveCompare:_userName] != NSOrderedSame);
            
        } else if ([limitToUser isKindOfClass:[NSArray class]]) {
            
            for (NSString *userName in limitToUser) {
                
                if ([userName caseInsensitiveCompare:_userName] == NSOrderedSame) {
                    userRestricted = NO;
                    break;
                }
            }
        }
    }
    
    if (limitToGroup) {
        
        if ([limitToGroup isKindOfClass:[NSString class]]) {
            
            groupRestricted = ![MTIdentity groupMembershipForUser:_userName groupName:limitToGroup error:nil];
            
        } else if ([limitToGroup isKindOfClass:[NSArray class]]) {
            
            for (NSString *groupName in limitToGroup) {
                
                if ([MTIdentity groupMembershipForUser:_userName groupName:groupName error:nil]) {
                    groupRestricted = NO;
                    break;
                }
            }
        }
    }
    
    BOOL isRestricted = (
                         [enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeNone] ||
                         [enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeAdmin] ||
                         [enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeUser] ||
                         (limitToUser && userRestricted) ||
                         (!limitToUser && limitToGroup && groupRestricted)
                         );
    
    return isRestricted;
}

- (BOOL)isExcludedFromRevokeAtLogin
{
    BOOL userIsExcluded = NO;
    
    NSArray *excludedUsers = ([_userDefaults objectIsForcedForKey:kMTDefaultsRevokeAtLoginExcludedUsersKey]) ? [_userDefaults arrayForKey:kMTDefaultsRevokeAtLoginExcludedUsersKey] : nil;
    
    for (NSString *userName in excludedUsers) {

        if ([userName isKindOfClass:[NSString class]] &&
            [userName caseInsensitiveCompare:_userName] == NSOrderedSame) {
            
            userIsExcluded = YES;
            break;
        }
    }
    
    return userIsExcluded;
}

@end
