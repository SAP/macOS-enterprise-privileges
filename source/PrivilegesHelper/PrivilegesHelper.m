/*
 PrivilegesHelper.m
 Copyright 2016-2018 SAP SE
 
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
#import <CoreServices/CoreServices.h>
#import <Collaboration/Collaboration.h>
#import <errno.h>

@interface PrivilegesHelper () <NSXPCListenerDelegate, HelperToolProtocol>
@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (nonatomic, assign) BOOL shouldTerminate;
@end

static const NSTimeInterval kHelperCheckInterval = 20.0;

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
    
    while (!_shouldTerminate)
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kHelperCheckInterval]];
    }
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
// Called by our XPC listener when a new connection comes in.  We configure the connection
// with our protocol and ourselves as the main object.
{
    assert(listener == _listener);
#pragma unused(listener)
    assert(newConnection != nil);
    
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
    newConnection.exportedObject = self;
    [newConnection resume];
    
    return YES;
}

- (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command
// Check that the client denoted by authData is allowed to run the specified command.
// authData is expected to be an NSData with an AuthorizationExternalForm embedded inside.
{
#pragma unused(authData)
    NSError *                   error;
    OSStatus                    err;
    OSStatus                    junk;
    AuthorizationRef            authRef;
    
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

#pragma mark * HelperToolProtocol implementation

// IMPORTANT: NSXPCConnection can call these methods on any thread.  It turns out that our
// implementation of these methods is thread safe but if that's not the case for your code
// you have to implement your own protection (for example, having your own serial queue and
// dispatching over to it).

- (void)getVersionWithReply:(void(^)(NSString * version))reply
{
    reply([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
}

- (void)changeGroupMembershipForUser:(NSString*)userName group:(uint)groupID remove:(BOOL)remove authorization:(NSData *)authData withReply:(void(^)(NSError *error))reply
{
    NSError *error = [self checkAuthorization:authData command:_cmd];
    
    if (error == nil) {
        
        if (userName != nil) {
            
            // get the user identity
            CBIdentity *userIdentity = [CBIdentity identityWithName:userName authority:[CBIdentityAuthority defaultIdentityAuthority]];
            
            if (userIdentity != nil) {
                
                // get the group identity
                CBGroupIdentity *groupIdentity = [CBGroupIdentity groupIdentityWithPosixGID:groupID authority:[CBIdentityAuthority localIdentityAuthority]];
                
                if (groupIdentity != nil) {
                    
                    CSIdentityRef csUserIdentity = [userIdentity CSIdentity];
                    CSIdentityRef csGroupIdentity = [groupIdentity CSIdentity];
                    
                    // add or remove the user to/from the group
                    if (remove) {
                        CSIdentityRemoveMember(csGroupIdentity, csUserIdentity);
                    } else {
                        CSIdentityAddMember(csGroupIdentity, csUserIdentity);
                    }
                    
                    // commit changes to the identity store to update the group
                    CFErrorRef commitError = NULL;
                    if (CSIdentityCommit(csGroupIdentity, NULL, &commitError)) {
                        
                        // re-check the group membership. this seems to update some caches or so. without this re-checking
                        // sometimes the system does not recognize the changes of the group membership instantly.
                        [MTIdentity getGroupMembershipForUser:userName groupID:groupID error:nil];
                        
                    } else {
                        
                        error = [NSError errorWithDomain:@"corp.sap.privileges" code:100 userInfo:[(__bridge NSError*)commitError userInfo]];
                    }
                    
                }  else {
                    
                    NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:@"Missing group identity", NSLocalizedDescriptionKey, nil];
                    error = [NSError errorWithDomain:@"corp.sap.privileges" code:100 userInfo:errorDetail];
                    
                }
                
            }  else {
                
                NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:@"Missing user identity", NSLocalizedDescriptionKey, nil];
                error = [NSError errorWithDomain:@"corp.sap.privileges" code:100 userInfo:errorDetail];
                
            }
            
        }  else {
            
            NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:@"User name is missing", NSLocalizedDescriptionKey, nil];
            error = [NSError errorWithDomain:@"corp.sap.privileges" code:100 userInfo:errorDetail];
            
        }
    }
    
    reply(error);
}

- (void)quitHelperTool
{
    _shouldTerminate = YES;
}

@end
