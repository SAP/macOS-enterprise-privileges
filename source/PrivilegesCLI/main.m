/*
    main.m
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

#import <Foundation/Foundation.h>
#import "MTPrivileges.h"
#import "MTAgentConnection.h"
#import "Constants.h"

@interface Main : NSObject
@property (atomic, assign) BOOL shouldTerminate;
@property (assign) BOOL authSuccess;
@end

@implementation Main

- (void)run
{
    // don't run this as root
    if (getuid() != 0) {
        
        NSArray *theArguments = [NSArray arrayWithArray:[[NSProcessInfo processInfo] arguments]];
        NSString *lastArgument = [theArguments lastObject];
        
        MTPrivileges *privilegesApp = [[MTPrivileges alloc] init];
        BOOL hasAdminPrivileges = [[privilegesApp currentUser] hasAdminPrivileges];

        if ([lastArgument isEqualToString:@"-s"] || [lastArgument isEqualToString:@"--status"]) {
        
            if (hasAdminPrivileges) {
                
                [self writeConsole:[NSString stringWithFormat:@"User %@ has administrator privileges.", [[privilegesApp currentUser] userName]]];
                
                if ([privilegesApp expirationInterval] > 0) {
                    
                    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                    
                    [[privilegesApp currentUser] privilegesExpirationWithReply:^(NSDate *expire, NSUInteger remaining) {
                        
                        if (remaining > 0) {
                            
                            [self writeConsole:[NSString stringWithFormat:@"Administrator privileges expire in %@.", [self stringForDuration:remaining]]];
                        }
                        
                        dispatch_semaphore_signal(semaphore);
                    }];
                    
                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                }
                
            } else {
                
                [self writeConsole:[NSString stringWithFormat:@"User %@ has standard user privileges.", [[privilegesApp currentUser] userName]]];
            }
            
        } else if ([lastArgument isEqualToString:@"-a"] || [lastArgument isEqualToString:@"--add"] ||
                   [lastArgument isEqualToString:@"-r"] || [lastArgument isEqualToString:@"--remove"]) {
            
            if ([privilegesApp useIsRestrictedForUser:[privilegesApp currentUser]]) {
                
                [self writeConsole:@"You cannot use this application to change your privileges because your administrator has restricted the use of this application."];
                
                if ([[privilegesApp enforcedPrivilegeType] isEqualToString:kMTEnforcedPrivilegeTypeAdmin]) {
                    [self writeConsole:[NSString stringWithFormat:@"Administrator privileges have been assigned by your administrator."]];
                } else if ([[privilegesApp enforcedPrivilegeType] isEqualToString:kMTEnforcedPrivilegeTypeUser]) {
                    [self writeConsole:[NSString stringWithFormat:@"Standard user privileges have been assigned by your administrator."]];
                }
                
            } else {
                
                BOOL requestAdminPrivileges = ([lastArgument isEqualToString:@"-a"] || [lastArgument isEqualToString:@"--add"]) ? YES : NO;
                
                if (requestAdminPrivileges == hasAdminPrivileges) {
                    
                    [self writeConsole:[NSString stringWithFormat:@"User %@ already has the requested privileges. Nothing to do.", [[privilegesApp currentUser] userName]]];
                    
                } else {
                    
                    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                                        
                    if (requestAdminPrivileges) {
                        
                        NSString *privilegesReason = nil;
                        __block BOOL authSuccess = YES;
                         
#pragma mark Reason
                        if ([privilegesApp reasonRequired]) {
                            
                            NSInteger minReasonLength = [privilegesApp reasonMinLength];
                            NSInteger maxReasonLength = [privilegesApp reasonMaxLength];
                            
                            while (!privilegesReason) {
                                
                                NSMutableData *zeroedData = [NSMutableData dataWithCapacity:maxReasonLength];
                                const void *bufferBytes = [zeroedData bytes];
                                char *buffer = (char*)bufferBytes;
                                char *reason = NULL;
                                
                                printf("Please enter the reason you need administrator privileges (at least %ld characters): ", (long)minReasonLength);
                                reason = fgets(buffer, (int)maxReasonLength, stdin);
                                
                                NSString *reasonText = [NSString stringWithUTF8String:reason];

                                if ([privilegesApp checkReasonString:[privilegesApp cleanedReasonStringWithString:reasonText]]) {
                                    privilegesReason = reasonText;
                                } else {
                                    [self writeConsole:@"The provided reason does not match the requirements!"];
                                }                                
                            }
                        }
                        
#pragma mark Authentication
                        
                        if ([privilegesApp authenticationRequired]) {
                            
                            authSuccess = NO;
                            
                            int i = 3;
                            
                            while (i > 0 && !authSuccess) {
                            
                                if ([privilegesApp allowCLIBiometricAuthentication]) {
                                    
                                    [[privilegesApp currentUser] authenticateWithCompletionHandler:^(BOOL success) {
                                        
                                        authSuccess = success;
                                        dispatch_semaphore_signal(semaphore);
                                    }];
                                    
                                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                                }
                            
                                if (!authSuccess) {
                                    
                                    char *password = getpass("Please enter your account password: ");
                                    NSString *userPassword = [NSString stringWithUTF8String:password];
                                    i--;
                                    
                                    if ([userPassword length] > 0 && [MTIdentity verifyPassword:userPassword forUser:[[privilegesApp currentUser] userName]]) {
                                        
                                        authSuccess = YES;
                                        
                                    } else if (i > 0) {
                                        
                                        [self writeConsole:@"Sorry, try again."];
                                    }
                                }
                            }
                            
                            if (!authSuccess) {
                                [self writeConsole:@"3 incorrect password attempts."];
                            }
                        }
                        
                        if (authSuccess) {
                            
                            [[privilegesApp currentUser] requestAdminPrivilegesWithReason:privilegesReason
                                                                        completionHandler:^(BOOL success) {
                                    
                                if (success) {
                                        
                                    [self writeConsole:[NSString stringWithFormat:@"User %@ now has administrator privileges.", [[privilegesApp currentUser] userName]]];
                                    
                                    if ([privilegesApp expirationInterval] > 0) {
                                        
                                        [self writeConsole:[NSString stringWithFormat:@"Administrator privileges expire in %@.", [self stringForDuration:[privilegesApp expirationInterval]]]];
                                    }
                                    
                                } else {
                                    
                                    [self writeConsole:[NSString stringWithFormat:@"Failed to change privileges for user %@.", [[privilegesApp currentUser] userName]]];
                                }
                                
                                dispatch_semaphore_signal(semaphore);
                            }];
                            
                            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                        }
                        
                    } else {
                                                
                        [[privilegesApp currentUser] revokeAdminPrivilegesWithCompletionHandler:^(BOOL success) {
                                                            
                            if (success) {
                                [self writeConsole:[NSString stringWithFormat:@"User %@ now has standard user privileges.", [[privilegesApp currentUser] userName]]];
                            } else {
                                [self writeConsole:[NSString stringWithFormat:@"Failed to change privileges for user %@", [[privilegesApp currentUser] userName]]];
                            }
                            
                            dispatch_semaphore_signal(semaphore);
                        }];
                        
                        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                    }
                }
            }
            
        } else {
            
            // display usage info and exit
            [self printUsage];
        }
        
        _shouldTerminate = YES;
        
    } else {
        
        [self writeConsole:@"You cannot run this application as root!"];
        _shouldTerminate = YES;
    }
    
    // run until _shouldTerminate is true
    while (!_shouldTerminate && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
}

- (void)writeConsole:(NSString*)consoleMessage
{
    fprintf(stderr, "%s\n", [consoleMessage UTF8String]);
}

- (NSString*)stringForDuration:(NSUInteger)duration
{
    NSMeasurement *durationMeasurement = [[NSMeasurement alloc] initWithDoubleValue:duration
                                                                               unit:[NSUnitDuration minutes]
    ];
    
    NSMeasurementFormatter *durationFormatter = [[NSMeasurementFormatter alloc] init];
    [[durationFormatter numberFormatter] setMaximumFractionDigits:0];
    [durationFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
    [durationFormatter setUnitStyle:NSFormattingUnitStyleLong];
    [durationFormatter setUnitOptions:NSMeasurementFormatterUnitOptionsProvidedUnit];
    
    return [durationFormatter stringFromMeasurement:durationMeasurement];
}

- (void) printUsage
{
    fprintf(stderr, "\nUsage: PrivilegesCLI <arg>\n\n");
    fprintf(stderr, "  -a, --add     Adds the current user to the admin group\n");
    fprintf(stderr, "  -r, --remove  Removes the current user from the admin group\n");
    fprintf(stderr, "  -s, --status  Displays the current user's privileges\n\n");
    
    _shouldTerminate = YES;
}

@end

int main(int argc, const char * argv[])
{
#pragma unused(argc)
#pragma unused(argv)
        
    @autoreleasepool {
            
        Main *m = [[Main alloc] init];
        [m run];
    }
    
    return EXIT_SUCCESS;
}
