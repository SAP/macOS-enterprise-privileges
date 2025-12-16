/*
    MTPrivilegesExtension.m
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

#import "MTPrivilegesExtension.h"
#import "MTCodeSigning.h"
#import "MTProcessValidation.h"
#import "Constants.h"
#import <os/log.h>

@interface MTPrivilegesExtension ()
@property (nonatomic, strong, readwrite) NSMutableSet *activeConnections;
@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (assign) BOOL isPaused;
@end

@interface ExtendedNSXPCConnection : NSXPCConnection
@property audit_token_t auditToken;
@end

OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

@implementation MTPrivilegesExtension

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _activeConnections = [[NSMutableSet alloc] init];
                
        _listener = [[NSXPCListener alloc] initWithMachServiceName:kMTExtensionMachServiceName];
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
        // additionally the calling application must have the same version number as this xpc service and must
        // use the bundle identifier "corp.sap.privileges.helper"
        NSError *error = nil;
        NSString *signingAuth = [MTCodeSigning getSigningAuthorityWithError:&error];
        NSString *requiredVersion = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        
        if (signingAuth) {

            // we only allow the Privileges helper to connect
            NSString *reqString = [MTCodeSigning codeSigningRequirementsWithCommonName:signingAuth
                                                                      bundleIdentifier:kMTHelperBundleIdentifier
                                                                         versionString:requiredVersion
            ];
            SecTaskRef taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
            
            if (taskRef) {

                OSStatus result = SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(reqString));
                
                if (result == errSecSuccess) {

                    acceptConnection = YES;
                    
                    [newConnection setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(PrivilegesExtensionProtocol)]];
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

- (void)suspendExtensionUsingAuthorizedPID:(pid_t)pid completionHandler:(void(^)(BOOL success, NSError *error))completionHandler
{
    NSError *error = nil;
    NSString *errorMsg = nil;
    
    if (pid > 1) {
        
        MTProcessValidation *upgradeProcess = [[MTProcessValidation alloc] initWithPID:pid];
        _isPaused = [upgradeProcess isValid];
        errorMsg = @"Process is not authorized";
        
    } else {
        
        _isPaused = NO;
        errorMsg = @"Invalid process id";
    }
    
    if (errorMsg) {
        
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:errorMsg, NSLocalizedDescriptionKey, nil];
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:100 userInfo:errorDetail];
    }
    
    if (completionHandler) { completionHandler(_isPaused, error); }
}

- (void)resumeExtensionWithCompletionHandler:(void(^)(BOOL success))completionHandler
{
    _isPaused = NO;
    if (completionHandler) { completionHandler(!_isPaused); }
}

- (void)statusWithReply:(void(^)(NSString *status))reply
{
    if (reply) {
        
        NSString *status = kMTExtensionStatusEnabled;
        
        if (_isPaused) {
            
            status = kMTExtensionStatusSuspended;
            
        } else if (!_isRunning) {
            
            status = kMTExtensionStatusWaiting;
        }
        
        reply(status);
    }
}

@end
