/*
 PrivilegesHelper.m
 Copyright 2016-2020 SAP SE
 
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

#import "PrivilegesHelper.h"
#import "MTAuthCommon.h"
#import "MTIdentity.h"
#import "MTSyslog.h"
#import <CoreServices/CoreServices.h>
#import <Collaboration/Collaboration.h>
#import <errno.h>
#import <os/log.h>

@interface PrivilegesHelper () <NSXPCListenerDelegate, HelperToolProtocol>
@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (atomic, strong, readwrite) MTSyslog *syslogServer;
@property (atomic, assign) BOOL shouldTerminate;
@property (atomic, assign) BOOL networkOperation;
@end

@interface ExtendedNSXPCConnection : NSXPCConnection
@property audit_token_t auditToken;
@end

OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

@implementation PrivilegesHelper

- (id)init
{
    self = [super init];
    if (self != nil) {
        
        // Set up our XPC listener to handle requests on our Mach service.
        self->_listener = [[NSXPCListener alloc] initWithMachServiceName:kHelperToolMachServiceName];
        [self->_listener setDelegate:self];
    }
    
    return self;
}

- (void)run
{
    // Tell the XPC listener to start processing requests.
    [_listener resume];
    
    // run until _shouldTerminate is true and network operations have been finished
    while (!(_shouldTerminate && !_networkOperation)) { [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:20.0]]; }
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
// Called by our XPC listener when a new connection comes in.  We configure the connection
// with our protocol and ourselves as the main object.
{
    assert(listener == _listener);
#pragma unused(listener)
    assert(newConnection != nil);
    
    BOOL acceptConnection = NO;
    
    // see how we have been signed and make sure only processes with the same signing authority can connect
    NSError *error = nil;
    NSString *signingAuth = [MTAuthCommon getSigningAuthorityWithError:&error];

    if (signingAuth) {
        NSString *reqString = [NSString stringWithFormat:@"anchor trusted and certificate leaf [subject.CN] = \"%@\"", signingAuth];
        SecTaskRef taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
    
        if (taskRef) {

            if (SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(reqString)) == errSecSuccess) {
                acceptConnection = YES;
                
                newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
                newConnection.exportedObject = self;
                [newConnection resume];
                
            } else {
                os_log(OS_LOG_DEFAULT, "SAPCorp: ERROR! Code signature verification failed");
            }
            
            CFRelease(taskRef);
        }
        
    } else {
        os_log(OS_LOG_DEFAULT, "SAPCorp: ERROR! Failed to get code signature: %{public}@", error);
    }
    
    return acceptConnection;
}

- (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command
// Check that the client denoted by authData is allowed to run the specified command.
{
#pragma unused(authData)
    NSError *error;
    OSStatus err;
    OSStatus junk;
    AuthorizationRef authRef;
    
    assert(command != nil);
    
    authRef = NULL;
    
    // First check that authData looks reasonable.
    error = nil;
    if ( (authData == nil) || ([authData length] != sizeof(AuthorizationExternalForm)) ) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    // Create an authorization ref from that the external form data contained within.
    
    if (error == nil) {
        err = AuthorizationCreateFromExternalForm([authData bytes], &authRef);
        
        // Authorize the right associated with the command.
        
        if (err == errAuthorizationSuccess) {
            AuthorizationItem   oneRight = { NULL, 0, NULL, 0 };
            AuthorizationRights rights   = { 1, &oneRight };
            
            oneRight.name = [[MTAuthCommon authorizationRightForCommand:command] UTF8String];
            assert(oneRight.name != NULL);
            
            err = AuthorizationCopyRights(
                                          authRef,
                                          &rights,
                                          NULL,
                                          kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed,
                                          NULL
                                          );
        }
        if (err != errAuthorizationSuccess) {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
        }
    }
    
    if (authRef != NULL) {
        junk = AuthorizationFree(authRef, 0);
        assert(junk == errAuthorizationSuccess);
    }
    
    return error;
}

#pragma mark *HelperToolProtocol implementation

// IMPORTANT: NSXPCConnection can call these methods on any thread.  It turns out that our
// implementation of these methods is thread safe but if that's not the case for your code
// you have to implement your own protection (for example, having your own serial queue and
// dispatching over to it).

- (void)connectWithEndpointReply:(void (^)(NSXPCListenerEndpoint *))reply
    // Part of the HelperToolProtocol.  Not used by the standard app (it's part of the sandboxed
    // XPC service support).  Called by the XPC service to get an endpoint for our listener.  It then
    // passes this endpoint to the app so that the sandboxed app can talk us directly.
{
    reply([self.listener endpoint]);
}

- (void)helperVersionWithReply:(void(^)(NSString *version))reply
{
    reply([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
}

- (void)changeAdminRightsForUser:(NSString*)userName
                          remove:(BOOL)remove
                          reason:(NSString*)reason
                   authorization:(NSData*)authData
                       withReply:(void(^)(NSError *error))reply
{
    NSString *errorMsg = nil;
    NSError *error = [self checkAuthorization:authData command:_cmd];
    
    if (!error) {
        
        if (userName) {
            
            // get the user identity
            CBIdentity *userIdentity = [CBIdentity identityWithName:userName
                                                          authority:[CBIdentityAuthority defaultIdentityAuthority]];
            
            if (userIdentity) {
                
                // get the group identity
                CBGroupIdentity *groupIdentity = [CBGroupIdentity groupIdentityWithPosixGID:ADMIN_GROUP_ID
                                                                                  authority:[CBIdentityAuthority localIdentityAuthority]];
                
                if (groupIdentity) {
                    
                    CSIdentityRef csUserIdentity = [userIdentity CSIdentity];
                    CSIdentityRef csGroupIdentity = [groupIdentity CSIdentity];
                    
                    // add or remove the user to/from the group
                    if (remove) {
                        CSIdentityRemoveMember(csGroupIdentity, csUserIdentity);
                    } else {
                        CSIdentityAddMember(csGroupIdentity, csUserIdentity);
                    }
                    
                    // commit changes to the identity store to update the group
                    if (CSIdentityCommit(csGroupIdentity, NULL, NULL)) {
                        
                        // re-check the group membership. this seems to update some caches or so. without this re-checking
                        // sometimes the system does not recognize the changes of the group membership instantly.
                        [MTIdentity getGroupMembershipForUser:userName groupID:ADMIN_GROUP_ID error:nil];
                        
                        // log the privilege change
                        NSString *logMessage = [NSString stringWithFormat:@"SAPCorp: User %@ has now %@ rights", userName, (remove) ? @"standard user" : @"admin"];
                        if ([reason length] > 0) { logMessage = [logMessage stringByAppendingFormat:@" for the following reason: %@", reason]; }
                        os_log(OS_LOG_DEFAULT, "%{public}@", logMessage);
                        
                        // if remote logging has been configured, we send the log message to the remote
                        // logging server as well
                        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"corp.sap.privileges"];
                        
                        if ([userDefaults objectIsForcedForKey:@"RemoteLogging"]) {
                            
                            // get the required configuration data
                            NSDictionary *remoteLogging = [userDefaults dictionaryForKey:@"RemoteLogging"];
                            NSString *serverType = [remoteLogging objectForKey:@"ServerType"];
                            NSString *serverAddress = [remoteLogging objectForKey:@"ServerAddress"];
                            
                            if ([[serverType lowercaseString] isEqualToString:@"syslog"] && serverAddress) {
                                
                                NSInteger serverPort = [[remoteLogging objectForKey:@"ServerPort"] integerValue];
                                BOOL enableTCP = [[remoteLogging objectForKey:@"EnableTCP"] boolValue];
                                NSDictionary *syslogOptions = [remoteLogging objectForKey:@"SyslogOptions"];
                                NSUInteger logFacility = ([syslogOptions objectForKey:@"LogFacility"]) ? [[syslogOptions valueForKey:@"LogFacility"] integerValue] : MTSyslogMessageFacilityAuth;
                                NSUInteger logSeverity = ([syslogOptions objectForKey:@"LogSeverity"]) ? [[syslogOptions valueForKey:@"LogSeverity"] integerValue] : MTSyslogMessageSeverityInformational;
                                NSUInteger maxSize = ([syslogOptions objectForKey:@"MaximumMessageSize"]) ? [[syslogOptions valueForKey:@"MaximumMessageSize"] integerValue] : 0;
                                
                                MTSyslogMessage *message = [[MTSyslogMessage alloc] init];
                                [message setFacility:logFacility];
                                [message setSeverity:logSeverity];
                                [message setAppName:@"Privileges"];
                                [message setMessageId:(remove) ? @"PRIV_S" : @"PRIV_A"];
                                if (maxSize > MTSyslogMessageMaxSize480) { [message setMaxSize:maxSize]; }
                                [message setEventMessage:logMessage];
                                 
                                _syslogServer = [[MTSyslog alloc] initWithServerAddress:serverAddress
                                                                             serverPort:(serverPort > 0) ? serverPort : 514
                                                                            andProtocol:(enableTCP) ? MTSocketTransportLayerProtocolTCP : MTSocketTransportLayerProtocolUDP
                                                          ];
                                
                                _networkOperation = YES;
                                [_syslogServer sendMessage:message completionHandler:^(NSError *networkError) {
                                    
                                    if (networkError) {
                                        os_log(OS_LOG_DEFAULT, "SAPCorp: ERROR! Remote logging failed: %{public}@", networkError);
                                    }
                                    
                                    dispatch_async(dispatch_get_main_queue(), ^{ self->_networkOperation = NO; });
                                }];
                                
                            } else {
                                os_log(OS_LOG_DEFAULT, "SAPCorp: ERROR! Remote logging is misconfigured");
                            }
                        }
                        
                    } else {
                        errorMsg = @"Identity could not be committed to the authority database";
                    }
                    
                }  else {
                    errorMsg = @"Missing group identity";
                }
                
            }  else {
                errorMsg = @"Missing user identity";
            }
            
        }  else {
            errorMsg = @"User name is missing";
        }
    
    } else {
         errorMsg = @"Authorization check failed";
    }
    
    if ([errorMsg length] > 0) {
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:errorMsg, NSLocalizedDescriptionKey, nil];
        error = [NSError errorWithDomain:@"corp.sap.privileges" code:100 userInfo:errorDetail];
    }
    
    reply(error);
}

- (void)quitHelperTool
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_shouldTerminate = YES;
    });
}

@end
