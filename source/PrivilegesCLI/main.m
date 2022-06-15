/*
 main.m
 Copyright 2016-2022 SAP SE
 
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

#import "MTIdentity.h"
#import "PrivilegesHelper.h"
#import "MTAuthCommon.h"
#import "Constants.h"
#import <Foundation/Foundation.h>


@interface Main : NSObject
@property (assign) AuthorizationRef authRef;
@property (atomic, copy, readwrite) NSData *authorization;
@property (atomic, strong, readwrite) NSXPCConnection *helperToolConnection;
@property (atomic, strong, readwrite) NSString *currentUser;
@property (atomic, strong, readwrite) NSString *adminReason;
@property (atomic, assign) BOOL grantAdminRights;
@property (atomic, assign) BOOL shouldTerminate;
@end

@implementation Main

- (void)run
{
    // don't run this as root
    if (getuid() != 0) {
        
        // get the name of the current user
        _currentUser = NSUserName();
        
        // check if we're managed
        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"corp.sap.privileges"];
        
        NSString *enforcedPrivileges = ([userDefaults objectIsForcedForKey:kMTDefaultsEnforcePrivileges]) ? [userDefaults objectForKey:kMTDefaultsEnforcePrivileges] : nil;
        NSString *limitToUser = ([userDefaults objectIsForcedForKey:kMTDefaultsLimitToUser]) ? [userDefaults objectForKey:kMTDefaultsLimitToUser] : nil;
        NSString *limitToGroup = ([userDefaults objectIsForcedForKey:kMTDefaultsLimitToGroup]) ? [userDefaults objectForKey:kMTDefaultsLimitToGroup] : nil;
        
        NSArray *theArguments = [NSArray arrayWithArray:[[NSProcessInfo processInfo] arguments]];
        NSString *lastArgument = [theArguments lastObject];
        
        if ([theArguments count] == 2 && ([lastArgument isEqualToString:@"--status"])) {
        
            if ([MTIdentity getGroupMembershipForUser:_currentUser groupID:kMTAdminGroupID error:nil]) {
                [self sendConsoleMessage:[NSString stringWithFormat:@"User %@ has admin rights", _currentUser]];
            } else {
                [self sendConsoleMessage:[NSString stringWithFormat:@"User %@ has standard user rights", _currentUser]];
            }
            
        } else {

            if ([enforcedPrivileges isEqualToString:@"admin"] || [enforcedPrivileges isEqualToString:@"user"]) {
                
                theArguments = [NSArray arrayWithObjects:[[NSProcessInfo processInfo] processName], ([enforcedPrivileges isEqualToString:@"admin"]) ? @"--add" : @"--remove", nil];
                lastArgument = [theArguments lastObject];
                [self sendConsoleMessage:[NSString stringWithFormat:@"Arguments are ignored because %@ rights have been assigned by an administrator", ([enforcedPrivileges isEqualToString:@"admin"]) ? @"admin" : @"standard user"]];
            }

            if ([theArguments count] == 2 && ([lastArgument isEqualToString:@"--remove"] || [lastArgument isEqualToString:@"--add"])) {
                
                if ([enforcedPrivileges isEqualToString:@"none"] || (!enforcedPrivileges &&
                    ((limitToUser && ![[limitToUser lowercaseString] isEqualToString:_currentUser]) ||
                    (!limitToUser && limitToGroup && ![MTIdentity getGroupMembershipForUser:_currentUser groupName:limitToGroup error:nil])))) {
                    
                    [self sendConsoleMessage:@"You cannot use this app to change your privileges because your administrator has restricted the use of this app."];
                    
                } else {
                
                    BOOL allowUsage = YES;
                    _grantAdminRights = ([lastArgument isEqualToString:@"--add"]) ? YES : NO;
                        
                    NSError *userError = nil;
                    BOOL isAdmin = [MTIdentity getGroupMembershipForUser:_currentUser groupID:kMTAdminGroupID error:&userError];
                           
                    if (userError) {
                        [self logError:nil withDescription:[NSString stringWithFormat:@"Unable to get group membership for user %@!", _currentUser] andTerminate:NO];
                        allowUsage = NO;
                           
                    } else {
                        
                        // check if we must change something
                        if ((isAdmin && _grantAdminRights) || (!isAdmin && !_grantAdminRights)) {
                            [self logError:nil withDescription:[NSString stringWithFormat:@"User %@ already has the requested privileges. Nothing to do.", _currentUser] andTerminate:NO];
                            allowUsage = NO;
                        
                        } else {
                            
                            // if admin rights are requested and authentication is required, we ask for the user's password ...
                            if (_grantAdminRights && ([userDefaults objectIsForcedForKey:kMTDefaultsAuthRequired] && [userDefaults boolForKey:kMTDefaultsAuthRequired])) {
                                
                                char *password = getpass("Please enter your account password: ");
                                NSString *userPassword = [NSString stringWithUTF8String:password];
                                
                                if ([userPassword length] <= 0 || ![MTIdentity verifyPassword:userPassword forUser:_currentUser]) {
                                    [self logError:nil withDescription:@"Incorrect password! Unable to change group membership." andTerminate:NO];
                                    allowUsage = NO;
                                }
                            }
                            
                            if (allowUsage && _grantAdminRights && ([userDefaults objectIsForcedForKey:kMTDefaultsRequireReason] && [userDefaults boolForKey:kMTDefaultsRequireReason])) {
                                
                                NSInteger minReasonLength = 0;
                                if ([userDefaults objectIsForcedForKey:kMTDefaultsReasonMinLength]) { minReasonLength = [userDefaults integerForKey:kMTDefaultsReasonMinLength]; }
                                if (minReasonLength <= 0) { minReasonLength = 10; }
                                
                                _adminReason = nil;
                                char reason[100] = {0};
                                printf("Please enter the reason for needing admin rights (at least %ld characters): ", (long)minReasonLength);
                                scanf("%[^\n]s", reason);
                                NSString *reasonText = [NSString stringWithUTF8String:reason];
                                
                                if ([reasonText length] < minReasonLength) {
                                    [self logError:nil withDescription:@"The provided reason does not match the requirements!" andTerminate:NO];
                                    allowUsage = NO;
                                } else {
                                    _adminReason = reasonText;
                                }
                            }

                        }
                    }
                    
                    if (allowUsage) {
                                            
                        // create authorization reference
                        AuthorizationExternalForm extForm;
                        OSStatus err = AuthorizationCreate(NULL, NULL, 0, &self->_authRef);
                        
                        if (err == errAuthorizationSuccess) {
                            err = AuthorizationMakeExternalForm(self->_authRef, &extForm);
                        }
                        
                        if (err == errAuthorizationSuccess) {
                            self.authorization = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
                            if (self->_authRef) { [MTAuthCommon setupAuthorizationRights:self->_authRef]; }
                        }
                            
                        if (!_authorization) {
                                
                            // display an error dialog and exit
                            [self logError:nil withDescription:@"Unable to create authorization reference!" andTerminate:NO];
                            
                        } else {

                            // check for the helper
                            [self checkForHelper];
                            
                            // run until _shouldTerminate is true
                            while (!_shouldTerminate && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
                        }
                        
                        // tell the helper to quit
                        [self connectAndExecuteCommandBlock:^(NSError *connectError) {
                            
                            if (connectError) {
                                [self logError:connectError withDescription:@"Unable to create XPC connection!" andTerminate:YES];
                                
                            } else {
                                [[self->_helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
                                    [self logError:proxyError withDescription:@"Failed to execute XPC method!" andTerminate:YES];
                                }] quitHelperTool];
                            }
                        }];
                    }
                }
            
            } else {
                
                // display usage info and exit
                [self printUsage];
            }
        }
        
    } else {
        
        // display an error dialog and exit
        [self logError:nil withDescription:@"You cannot run this as root!" andTerminate:NO];
    }
     
}

- (void)terminateRunLoop
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_shouldTerminate = YES;
    });
}

- (void) printUsage
{
    fprintf(stderr, "\nUsage: PrivilegesCLI <arg>\n\n");
    fprintf(stderr, "Arguments:   --add        Adds the current user to the admin group\n");
    fprintf(stderr, "             --remove     Removes the current user from the admin group\n");
    fprintf(stderr, "             --status     Displays the current user's privileges\n\n");
    
    [self terminateRunLoop];
}

- (void)changeAdminGroup:(NSString*)userName remove:(BOOL)remove
{
    [self connectAndExecuteCommandBlock:^(NSError *connectError) {
        
        if (connectError) {
            [self logError:connectError withDescription:@"Unable to create XPC connection!" andTerminate:YES];
            
        } else {
        
            [[self->_helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
                [self logError:proxyError withDescription:@"Failed to execute XPC method!" andTerminate:YES];
            }] changeAdminRightsForUser:userName
                                 remove:remove
                                 reason:self->_adminReason
                          authorization:self->_authorization
                              withReply:^(NSError *error) {
                
                if (error) {
                    [self sendConsoleMessage:@"Unable to change privileges!"];
                    
                } else {
                    
                    NSString *logMessage = [NSString stringWithFormat:@"User %@ has now %@ rights", userName, (remove) ? @"standard user" : @"admin"];
                    [self sendConsoleMessage:logMessage];
                    
                    // send a notification to update the Dock tile
                    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"corp.sap.PrivilegesChanged"
                                                                                  object:userName
                                                                                 userInfo:nil
                                                                                  options:NSNotificationDeliverImmediately | NSNotificationPostToAllSessions
                     ];
                }
                
                [self terminateRunLoop];
                
            }];
        }
        
    }];
}

- (void)checkForHelper
{
    [self connectAndExecuteCommandBlock:^(NSError *connectError) {
        
        if (connectError) {
            [self logError:connectError withDescription:@"Unable to create XPC connection!" andTerminate:YES];
            
        } else {

            [[self->_helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
                [self logError:proxyError withDescription:@"Failed to execute XPC method!" andTerminate:YES];
            }] helperVersionWithReply:^(NSString *helperVersion) {
                
                if (helperVersion) {
                    
                    // set the required helper version (this must match the app version)
                    NSString *mainbundlePath = [[NSBundle bundleForClass:[self class]] bundlePath];
                    NSBundle *mainBundle = [NSBundle bundleWithPath:mainbundlePath];
                    NSString *requiredVersion = [[mainBundle infoDictionary] objectForKey:@"CFBundleShortVersionString"];
                    
                    if ([helperVersion isEqualToString:requiredVersion]) {
                        
                        // everything seems to be good, so set the privileges
                        [self performSelectorOnMainThread:@selector(helperCheckSuccessful:) withObject:nil waitUntilDone:NO];
                        
                    } else {
                        
                        [self logError:nil  withDescription:[NSString stringWithFormat:@"Helper version mismatch (is %@, should be %@)", helperVersion, requiredVersion] andTerminate:YES];
                    }
                    
                } else {
                    [self logError:nil  withDescription:@"Helper tool is not running!" andTerminate:YES];
                }
            }];
        }
    }];
}

- (void)logError:(NSError*)error withDescription:(NSString*)errorString andTerminate:(BOOL)terminate
{
    errorString = ([errorString length] > 0) ? errorString : @"An unknown error occurred!";
    
    if (error) {
        [self sendConsoleMessage:[NSString stringWithFormat:@"%@: %@ (%d)", errorString, [error domain], (int)[error code]]];
    }
    
    [self sendConsoleMessage:errorString];
    
    if (terminate) { [self terminateRunLoop]; }
}

- (void)sendConsoleMessage:(NSString*)consoleMessage
{
    fprintf(stderr, "%s\n", [consoleMessage UTF8String]);
}

- (void)helperCheckSuccessful:(NSString*)helperVersion
{
    [self changeAdminGroup:_currentUser remove:!_grantAdminRights];
}

- (void)connectToHelperTool
    // Ensures that we're connected to our helper tool.
{
    assert([NSThread isMainThread]);
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
            // If the connection gets invalidated then, on the main thread, nil out our
            // reference to it.  This ensures that we attempt to rebuild it the next time around.
            self.helperToolConnection.invalidationHandler = nil;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.helperToolConnection = nil;
                [self logError:nil withDescription:@"Helper connection invalidated!" andTerminate:NO];
            }];
        };
        #pragma clang diagnostic pop
        [self.helperToolConnection resume];
    }
}

- (void)connectAndExecuteCommandBlock:(void(^)(NSError *))commandBlock
    // Connects to the helper tool and then executes the supplied command block on the
    // main thread, passing it an error indicating if the connection was successful.
{
    assert([NSThread isMainThread]);
    
    // Ensure that there's a helper tool connection in place.
    
    [self connectToHelperTool];

    // Run the command block.  Note that we never error in this case because, if there is
    // an error connecting to the helper tool, it will be delivered to the error handler
    // passed to -remoteObjectProxyWithErrorHandler:.  However, I maintain the possibility
    // of an error here to allow for future expansion.

    commandBlock(nil);
}

@end

int main(int argc, const char *argv[])
{
#pragma unused(argc)
#pragma unused(argv)
    int retVal;
    
    @autoreleasepool {
        Main *m = [[Main alloc] init];
        [m run];
        
        retVal = EXIT_SUCCESS;
    }
    
    return retVal;
}

