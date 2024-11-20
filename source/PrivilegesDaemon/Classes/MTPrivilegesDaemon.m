/*
    MTPrivilegesDaemon.m
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

#import "MTPrivilegesDaemon.h"
#import "MTCodeSigning.h"
#import "Constants.h"
#import <Collaboration/Collaboration.h>
#import <os/log.h>

@interface MTPrivilegesDaemon ()
@property (nonatomic, strong, readwrite) NSMutableSet *activeConnections;
@property (atomic, strong, readwrite) NSXPCListener *listener;
@end

@interface ExtendedNSXPCConnection : NSXPCConnection
@property audit_token_t auditToken;
@end

OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

@implementation MTPrivilegesDaemon

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _activeConnections = [[NSMutableSet alloc] init];
                
        _listener = [[NSXPCListener alloc] initWithMachServiceName:kMTDaemonMachServiceName];
        [_listener setDelegate:self];
        [_listener resume];
    }
    
    return self;
}

- (void)invalidateXPC
{
    [_listener invalidate];
    _listener = nil;
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    BOOL acceptConnection = NO;
    
    if (listener == _listener && newConnection != nil) {
        
        // see how we have been signed and make sure only processes with the same signing authority can connect.
        // additionally the calling application must have the same version number as this xpc service and must be
        // one of the components using a bundle identifier starting with "corp.sap.privileges"
        NSError *error = nil;
        NSString *signingAuth = [MTCodeSigning getSigningAuthorityWithError:&error];
        NSString *requiredVersion = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        
        if (signingAuth) {

            // we only allow the Privileges agent to connect
            NSString *reqString = [MTCodeSigning codeSigningRequirementsWithCommonName:signingAuth
                                                                      bundleIdentifier:@"corp.sap.privileges.agent" 
                                                                         versionString:requiredVersion
            ];
            SecTaskRef taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
                       
            if (taskRef) {

                if (SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(reqString)) == errSecSuccess) {

                    acceptConnection = YES;
                       
                    NSXPCInterface *exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(PrivilegesDaemonProtocol)];
                    [newConnection setExportedInterface:exportedInterface];
                    [newConnection setExportedObject:self];
                    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
                    [newConnection setInvalidationHandler:^{
                                  
                        [newConnection setInvalidationHandler:nil];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.activeConnections removeObject:newConnection];
                            os_log(OS_LOG_DEFAULT, "SAPCorp: %{public}@ invalidated", newConnection);
                        });
                    }];
#pragma clang diagnostic pop
                    
                    [newConnection resume];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.activeConnections addObject:newConnection];
                        os_log(OS_LOG_DEFAULT, "SAPCorp: %{public}@ established", newConnection);
                    });
        
                } else {
                        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Code signature verification failed");
                }
                    
                CFRelease(taskRef);
            }
                
        } else {
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Failed to get code signature: %{public}@", error);
        }
    }

    return acceptConnection;
}

- (NSInteger)numberOfActiveXPCConnections
{
    return [_activeConnections count];
}

- (BOOL)changePrivilegesForUser:(NSString*)userName grantAdminPrivileges:(BOOL)grant
{
    BOOL success = NO;
        
    // get the group identity
    CBGroupIdentity *groupIdentity = [CBGroupIdentity groupIdentityWithPosixGID:kMTAdminGroupID
                                                                      authority:[CBIdentityAuthority localIdentityAuthority]
    ];
    
    if (groupIdentity) {
        
        CBIdentity *userIdentity = [CBIdentity identityWithName:userName
                                                      authority:[CBIdentityAuthority defaultIdentityAuthority]
        ];
        
        if (userIdentity) {
            
            CSIdentityRef csUserIdentity = [userIdentity CSIdentity];
            CSIdentityRef csGroupIdentity = [groupIdentity CSIdentity];
            
            // add or remove the user to/from the group
            if (grant) {
                CSIdentityAddMember(csGroupIdentity, csUserIdentity);
            } else {
                CSIdentityRemoveMember(csGroupIdentity, csUserIdentity);
            }
            
            // commit changes to the identity store to update the group
            success = CSIdentityCommit(csGroupIdentity, NULL, NULL);
        }
    }
    
    return success;
}

#pragma mark Exported methods

- (void)grantAdminRightsToUser:(NSString*)userName
                        reason:(NSString*)reason
             completionHandler:(void(^)(BOOL success))completionHandler
{
    BOOL success = NO;

    if (userName) {
                
        success = [self changePrivilegesForUser:userName grantAdminPrivileges:YES];
                
        if (success) {
            
            // log the privilege change
            NSString *logMessage = [NSString stringWithFormat:@"SAPCorp: User %@ now has administrator privileges", userName];
            if ([reason length] > 0) { logMessage = [logMessage stringByAppendingFormat:@" for the following reason: \"%@\"", reason]; }
            os_log(OS_LOG_DEFAULT, "%{public}@", logMessage);
            
        } else {
            
            NSString *logMessage = [NSString stringWithFormat:@"SAPCorp: Failed to change privileges for user %@", userName];
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "%{public}@", logMessage);
        }
    }
    
    if (completionHandler) { completionHandler(success); }
}

- (void)removeAdminRightsFromUser:(NSString*)userName
                           reason:(NSString*)reason
                completionHandler:(void(^)(BOOL success))completionHandler
{
    BOOL success = NO;

    if (userName) {
        
        success = [self changePrivilegesForUser:userName grantAdminPrivileges:NO];
                
        if (success) {
            
            // log the privilege change
            NSString *logMessage = [NSString stringWithFormat:@"SAPCorp: User %@ now has standard user privileges", userName];
            if ([reason length] > 0) { logMessage = [logMessage stringByAppendingFormat:@" (%@)", reason]; }
            os_log(OS_LOG_DEFAULT, "%{public}@", logMessage);
        
        } else {
            
            NSString *logMessage = [NSString stringWithFormat:@"SAPCorp: Failed to change privileges for user %@", userName];
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "%{public}@", logMessage);
        }
    }
    
    if (completionHandler) { completionHandler(success); }
}

@end
