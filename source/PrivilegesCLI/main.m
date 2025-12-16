/*
    main.m
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

#import <Foundation/Foundation.h>
#import "MTPrivileges.h"
#import "MTProcessInfo.h"
#import "MTSystemExtension.h"
#import "Constants.h"

@interface Main : NSObject
@property (nonatomic, strong, readwrite) MTSystemExtension *systemExtension;
@property (atomic, assign) BOOL shouldTerminate;
@end

@implementation Main

- (int)run
{
    __block int exitCode = 0;
    _shouldTerminate = YES;
    
    MTProcessInfo *appArguments = [[MTProcessInfo alloc] init];
    BOOL rootAllowed = ([appArguments systemExtension] || [appArguments showVersion]);
    
    // don't run this as root
    if (getuid() != 0 || rootAllowed) {
        
#pragma mark - Argument "--extension"
                
        if ([appArguments systemExtension]) {
            
            if (@available(macOS 13.0, *)) {
                
                NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppBundleIdentifier];
                MTExtensionRequestType requestType = [appArguments extensionRequestType];
                
                if (requestType != MTExtensionRequestTypeInvalid) {
                    
                    BOOL skipExecution = NO;
                    BOOL extensionIsManaged = [userDefaults objectIsForcedForKey:kMTDefaultsEnableSystemExtensionKey];
                    BOOL enableExtension = ([userDefaults objectIsForcedForKey:kMTDefaultsEnableSystemExtensionKey] && [userDefaults boolForKey:kMTDefaultsEnableSystemExtensionKey]);
                    
                    // if we were called with the "managed" argument, we check
                    // if the setting is managed and adjust the type accordingly
                    if (requestType == MTExtensionRequestTypeManaged) {
                        
                        if (extensionIsManaged) {
                            
                            requestType = (enableExtension) ? MTExtensionRequestTypeEnable : MTExtensionRequestTypeDisable;
                            
                        } else {
                            
                            [self writeConsole:@"System extension is not managed"];
                            skipExecution = YES;
                        }
                        
                    } else if (extensionIsManaged) {
                        
                        if ((requestType == MTExtensionRequestTypeEnable && !enableExtension) ||
                            (requestType == MTExtensionRequestTypeDisable && enableExtension)) {
                            
                            [self writeConsole:[NSString stringWithFormat:@"System extension is managed and cannot be %@", (requestType == MTExtensionRequestTypeEnable) ? kMTExtensionStatusEnabled : kMTExtensionStatusDisabled]];
                            
                            exitCode = 7;
                            skipExecution = YES;
                        }
                    }
                    
                    if (!skipExecution) {
                        
                        _shouldTerminate = NO;
                        
                        // get the current status of the extension
                        _systemExtension = [[MTSystemExtension alloc] init];
                        [_systemExtension statusWithReply:^(NSString *extensionStatus) {
                                
                            if (requestType == MTExtensionRequestTypeStatus) {
                                
                                NSString *statusText = [NSString stringWithFormat:@"System extension is %@", extensionStatus];
                                
                                if (extensionIsManaged) {
                                    
                                    if ((enableExtension && [extensionStatus isEqualToString:kMTExtensionStatusEnabled]) ||
                                        (!enableExtension && [extensionStatus isEqualToString:kMTExtensionStatusDisabled])) {
                                        
                                        statusText = [statusText stringByAppendingString:@" (managed)"];
                                        
                                    } else {
                                        
                                        statusText = [statusText stringByAppendingFormat:@" (managed, expected: %@)", (enableExtension) ? kMTExtensionStatusEnabled : kMTExtensionStatusDisabled];
                                    }
                                }
                                
                                [self writeConsole:statusText];
                                dispatch_async(dispatch_get_main_queue(), ^{ self->_shouldTerminate = YES; });
                                
                            } else if ((requestType == MTExtensionRequestTypeEnable && [extensionStatus isEqualToString:kMTExtensionStatusEnabled]) ||
                                       (requestType == MTExtensionRequestTypeDisable && [extensionStatus isEqualToString:kMTExtensionStatusDisabled])) {
                                
                                [self writeConsole:[NSString stringWithFormat:@"System extension is already %@", extensionStatus]];
                                dispatch_async(dispatch_get_main_queue(), ^{ self->_shouldTerminate = YES; });
                                
                            } else {
                                
                                switch (requestType) {
                                        
                                    case MTExtensionRequestTypeEnable: {
                                                                                
                                        [self->_systemExtension enableWithCompletionHandler:^(BOOL success, NSError *error) {
                                            
                                            if (success) {
                                                
                                                [self writeConsole:@"System extension enabled"];
                                                                                                        
                                                [self->_systemExtension statusWithReply:^(NSString *status) {
                                                    
                                                    if ([status rangeOfString:@"waiting"].location != NSNotFound) {
                                                        [self writeConsole:@"\nPlease grant the Privileges system extension\nfull disk access, otherwise it will not work."];
                                                    }
                                                    
                                                    dispatch_async(dispatch_get_main_queue(), ^{ self->_shouldTerminate = YES; });
                                                }];
                                                
                                            } else {
                                                
                                                [self writeConsole:[NSString stringWithFormat:@"Failed to enable system extension: %@", error]];
                                                exitCode = 6;
                                                
                                                dispatch_async(dispatch_get_main_queue(), ^{ self->_shouldTerminate = YES; });
                                            }
                                        }];
                                        
                                        break;
                                    }
                                        
                                    case MTExtensionRequestTypeDisable: {
                                                                                    
                                        [self->_systemExtension disableWithCompletionHandler:^(BOOL success, NSError *error) {
                                            
                                            if (success) {
                                                
                                                [self writeConsole:@"System extension disabled"];
                                                
                                            } else {
                                                
                                                [self writeConsole:[NSString stringWithFormat:@"Failed to disable system extension: %@", error]];
                                                exitCode = 6;
                                            }
                                            
                                            dispatch_async(dispatch_get_main_queue(), ^{ self->_shouldTerminate = YES; });
                                        }];
                                        
                                        break;
                                    }
                                        
                                    case MTExtensionRequestTypeSuspend: {
                                                                                    
                                        [self->_systemExtension suspendWithCompletionHandler:^(BOOL success, NSError *error) {
                                            
                                            if (!success) {
                                                
                                                [self writeConsole:@"Invalid argument!"];
                                                exitCode = 5;
                                            }
                                            
                                            dispatch_async(dispatch_get_main_queue(), ^{ self->_shouldTerminate = YES; });
                                        }];
                                        
                                        break;
                                    }
                                        
                                    default:
                                                                                    
                                        [self writeConsole:@"Invalid argument!"];
                                        exitCode = 5;
                                        
                                        dispatch_async(dispatch_get_main_queue(), ^{ self->_shouldTerminate = YES; });
                                }
                            }
                        }];
                    }
                    
                } else {
                    
                    [self writeConsole:@"Invalid argument!"];
                    exitCode = 5;
                }
                
            } else {
                
                [self printUsage];
            }
            
#pragma mark - Argument "--status"
            
        } else if ([appArguments showStatus]) {
            
            MTPrivileges *privilegesApp = [[MTPrivileges alloc] init];

            if (!privilegesApp) {
                        
                [self writeConsole:@"Failed to get current console user. Unable to continue"];
                exitCode = 5;
                                    
            } else {
                
                if ([[privilegesApp currentUser] hasAdminPrivileges]) {
                    
                    [self writeConsole:[NSString stringWithFormat:@"User %@ has administrator privileges", [[privilegesApp currentUser] userName]]];
                    
                    if ([privilegesApp expirationInterval] > 0) {
                        
                        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                        
                        [[privilegesApp currentUser] privilegesExpirationWithReply:^(NSDate *expire, NSUInteger remaining) {
                            
                            if (remaining > 0) {
                                
                                [self writeConsole:[NSString stringWithFormat:@"Administrator privileges expire in %@", [MTPrivileges stringForDuration:remaining
                                                                                                                                              localized:NO
                                                                                                                                           naturalScale:NO
                                                                                                                        ]
                                                   ]
                                ];
                            }
                            
                            dispatch_semaphore_signal(semaphore);
                        }];
                        
                        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                    }
                    
                } else {
                    
                    [self writeConsole:[NSString stringWithFormat:@"User %@ has standard user privileges", [[privilegesApp currentUser] userName]]];
                }
            }

#pragma mark - Argument "--version"
        
        } else if ([appArguments showVersion]) {
            
            NSString *versionString = @"unknown version";
            NSURL *launchURL = [appArguments launchURL];
            
            if (launchURL) {
                
                NSDictionary *infoDict = CFBridgingRelease(CFBundleCopyInfoDictionaryForURL((CFURLRef)launchURL));
                NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"];
                NSString *appBuild = [infoDict objectForKey:@"CFBundleVersion"];
                
                if (appVersion && appBuild) {
                    
                    versionString = [NSString stringWithFormat:@"%@ (%@)", appVersion, appBuild];
                }
            }
            
            [self writeConsole:[NSString stringWithFormat:@"PrivilegesCLI %@", versionString]];

#pragma mark - Argument "--add" or "--remove"
    
        } else if ([appArguments requestPrivileges] || [appArguments revertPrivileges]) {
            
            MTPrivileges *privilegesApp = [[MTPrivileges alloc] init];

            if (!privilegesApp) {
                
                [self writeConsole:@"Failed to get current console user. Unable to continue"];
                exitCode = 5;
                            
            } else {
            
                if ([[privilegesApp currentUser] useIsRestricted]) {
                    
                    [self writeConsole:@"You cannot use this application to change your privileges because your administrator has restricted the use of this application"];
                    
                    if ([[privilegesApp enforcedPrivilegeType] isEqualToString:kMTEnforcedPrivilegeTypeAdmin]) {
                        [self writeConsole:[NSString stringWithFormat:@"Administrator privileges have been assigned by your administrator"]];
                    } else if ([[privilegesApp enforcedPrivilegeType] isEqualToString:kMTEnforcedPrivilegeTypeUser]) {
                        [self writeConsole:[NSString stringWithFormat:@"Standard user privileges have been assigned by your administrator"]];
                    }
                    
                } else {
                    
                    BOOL hasAdminPrivileges = [[privilegesApp currentUser] hasAdminPrivileges];
                    BOOL requestAdminPrivileges = [appArguments requestPrivileges];
                    BOOL renewAdminPrivileges = (requestAdminPrivileges && hasAdminPrivileges && [privilegesApp privilegeRenewalAllowed] && [privilegesApp expirationInterval] > 0);
                    
                    if (requestAdminPrivileges == hasAdminPrivileges && !renewAdminPrivileges) {
                        
                        [self writeConsole:[NSString stringWithFormat:@"User %@ already has the requested privileges. Nothing to do.", [[privilegesApp currentUser] userName]]];
                        
                    } else {
                        
                        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                        
                        if (requestAdminPrivileges) {
                            
#pragma mark - Reason
                            NSString *privilegesReason = nil;
                            
                            if ([privilegesApp reasonRequired] && !renewAdminPrivileges) {
                                
                                NSInteger minReasonLength = [privilegesApp reasonMinLength];
                                NSInteger maxReasonLength = [privilegesApp reasonMaxLength];
                                NSString *reasonText = [appArguments requestReason];
                                
                                if (reasonText) {
                                    
                                    if ([privilegesApp checkReasonString:[privilegesApp cleanedReasonStringWithString:reasonText]]) {
                                        
                                        privilegesReason = reasonText;
                                        
                                    } else {
                                        
                                        [self writeConsole:@"The provided reason does not match the requirements!"];
                                        exitCode = 4;
                                    }
                                    
                                } else {
                                    
                                    while (!privilegesReason) {
                                        
                                        NSMutableData *zeroedData = [NSMutableData dataWithCapacity:maxReasonLength];
                                        const void *bufferBytes = [zeroedData bytes];
                                        char *buffer = (char*)bufferBytes;
                                        char *reason = NULL;
                                        
                                        printf("Please enter the reason you need administrator privileges (at least %ld characters): ", (long)minReasonLength);
                                        reason = fgets(buffer, (int)maxReasonLength, stdin);
                                        
                                        reasonText = [NSString stringWithUTF8String:reason];
                                        
                                        if ([privilegesApp checkReasonString:[privilegesApp cleanedReasonStringWithString:reasonText]]) {
                                            
                                            privilegesReason = reasonText;
                                            
                                        } else {
                                            
                                            [self writeConsole:@"The provided reason does not match the requirements!"];
                                        }
                                    }
                                }
                            }
                            
#pragma mark - Authentication
                            
                            if (([privilegesApp authenticationRequired] && !renewAdminPrivileges) ||
                                ([privilegesApp authenticationRequired] && renewAdminPrivileges && [privilegesApp renewalFollowsAuthSetting])) {
                                
                                __block BOOL authSuccess = NO;
                                __block BOOL biometricsRequired = NO;
                                
                                if ([privilegesApp biometricAuthenticationRequired] && ![privilegesApp allowCLIBiometricAuthentication]) {
                                    
                                    [self writeConsole:@"Biometric authentication is required but has not been enabled for PrivilegesCLI"];
                                    exitCode = 1;
                                    
                                } else {
                                    
                                    int i = 3;
                                    
                                    while (i > 0 && !authSuccess && !biometricsRequired) {
                                        
                                        if ([privilegesApp allowCLIBiometricAuthentication]) {
                                            
                                            [[privilegesApp currentUser] authenticateWithCompletionHandler:^(BOOL success, NSError *error) {
                                                
                                                authSuccess = success;
                                                biometricsRequired = (error && ([error code] == 130 || [error code] == 140));
                                                dispatch_semaphore_signal(semaphore);
                                            }];
                                            
                                            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                                        }
                                        
                                        if (!authSuccess) {
                                            
                                            i--;
                                            
                                            if (![privilegesApp biometricAuthenticationRequired]) {
                                                
                                                char *password = getpass("Please enter your account password: ");
                                                NSString *userPassword = [NSString stringWithUTF8String:password];
                                                
                                                if ([userPassword length] > 0 && [MTIdentity verifyPassword:userPassword forUser:[[privilegesApp currentUser] userName]]) {
                                                    
                                                    authSuccess = YES;
                                                    
                                                } else if (i > 0) {
                                                    
                                                    [self writeConsole:@"Sorry, try again"];
                                                }
                                            }
                                        }
                                    }
                                    
                                    if (!authSuccess) {
                                        
                                        if (biometricsRequired) {
                                            [self writeConsole:@"Biometric authentication required!"];
                                        } else {
                                            [self writeConsole:@"3 incorrect password attempts"];
                                        }
                                        
                                        exitCode = 1;
                                    }
                                }
                            }
                            
                            if (exitCode == 0) {
                                
                                if (renewAdminPrivileges) {
                                    
                                    [[privilegesApp currentUser] renewAdminPrivilegesWithCompletionHandler:^(BOOL success) {
                                        
                                        if (success) {
                                            
                                            [self writeConsole:[NSString stringWithFormat:@"Administrator privileges have been renewed and will expire in %@", [MTPrivileges stringForDuration:[privilegesApp expirationInterval]
                                                                                                                                                                                     localized:NO
                                                                                                                                                                                  naturalScale:NO
                                                                                                                                                               ]
                                                               ]
                                            ];
                                            
                                        } else {
                                            
                                            [self writeConsole:[NSString stringWithFormat:@"Failed to renew privileges for user %@", [[privilegesApp currentUser] userName]]];
                                            exitCode = 2;
                                        }
                                        
                                        dispatch_semaphore_signal(semaphore);
                                    }];
                                    
                                } else {
                                    
                                    [[privilegesApp currentUser] requestAdminPrivilegesWithReason:privilegesReason
                                                                                completionHandler:^(BOOL success) {
                                        
                                        if (success) {
                                            
                                            [self writeConsole:[NSString stringWithFormat:@"User %@ now has administrator privileges", [[privilegesApp currentUser] userName]]];
                                            
                                            if ([privilegesApp expirationInterval] > 0) {
                                                
                                                [self writeConsole:[NSString stringWithFormat:@"Administrator privileges expire in %@", [MTPrivileges stringForDuration:[privilegesApp expirationInterval]
                                                                                                                                                              localized:NO
                                                                                                                                                           naturalScale:NO
                                                                                                                                        ]
                                                                   ]
                                                ];
                                            }
                                            
                                        } else {
                                            
                                            [self writeConsole:[NSString stringWithFormat:@"Failed to change privileges for user %@", [[privilegesApp currentUser] userName]]];
                                            exitCode = 2;
                                        }
                                        
                                        dispatch_semaphore_signal(semaphore);
                                    }];
                                }
                                
                                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                            }
                            
                        } else {
                            
                            [[privilegesApp currentUser] revokeAdminPrivilegesWithCompletionHandler:^(BOOL success) {
                                
                                if (success) {
                                    [self writeConsole:[NSString stringWithFormat:@"User %@ now has standard user privileges", [[privilegesApp currentUser] userName]]];
                                } else {
                                    [self writeConsole:[NSString stringWithFormat:@"Failed to change privileges for user %@", [[privilegesApp currentUser] userName]]];
                                    exitCode = 2;
                                }
                                
                                dispatch_semaphore_signal(semaphore);
                            }];
                            
                            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                        }
                    }
                }
            }
            
#pragma mark - Other or no argument
            
        } else {
            
            // display usage info and exit
            [self printUsage];
        }
        
    } else {
        
        [self writeConsole:@"You cannot run this application as root!"];
        exitCode = 3;
    }
        
    // run until _shouldTerminate is true
    while (!_shouldTerminate && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    
    return exitCode;
}

- (void)writeConsole:(NSString*)consoleMessage
{
    fprintf(stderr, "%s\n", [consoleMessage UTF8String]);
}

- (void)printUsage
{
    fprintf(stderr, "\nUsage: PrivilegesCLI <arg>\n\n");
    fprintf(stderr, "  -a [-n text],                Adds the current user to the admin group. A reason\n");
    fprintf(stderr, "  --add [--reason text]        for requesting administrator privileges may also be\n");
    fprintf(stderr, "                               specified. This is optional. If a reason is required\n");
    fprintf(stderr, "                               but not specified, the tool will prompt for a reason.\n\n");
    fprintf(stderr, "  -r, --remove                 Removes the current user from the admin group.\n\n");
    fprintf(stderr, "  -s, --status                 Displays the current user's privileges.\n\n");
    
    if (@available(macOS 13.0, *)) {
        
        fprintf(stderr, "  -e, --extension on | off     Enables or disables the Privileges system extension.\n");
        fprintf(stderr, "                               Once enabled, it prevents Privileges from being renamed,\n");
        fprintf(stderr, "                               copied, or deleted. It also prevents the unloading of\n");
        fprintf(stderr, "                               the Privileges launchd plists.\n\n");
        fprintf(stderr, "                  status       Displays the current status of the system extension.\n\n");
    }
    
    fprintf(stderr, "  -v, --version                Displays version information.\n\n");
}

@end

int main(int argc, const char * argv[])
{
#pragma unused(argc)
#pragma unused(argv)
    
    int exitCode = 0;
        
    @autoreleasepool {
            
        Main *m = [[Main alloc] init];
        exitCode = [m run];
    }
    
    return exitCode;
}
