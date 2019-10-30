/*
 main.m
 Copyright 2016-2019 SAP SE
 
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
#import "MTAuthCommon.h"
#import "PrivilegesHelper.h"
#import <Foundation/Foundation.h>

@interface Main : NSObject
@property (assign) AuthorizationRef authRef;
@property (assign) NSPort *receiveStopMessagePort;
@property (nonatomic, assign) NSInteger helperCheckFailed;
@property (atomic, copy, readwrite) NSData *authorization;
@property (atomic, strong, readwrite) NSXPCConnection *helperToolConnection;
@property (nonatomic, assign) BOOL grantAdminRights;
@property (nonatomic, assign) BOOL shouldTerminate;
@end

@implementation Main

- (void)run
{
    // don't run this as root
    if (getuid() != 0) {
        
        NSArray *theArguments = nil;
        NSString *enforcedPrivileges = nil;
        
        // check if we're managed
        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"corp.sap.privileges"];
        
        if ([userDefaults objectIsForcedForKey:@"EnforcePrivileges"]) {
            enforcedPrivileges = [userDefaults objectForKey:@"EnforcePrivileges"];
        }
        
        if ([enforcedPrivileges isEqualToString:@"none"]) {

            fprintf(stderr, "You cannot use this app to change your privileges!\n");
            
        } else {
            
            if ([enforcedPrivileges isEqualToString:@"admin"] || [enforcedPrivileges isEqualToString:@"user"]) {
                theArguments = [NSArray arrayWithObjects:
                                [[NSProcessInfo processInfo] processName],
                                [NSString stringWithFormat:@"%@", ([enforcedPrivileges isEqualToString:@"admin"]) ? @"--add" : @"--remove"],
                                nil
                                ];
            
                fprintf(stderr, "Arguments are ignored because %s rights have been assigned by an administrator\n", ([enforcedPrivileges isEqualToString:@"admin"]) ? "admin" : "standard user");
            
            } else {
                theArguments = [NSArray arrayWithArray:[[NSProcessInfo processInfo] arguments]];
            }
            
            NSString *lastArgument = [theArguments lastObject];
            
            if ([theArguments count] == 2 && ([lastArgument isEqualToString:@"--remove"] || [lastArgument isEqualToString:@"--add"])) {
                
                _grantAdminRights = ([lastArgument isEqualToString:@"--add"]) ? YES : NO;
                
                // create authorization reference
                _authorization = [MTAuthCommon createAuthorizationUsingAuthorizationRef:&_authRef];
                
                if (!_authorization) {
                    
                    // display an error dialog and exit
                    fprintf(stderr, "Unable to create authorization reference!\n");
                    
                } else {
                    
                    // check for the helper
                    [self checkForHelper];
                    
                    // wait until "shouldTerminate" is true
                    _receiveStopMessagePort = [NSPort port];
                    [_receiveStopMessagePort setDelegate:(id)self];
                    
                    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
                    [runLoop addPort:_receiveStopMessagePort forMode:NSDefaultRunLoopMode];
                    while (!_shouldTerminate && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
                }
                
                // tell the helper to quit
                [MTAuthCommon connectToHelperToolUsingConnection:&_helperToolConnection andExecuteCommandBlock:^(void) { [[self->_helperToolConnection remoteObjectProxy] quitHelperTool]; }];
                
            } else {
                
                // display usage info and exit
                [self printUsage];
            }
        }
        
    } else {
        
        // display an error dialog and exit
        fprintf(stderr, "You cannot run this as root!\n");
    }
     
}

- (void)fireTerminateMessage
{
    // Send an empty message to the receiveStopMessagePort; This is a
    // special port just for getting "terminate" requests
    NSPortMessage* emptyQuitMessage = [[NSPortMessage alloc]
                                       initWithSendPort:_receiveStopMessagePort
                                       receivePort:_receiveStopMessagePort
                                       components:[NSArray arrayWithObject:[NSData data]]];
    [emptyQuitMessage sendBeforeDate:[NSDate distantFuture]];
}

- (void)handlePortMessage:(NSPortMessage*)portMessage
{
#pragma unused(portMessage)
    // The message is unimportant; the only message that this port receives is the request to stop running.
    // Sending a message through a port ensures that the run loop will get a chance
    //  to test the isRunning flag and terminate the run loop.
    _shouldTerminate = YES;
}

- (void) printUsage
{
    fprintf(stderr, "\nUsage: PrivilegesCLI <arg>\n\n");
    fprintf(stderr, "Arguments:   --add        Adds the current user to the admin group\n");
    fprintf(stderr, "             --remove     Remove the current user from the admin group\n\n");
    
    [self fireTerminateMessage];
}

- (void)changeAdminGroup:(NSString*)userName group:(uint)groupID remove:(BOOL)remove
{
    [MTAuthCommon connectToHelperToolUsingConnection:&_helperToolConnection
                              andExecuteCommandBlock:^(void) {
                                  
                                  [[self->_helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
                                      
                                      fprintf(stderr, "Unable to connect to helper tool!\n");
                                      [self fireTerminateMessage];
                                      
                                  }] changeGroupMembershipForUser:userName group:groupID remove:remove authorization:self->_authorization withReply:^(NSError *error) {
                                      
                                      if (error != nil) {
                                          fprintf(stderr, "Unable to change privileges!\n");
                                          
                                      } else {
                                          
                                          if (remove) {
                                              fprintf(stderr, "User %s has now standard user rights\n", [userName UTF8String]);
                                              NSLog(@"SAPCorp: User %@ has now standard user rights", userName);
                                          } else {
                                              fprintf(stderr, "User %s has now admin rights\n", [userName UTF8String]);
                                              NSLog(@"SAPCorp: User %@ has now admin rights", userName);
                                          }
                                          
                                          // send a notification to update the Dock tile
                                          [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"corp.sap.PrivilegesChanged"
                                                                                                        object:userName
                                                                                                       userInfo:nil
                                                                                                        options:NSNotificationDeliverImmediately | NSNotificationPostToAllSessions
                                           ];
                                      }
                                      
                                      [self fireTerminateMessage];
                                      
                                  }];
                                  
                              }];
}

- (void)checkForHelper
{
    [MTAuthCommon connectToHelperToolUsingConnection:&_helperToolConnection
                              andExecuteCommandBlock:^(void) {
                                  
                                  [[self->_helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
                                      [self performSelectorOnMainThread:@selector(helperCheckFailed:) withObject:proxyError waitUntilDone:NO];
                                      
                                  }] getVersionWithReply:^(NSString *helperVersion) {
                                      if (helperVersion) {
                                          [self performSelectorOnMainThread:@selector(helperCheckSuccessful:) withObject:helperVersion waitUntilDone:NO];
                                          
                                      } else {
                                          NSString *errorMsg = @"Unable to determine helper version";
                                          [self performSelectorOnMainThread:@selector(helperCheckFailed:) withObject:errorMsg waitUntilDone:NO];
                                      }
                                  }];
                                  
                              }];
}

- (void)helperCheckFailed:(NSString*)errorMessage
{
    fprintf(stderr, "Helper tool is not running!\n");
    [self fireTerminateMessage];
}

- (void)helperCheckSuccessful:(NSString*)helperVersion
{
    NSError *userError = nil;
    NSString *userName = NSUserName();
    int groupID = [MTIdentity gidFromGroupName:ADMIN_GROUP_NAME];
    
    if (groupID == -1) {
        
        fprintf(stderr, "Unable to get id of the admin group!\n");
        [self fireTerminateMessage];
        
    } else {
        
        BOOL isAdmin = [MTIdentity getGroupMembershipForUser:userName groupID:groupID error:&userError];
        
        if (userError != nil) {
            
            fprintf(stderr, "Unable to get group membership for user %s!\n", [userName UTF8String]);
            
        } else {
            
            if (isAdmin && !_grantAdminRights) {
                
                // remove the admin privileges
                [self changeAdminGroup:userName group:groupID remove:YES];
                
            } else if (!isAdmin && _grantAdminRights) {
                
                // grant admin privileges
                [self changeAdminGroup:userName group:groupID remove:NO];
                
            } else {
                
                fprintf(stderr, "User %s already has the requested permissions. Nothing to do.\n", [userName UTF8String]);
                [self fireTerminateMessage];
            }
            
        }
    }
}

@end

int main(int argc, const char * argv[])
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

