/*
PrivilegesXPC.m
Copyright 2020 SAP SE

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
#import "MTAuthCommon.h"
#import "PrivilegesHelper.h"
#import <ServiceManagement/ServiceManagement.h>
#import <os/log.h>

@interface PrivilegesXPC () <NSXPCListenerDelegate, PrivilegesXPCProtocol>
@property (atomic, strong, readonly) NSXPCListener *listener;
@property (atomic, copy, readonly) NSData *authorization;
@property (atomic, strong, readonly) NSOperationQueue *queue;
@property (atomic, strong, readwrite) NSXPCConnection *helperToolConnection;
@property (assign) AuthorizationRef authRef;
@end

@interface ExtendedNSXPCConnection : NSXPCConnection
@property audit_token_t auditToken;
@end

OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

@implementation PrivilegesXPC

- (id)init
{
    self = [super init];
    
    if (self != nil) {
        OSStatus err;
        AuthorizationExternalForm extForm;
        
        self->_listener = [NSXPCListener serviceListener];
        assert(self->_listener != nil);     // this code must be run from an XPC service

        self->_listener.delegate = self;

        err = AuthorizationCreate(NULL, NULL, 0, &self->_authRef);
        if (err == errAuthorizationSuccess) {
            err = AuthorizationMakeExternalForm(self->_authRef, &extForm);
        }
        if (err == errAuthorizationSuccess) {
            self->_authorization = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
        }
        assert(err == errAuthorizationSuccess);
        
        self->_queue = [[NSOperationQueue alloc] init];
        [self->_queue setMaxConcurrentOperationCount:1];
    }
    
    return self;
}

- (void)dealloc
{
    if (self->_authRef != NULL) {
        (void) AuthorizationFree(self->_authRef, 0);
    }
}

- (void)run
{
    [self.listener resume];     // never comes back
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
    // Called by our XPC listener when a new connection comes in.  We configure the connection
    // with our protocol and ourselves as the main object.
{
    assert(listener == self.listener);
    #pragma unused(listener)
    assert(newConnection != nil);
    
    BOOL acceptConnection = NO;

    // see how we have been signed and make sure only processes with the same signing authority can connect.
    // additionally the calling application must have the same version number as this helper and must be one
    // of the components using a bundle identifier starting with "corp.sap.privileges"
    NSError *error = nil;
    NSString *signingAuth = [MTAuthCommon getSigningAuthorityWithError:&error];
    NSString *requiredVersion = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    if (signingAuth) {
        NSString *reqString = [NSString stringWithFormat:@"anchor trusted and certificate leaf [subject.CN] = \"%@\" and info [CFBundleShortVersionString] >= \"%@\" and info [CFBundleIdentifier] = corp.sap.privileges*", signingAuth, requiredVersion];
        SecTaskRef taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
       
        if (taskRef) {

            if (SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(reqString)) == errSecSuccess) {
                   acceptConnection = YES;
                   
                newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(PrivilegesXPCProtocol)];
                newConnection.exportedObject = self;
                [newConnection resume];
    
            } else {
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Code signature verification failed");
            }
                
            CFRelease(taskRef);
        }
            
    } else {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Failed to get code signature: %{public}@", error);
    }
        
    return acceptConnection;
}

- (void)installHelperToolWithReply:(void(^)(NSError *error))reply
    // Part of XPCServiceProtocol.  Called by the app to install the helper tool.
{
    Boolean success;
    CFErrorRef error;
    
    success = SMJobBless(
        kSMDomainSystemLaunchd,
        CFSTR("corp.sap.privileges.helper"),
        self->_authRef,
        &error
    );

    if (success) {
        reply(nil);
    } else {
        assert(error != NULL);
        reply((__bridge NSError *) error);
        CFRelease(error);
    }
}

- (void)setupAuthorizationRights
    // Part of XPCServiceProtocol.  Called by the app at startup time to set up our
    // authorization rights in the authorization database.
{
    [MTAuthCommon setupAuthorizationRights:self->_authRef];
}

- (void)connectWithEndpointAndAuthorizationReply:(void(^)(NSXPCListenerEndpoint *endpoint, NSData *authorization))reply
    // Part of XPCServiceProtocol.  Called by the app to get an endpoint that's
    // connected to the helper tool.  This a also returns the XPC service's authorization
    // reference so that the app can pass that to the requests it sends to the helper tool.
    // Without this authorization will fail because the app is sandboxed.
{
    // Because we access helperToolConnection, we have to run on the operation queue.
    
    [self.queue addOperationWithBlock:^{

        // Create our connection to the helper tool if it's not already in place.
        
        if (self.helperToolConnection == nil) {
            self.helperToolConnection = [[NSXPCConnection alloc] initWithMachServiceName:kHelperToolMachServiceName options:NSXPCConnectionPrivileged];
            self.helperToolConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-retain-cycles"
            // We can ignore the retain cycle warning because a) the retain taken by the
            // invalidation handler block is released by us setting it to nil when the block
            // actually runs, and b) the retain taken by the block passed to -addOperationWithBlock:
            // will be released when that operation completes and the operation itself is deallocated
            // (notably self does not have a reference to the NSBlockOperation).
            self.helperToolConnection.invalidationHandler = ^{
                // If the connection gets invalidated then, on our operation queue thread, nil out our
                // reference to it.  This ensures that we attempt to rebuild it the next time around.
                self.helperToolConnection.invalidationHandler = nil;
                [self.queue addOperationWithBlock:^{
                    self.helperToolConnection = nil;
                    os_log(OS_LOG_DEFAULT, "SAPCorp: Helper tool connection invalidated");
                }];
            };
            #pragma clang diagnostic pop
            [self.helperToolConnection resume];
        }

        // Call the helper tool to get the endpoint we need.
        [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Failed to connect to helper tool: %{public}@ / %{public}d", [proxyError domain], (int)[proxyError code]);
            reply(nil, nil);
        }] connectWithEndpointReply:^(NSXPCListenerEndpoint *replyEndpoint) {
            reply(replyEndpoint, self.authorization);
        }];
    }];
}

@end
