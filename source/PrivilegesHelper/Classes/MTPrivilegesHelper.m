/*
    MTPrivilegesHelper.m
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

#import "MTPrivilegesHelper.h"
#import "MTCodeSigning.h"
#import "Constants.h"
#import "MTIdentity.h"
#import "MTExtensionConnection.h"
#import "MTExtensionRequestType.h"
#import <os/log.h>

@interface MTPrivilegesHelper ()
@property (nonatomic, strong, readwrite) NSMutableSet *activeConnections;
@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (nonatomic, strong, readwrite) MTExtensionConnection *extensionConnection;
@property (nonatomic, copy) void (^pendingReply)(BOOL success, NSError *error);
@property (assign) MTExtensionRequestType currentRequestType;
@property (assign) BOOL isReplacement;
@end

@interface ExtendedNSXPCConnection : NSXPCConnection
@property audit_token_t auditToken;
@end

OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

@implementation MTPrivilegesHelper

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _activeConnections = [[NSMutableSet alloc] init];
        _extensionConnection = [[MTExtensionConnection alloc] init];
                
        _listener = [[NSXPCListener alloc] initWithMachServiceName:kMTHelperMachServiceName];
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
        // additionally the calling application must have the same version number as this application and must 
        // use either use the bundle identifier "corp.sap.privileges.cli" or "corp.sap.privileges.agent"
        NSError *error = nil;
        NSString *signingAuth = [MTCodeSigning getSigningAuthorityWithError:&error];
        NSString *requiredVersion = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        
        if (signingAuth) {
            
            NSString *reqString = [MTCodeSigning codeSigningRequirementsWithCommonName:signingAuth
                                                                     bundleIdentifiers:[NSArray arrayWithObjects:
                                                                                        kMTCLIBundleIdentifier,
                                                                                        kMTAgentBundleIdentifier,
                                                                                        nil]
                                                                         versionString:requiredVersion
            ];
            SecTaskRef taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
                       
            if (taskRef) {

                OSStatus result = SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(reqString));
                
                if (result == errSecSuccess) {

                    acceptConnection = YES;
                       
                    [newConnection setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(PrivilegesHelperProtocol)]];
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
                    
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Code signature verification failed (error %d)", result);
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

#pragma mark - Exported methods

- (void)enableExtensionWithCompletionHandler:(void(^)(BOOL success, NSError *error))completionHandler
{
    _isReplacement = NO;
    _pendingReply = completionHandler;
    _currentRequestType = MTExtensionRequestTypeEnable;
    
    OSSystemExtensionRequest *req = [OSSystemExtensionRequest activationRequestForExtension:kMTExtensionBundleIdentifier
                                                                                      queue:dispatch_get_main_queue()
    ];
    [req setDelegate:self];
    [[OSSystemExtensionManager sharedManager] submitRequest:req];
    
    
}

- (void)disableExtensionWithCompletionHandler:(void(^)(BOOL success, NSError *error))completionHandler
{
    _pendingReply = completionHandler;
    _currentRequestType = MTExtensionRequestTypeDisable;
    
    OSSystemExtensionRequest *req = [OSSystemExtensionRequest deactivationRequestForExtension:kMTExtensionBundleIdentifier
                                                                                        queue:dispatch_get_main_queue()
    ];
    [req setDelegate:self];
    [[OSSystemExtensionManager sharedManager] submitRequest:req];
}

- (void)suspendExtensionWithCompletionHandler:(void(^)(BOOL success, NSError *error))completionHandler
{
    [_extensionConnection connectToExtensionAndExecuteCommandBlock:^{
        
        [[[self->_extensionConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to extension: %{public}@", error);
            if (completionHandler) { completionHandler(NO, nil); }
            
        }] suspendExtensionUsingAuthorizedPID:[[NSXPCConnection currentConnection] processIdentifier] completionHandler:^(BOOL success, NSError *error) {
            
            if (success) {
                os_log(OS_LOG_DEFAULT, "SAPCorp: System extension suspended");
            } else {
                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to suspend system extension: %{public}@", error);
            }
            
            if (completionHandler) { completionHandler(success, nil); }
        }];
    }];
}

- (void)extensionStatusWithReply:(void(^)(NSString *status))reply
{
    [_extensionConnection connectToExtensionAndExecuteCommandBlock:^{
        
        [[[self->_extensionConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to extension: %{public}@", error);
            if (reply) { reply(@""); }
            
        }] statusWithReply:^(NSString *status) {
            
            if (reply) { reply(status); }
        }];
    }];
}

#pragma mark - OSSystemExtensionRequestDelegate

- (OSSystemExtensionReplacementAction)request:(OSSystemExtensionRequest OS_UNUSED *)request actionForReplacingExtension:(OSSystemExtensionProperties *)existing withExtension:(OSSystemExtensionProperties *)extension
{
    _isReplacement = YES;
    
    os_log(OS_LOG_DEFAULT, "SAPCorp: Got system extension replacement request (version %{public}@ -> version %{public}@)", [existing bundleVersion], [extension bundleVersion]);
    
    return OSSystemExtensionReplacementActionReplace;
}

- (void)requestNeedsUserApproval:(OSSystemExtensionRequest *)request
{
    os_log(OS_LOG_DEFAULT, "SAPCorp: Got request to enable system extension. Awaiting approval");
}

- (void)request:(OSSystemExtensionRequest *)request didFinishWithResult:(OSSystemExtensionRequestResult)result
{
    if (_currentRequestType == MTExtensionRequestTypeEnable) {
        
        os_log(OS_LOG_DEFAULT, "SAPCorp: System extension enabled");
        
        if (_isReplacement) {
            
            if (self->_pendingReply) {
                
                self->_pendingReply(YES, nil);
                self->_pendingReply = nil;
            }
            
        } else {
            
            // make sure a suspended extension is resumed
            [self extensionStatusWithReply:^(NSString *status) {
                
                if ([status isEqualToString:@"suspended"]) {
                    
                    [self->_extensionConnection connectToExtensionAndExecuteCommandBlock:^{
                        
                        [[[self->_extensionConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
                            
                            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to extension: %{public}@", error);
                            
                            if (self->_pendingReply) {
                                
                                self->_pendingReply(NO, nil);
                                self->_pendingReply = nil;
                            }
                            
                        }] resumeExtensionWithCompletionHandler:^(BOOL success) {
                            
                            if (success) {
                                os_log(OS_LOG_DEFAULT, "SAPCorp: System extension has resumed");
                            } else {
                                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: System extension is still suspended");
                            }
                            
                            if (self->_pendingReply) {
                                
                                self->_pendingReply(YES, nil);
                                self->_pendingReply = nil;
                            }
                        }];
                    }];
                    
                } else {
                    
                    if (self->_pendingReply) {
                        
                        self->_pendingReply(YES, nil);
                        self->_pendingReply = nil;
                    }
                }
            }];
        }
        
    } else {
        
        os_log(OS_LOG_DEFAULT, "SAPCorp: System extension disabled");
        
        if (self->_pendingReply) {
            
            self->_pendingReply(YES, nil);
            self->_pendingReply = nil;
        }
    }
}

- (void)request:(OSSystemExtensionRequest *)request didFailWithError:(NSError *)error
{
    if (_currentRequestType == MTExtensionRequestTypeEnable) {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to enable system extension: %{public}@", error);
    } else {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to disable system extension: %{public}@", error);
    }
    
    if (_pendingReply) {
        
        _pendingReply(NO, error);
        _pendingReply = nil;
    }
}

@end
