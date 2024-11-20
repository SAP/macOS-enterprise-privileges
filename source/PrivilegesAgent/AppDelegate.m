/*
    AppDelegate.m
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

#import "AppDelegate.h"
#import "MTPrivileges.h"
#import "MTCodeSigning.h"
#import "MTDaemonConnection.h"
#import "MTSystemInfo.h"
#import "Constants.h"
#import "MTIdentity.h"
#import "PrivilegesAgentProtocol.h"
#import "MTSyslogMessage.h"
#import "MTWebhook.h"
#import "MTLocalNotification.h"
#import <os/log.h>

@interface AppDelegate ()
@property (nonatomic, strong, readwrite) MTPrivileges *privilegesApp;
@property (nonatomic, strong, readwrite) NSArray *keysToObserve;
@property (nonatomic, strong, readwrite) NSTimer *expirationTimer;
@property (nonatomic, strong, readwrite) NSDate *timerExpirationDate;
@property (nonatomic, strong, readwrite) NSUserDefaults *userDefaults;
@property (nonatomic, strong, readwrite) MTLocalNotification *userNotification;
@property (nonatomic, strong, readwrite) MTDaemonConnection *daemonConnection;
@property (atomic, strong, readwrite) NSXPCListener *listener;
@end

@interface ExtendedNSXPCConnection : NSXPCConnection
@property audit_token_t auditToken;
@end

OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification 
{
    os_log(OS_LOG_DEFAULT, "SAPCorp: Launched for user %{public}@", NSUserName());
    
    _listener = [[NSXPCListener alloc] initWithMachServiceName:kMTAgentMachServiceName];
    [_listener setDelegate:self];
    [_listener resume];
    
    _privilegesApp = [[MTPrivileges alloc] init];
    _daemonConnection = [[MTDaemonConnection alloc] init];
    _userDefaults = [NSUserDefaults standardUserDefaults];
    
    _userNotification = [[MTLocalNotification alloc] init];
    [_userNotification requestAuthorizationWithCompletionHandler:nil];
        
    BOOL removeSavedTimer = YES;
    
    // enforce fixed privileges
    if ([_privilegesApp useIsRestrictedForUser:[_privilegesApp currentUser]]) {
        
        [self enforceFixedPrivileges];
        
    // revoke administrator privileges if needed
    } else if ([_privilegesApp privilegesShouldBeRevokedAtLogin] && 
               [[_privilegesApp currentUser] hasAdminPrivileges] &&
               [[NSDate date] timeIntervalSinceDate:[MTSystemInfo sessionStartDate]] < kMTRevokeAtLoginThreshold) {
        
        [self revokeAdminRightsWithCompletionHandler:nil];
        
    // check for a running timer
    } else if ([_userDefaults objectForKey:kMTDefaultsAgentTimerExpirationKey]) {
        
        NSDate *previousDate = [_userDefaults objectForKey:kMTDefaultsAgentTimerExpirationKey];

        // is the timer still valid?
        if ([[NSDate date] compare:previousDate] == NSOrderedAscending) {
            
            removeSavedTimer = NO;
            NSUInteger remainingTime = ceil([previousDate timeIntervalSinceNow]/60);
            if (remainingTime > [_privilegesApp expirationInterval]) { remainingTime = [_privilegesApp expirationInterval]; }
            [self scheduleExpirationTimerWithInterval:remainingTime isExisitingTimer:YES];
            
        } else {
            
            [self revokeAdminRightsWithCompletionHandler:nil];
        }
        
    // if (for whatever reason) the user is an admin and
    // the expiration interval is geater than 0 but there's
    // no active timer, we schedule a new timer to make sure
    // the administrator privileges expire at some point.
    } else if ([[_privilegesApp currentUser] hasAdminPrivileges] && [_privilegesApp expirationInterval] > 0) {
        
        removeSavedTimer = NO;
        [self scheduleExpirationTimerWithInterval:[_privilegesApp expirationInterval] isExisitingTimer:NO];
    }
    
    if (removeSavedTimer) {
        [_userDefaults removeObjectForKey:kMTDefaultsAgentTimerExpirationKey];
    }
    
    // define the keys in our prefs we need to observe
    _keysToObserve = [[NSArray alloc] initWithObjects:
                      kMTDefaultsExpirationIntervalKey,
                      kMTDefaultsAutoExpirationIntervalMaxKey,
                      kMTDefaultsHideOtherWindowsKey,
                      kMTDefaultsRevokeAtLoginKey,
                      kMTDefaultsPostChangeExecutablePathKey,
                      kMTDefaultsEnforcePrivilegesKey,
                      kMTDefaultsLimitToUserKey,
                      kMTDefaultsLimitToGroupKey,
                      nil
    ];
            
    // Start observing our preferences to make sure we'll get notified as soon as someting changes
    // (e.g. a configuration profile has been installed).
    for (NSString *aKey in _keysToObserve) {
        
        [[_privilegesApp userDefaults] addObserver:self
                                        forKeyPath:aKey
                                           options:NSKeyValueObservingOptionNew
                                           context:nil
        ];
    }

    // add an observer to detect wake from sleep
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(checkExpirationTimer)
                                                               name:NSWorkspaceDidWakeNotification
                                                             object:nil
    ];
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    BOOL acceptConnection = NO;
    
    // see how we have been signed and make sure only processes with the same signing authority can connect.
    // additionally the calling application must have the same version number as this xpc service and must be
    // one of the components using a bundle identifier starting with "corp.sap.privileges"
    NSError *error = nil;
    NSString *signingAuth = [MTCodeSigning getSigningAuthorityWithError:&error];
    NSString *requiredVersion = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    if (signingAuth) {
        
        NSString *reqString = [MTCodeSigning codeSigningRequirementsWithCommonName:signingAuth
                                                                  bundleIdentifier:@"corp.sap.privileges*" 
                                                                     versionString:requiredVersion
        ];
        SecTaskRef taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
       
        if (taskRef) {
            
            if (SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(reqString)) == errSecSuccess) {

                acceptConnection = YES;
                   
                newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(PrivilegesAgentProtocol)];
                newConnection.exportedObject = self;
                
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
                [newConnection setInvalidationHandler:^{
                              
                    [newConnection setInvalidationHandler:nil];
                    os_log(OS_LOG_DEFAULT, "SAPCorp: %{public}@ invalidated", newConnection);
                }];
#pragma clang diagnostic pop
                
                [newConnection resume];

                os_log(OS_LOG_DEFAULT, "SAPCorp: %{public}@ established", newConnection);
    
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

- (void)invalidateXPC
{
    [_listener invalidate];
    _listener = nil;
}

- (void)scheduleExpirationTimerWithInterval:(NSUInteger)interval isExisitingTimer:(BOOL)existing
{
    if (existing && [self->_userDefaults objectForKey:kMTDefaultsAgentTimerExpirationKey]) {
        
        self->_timerExpirationDate = [self->_userDefaults objectForKey:kMTDefaultsAgentTimerExpirationKey];

    } else {
        
        self->_timerExpirationDate = [NSDate dateWithTimeIntervalSinceNow:(interval * 60)];
        
        [self->_userDefaults setObject:self->_timerExpirationDate
                                forKey:kMTDefaultsAgentTimerExpirationKey
        ];
    }

    // post a notification to update the Dock tile
    [self postAutoRevokeIntervalUpdateNotificationWithInterval:interval];
            
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self->_expirationTimer = [NSTimer scheduledTimerWithTimeInterval:60
                                                                 repeats:YES
                                                                   block:^(NSTimer *timer) {
            
            NSInteger minutesLeft = [self privilegesTimeLeft];
                                        
            if (minutesLeft > 0) {
                
                // post a notification to update the Dock tile
                [self postAutoRevokeIntervalUpdateNotificationWithInterval:minutesLeft];
                
            }  else {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [self revokeAdminRightsWithCompletionHandler:^(BOOL success) {
                        
                        os_log(OS_LOG_DEFAULT, "SAPCorp: Administrator privileges for user %{public}@ have expired.", [[self->_privilegesApp currentUser] userName]);
                    }];
                });
            }
        }];
        
    });
}

- (void)checkExpirationTimer
{
    if ([[NSDate date] compare:_timerExpirationDate] == NSOrderedDescending) {
                
        [_expirationTimer fire];
                
    } else {
                
        NSInteger minutesLeft = [self privilegesTimeLeft];
        [self postAutoRevokeIntervalUpdateNotificationWithInterval:minutesLeft];
    }
}

- (void)enforceFixedPrivileges
{
    NSString *enforcedPrivileges = [_privilegesApp enforcedPrivilegeType];
    BOOL userHasAdminPrivileges = [[_privilegesApp currentUser] hasAdminPrivileges];
    
    if (enforcedPrivileges || [_privilegesApp useIsRestrictedForUser:[_privilegesApp currentUser]]) {
        
        if (_expirationTimer) {
            [_expirationTimer invalidate];
            _expirationTimer = nil;
            _timerExpirationDate = nil;
            
            [self postAutoRevokeIntervalUpdateNotificationWithInterval:0];
        }
        
        if ([enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeAdmin] && !userHasAdminPrivileges) {
            
            [self requestAdminRightsWithReason:nil completionHandler:nil];
            
        } else if ([enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeUser] && userHasAdminPrivileges) {
            
            [self revokeAdminRightsWithCompletionHandler:nil];
        }
        
    } else {
        
        // if the user had admin privileges assigned, make sure the
        // expiration interval is applied after the profile is removed
        if (userHasAdminPrivileges && [_privilegesApp expirationInterval] > 0) {
        
            [self scheduleExpirationTimerWithInterval:[_privilegesApp expirationInterval]
                                     isExisitingTimer:NO
            ];
        }
    }
}

- (NSUInteger)privilegesTimeLeft
{
    return (ceil([_timerExpirationDate timeIntervalSinceNow]/60));
}

- (BOOL)userHasAdminPrivileges
{
    return ([[_privilegesApp currentUser] hasAdminPrivileges]);
}

- (void)launchExecutable
{
    NSString *executablePath = [_privilegesApp postChangeExecutablePath];
    
    if (executablePath) {
        
        NSURL *executableURL = [NSURL fileURLWithPath:executablePath];
        
        if (executableURL) {
            
            NSArray *launchArguments = [NSArray arrayWithObjects:
                                            [[self->_privilegesApp currentUser] userName],
                                        ([[self->_privilegesApp currentUser] hasAdminPrivileges]) ? @"admin" : @"user",
                                        nil
            ];
            
            // get the executable for a selected bundle…
            NSNumber *isBundle = nil;
            
            if ([executableURL getResourceValue:&isBundle forKey:NSURLIsPackageKey error:nil] && [isBundle boolValue]) {
                
                NSWorkspaceOpenConfiguration *openConfiguration = [NSWorkspaceOpenConfiguration configuration];
                [openConfiguration setArguments:launchArguments];
                
                [[NSWorkspace sharedWorkspace] openApplicationAtURL:executableURL
                                                      configuration:openConfiguration
                                                  completionHandler:nil
                ];
                
            } else {
                
                NSError *error = nil;
                
                [NSTask launchedTaskWithExecutableURL:executableURL
                                            arguments:launchArguments
                                                error:&error
                                   terminationHandler:nil
                ];
                
                if (error) {
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "%{public}@", [NSString stringWithFormat:@"SAPCorp: Failed to launch %@: %@", [executableURL path], error]);
                }
            }
            
        } else {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "%{public}@", @"SAPCorp: Failed to launch executable: Invalid file url");
        }
    }
}

- (void)remoteLoggingTaskWithReason:(NSString*)reason
{
    // check if remote logging is configured
    MTPrivileges *privilegesApp = [[MTPrivileges alloc] init];
    NSDictionary *remoteLoggingConfiguration = [privilegesApp remoteLoggingConfiguration];
    
    if (remoteLoggingConfiguration) {

        NSString *logServerType = [remoteLoggingConfiguration objectForKey:kMTDefaultsRemoteLoggingServerTypeKey];
        
        if ([[logServerType lowercaseString] isEqualToString:kMTRemoteLoggingServerTypeSyslog]) {
            
            NSString *logMessage = nil;
            
            if ([[self->_privilegesApp currentUser] hasAdminPrivileges]) {
                
                logMessage = [NSString stringWithFormat:@"SAPCorp: User %@ now has administrator privileges", [[self->_privilegesApp currentUser] userName]];
                if ([reason length] > 0) { logMessage = [logMessage stringByAppendingFormat:@" for the following reason: \"%@\"", reason]; }
            
            } else {
            
                logMessage = [NSString stringWithFormat:@"SAPCorp: User %@ now has standard user privileges", [[self->_privilegesApp currentUser] userName]];
                if ([reason length] > 0) { logMessage = [logMessage stringByAppendingFormat:@" (%@)", reason]; }
            }
                                            
            [self writeToSyslog:logMessage user:[_privilegesApp currentUser] completionHandler:^(NSError *error) {
                
                if (error) {
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Remote logging failed: %{public}@", error);
                }
            }];
            
        } else if ([[logServerType lowercaseString] isEqualToString:kMTRemoteLoggingServerTypeWebhook]) {

            NSString *webhookURL = [remoteLoggingConfiguration objectForKey:kMTDefaultsRemoteLoggingServerAddressKey];
            
            if (webhookURL && [webhookURL length] > 0) {

                MTWebhook *webHook = [[MTWebhook alloc] initWithURL:[NSURL URLWithString:webhookURL]];
                [webHook postToWebhookForUser:[_privilegesApp currentUser]
                                       reason:reason
                               expirationDate:_timerExpirationDate
                            completionHandler:^(NSError *error) {
                    
                    if (error) {
                        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Remote logging failed: %{public}@", error);
                    }
                }];
            }
        }
    }
}

- (void)writeToSyslog:(NSString*)message user:(MTPrivilegesUser*)user completionHandler:(void (^) (NSError *error))completionHandler
{
    MTPrivileges *privilegesApp = [[MTPrivileges alloc] init];
    NSDictionary *remoteLoggingConfiguration = [privilegesApp remoteLoggingConfiguration];
    
    NSString *serverAddress = [remoteLoggingConfiguration objectForKey:kMTDefaultsRemoteLoggingServerAddressKey];
    NSDictionary *syslogOptions = [remoteLoggingConfiguration objectForKey:kMTDefaultsRemoteLoggingSyslogOptionsKey];
    
    NSInteger serverPort = [[syslogOptions objectForKey:kMTDefaultsRemoteLoggingSyslogServerPortKey] integerValue];
    BOOL useTLS = [[syslogOptions objectForKey:kMTDefaultsRemoteLoggingSyslogUseTLSKey] boolValue];
    
    if (serverPort == 0) {
        if (useTLS) { serverPort = (useTLS) ? 6514 : 514; }
    }
    
    MTSyslogMessageFacility logFacility = ([syslogOptions objectForKey:kMTDefaultsRemoteLoggingSyslogFacilityKey]) ? [[syslogOptions valueForKey:kMTDefaultsRemoteLoggingSyslogFacilityKey] intValue] : MTSyslogMessageFacilityAuth;
    MTSyslogMessageSeverity logSeverity = ([syslogOptions objectForKey:kMTDefaultsRemoteLoggingSyslogSeverityKey]) ? [[syslogOptions valueForKey:kMTDefaultsRemoteLoggingSyslogSeverityKey] intValue] : MTSyslogMessageSeverityInformational;
    MTSyslogMessageMaxSize maxSize = ([syslogOptions objectForKey:kMTDefaultsRemoteLoggingSyslogMaxSizeKey]) ? [[syslogOptions valueForKey:kMTDefaultsRemoteLoggingSyslogMaxSizeKey] intValue] : 0;
    
    MTSyslogMessage *syslogMessage = [[MTSyslogMessage alloc] init];
    [syslogMessage setFacility:logFacility];
    [syslogMessage setSeverity:logSeverity];
    [syslogMessage setAppName:@"Privileges"];
    [syslogMessage setMessageId:([user hasAdminPrivileges]) ? @"PRIV_A" : @"PRIV_S"];
    if (maxSize > MTSyslogMessageMaxSize480) { [syslogMessage setMaxSize:maxSize]; }
    [syslogMessage setEventMessage:message];
    
    NSURLSessionStreamTask *syslogTask = [[NSURLSession sharedSession] streamTaskWithHostName:serverAddress port:serverPort];
    [syslogTask resume];
    
    if (useTLS) { [syslogTask startSecureConnection]; }
    [syslogTask writeData:[[syslogMessage messageString] dataUsingEncoding:NSUTF8StringEncoding]
                  timeout:10
        completionHandler:completionHandler
    ];
}

- (void)displayNotificationOfType:(MTLocalNotificationType)type
{
    NSString *notificationMessage = nil;
    
    switch (type) {
            
        case MTLocalNotificationTypeGrantSuccess:
            notificationMessage = NSLocalizedString(@"notificationMessage_GrantSuccess", nil);
            break;
            
        case MTLocalNotificationTypeRevokeSuccess:
            notificationMessage = NSLocalizedString(@"notificationMessage_RevokeSuccess", nil);
            break;
            
        case MTLocalNotificationTypeError:
            notificationMessage = NSLocalizedString(@"notificationMessage_Error", nil);
            break;
            
        default:
            break;
    }
    
    if (notificationMessage) {
        
        [_userNotification sendNotificationWithTitle:kMTAppName
                                             message:notificationMessage
                                            userInfo:nil
                                     replaceExisting:YES
                                   completionHandler:nil
        ];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == [_privilegesApp userDefaults] && [_keysToObserve containsObject:keyPath]) {
        
        if ([keyPath isEqualToString:kMTDefaultsEnforcePrivilegesKey] ||
            [keyPath isEqualToString:kMTDefaultsLimitToUserKey] ||
            [keyPath isEqualToString:kMTDefaultsLimitToGroupKey]) {
            
            [self enforceFixedPrivileges];
            
        } else if ([keyPath isEqualToString:kMTDefaultsExpirationIntervalKey] ||
                   [keyPath isEqualToString:kMTDefaultsAutoExpirationIntervalMaxKey]) {
            
            if ([self privilegesTimeLeft] > [_privilegesApp expirationInterval]) {
             
                [self scheduleExpirationTimerWithInterval:[_privilegesApp expirationInterval]
                                         isExisitingTimer:NO
                ];
            }
        }
            
        [self postConfigurationChangeNotificationForKeyPath:keyPath];
    }
}

#pragma mark Notifications

- (void)postPrivilegesChangedNotification
{
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kMTNotificationNamePrivilegesDidChange
                                                                   object:nil
                                                                 userInfo:nil
                                                                  options:NSNotificationDeliverImmediately
     ];
}

- (void)postAutoRevokeIntervalUpdateNotificationWithInterval:(NSUInteger)interval
{
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kMTNotificationNameExpirationTimeLeft
                                                                   object:nil
                                                                 userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:interval] forKey:kMTNotificationKeyTimeLeft]
                                                                  options:NSNotificationDeliverImmediately
     ];
}

- (void)postConfigurationChangeNotificationForKeyPath:(NSString*)keyPath
{
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kMTNotificationNameConfigDidChange
                                                                   object:nil
                                                                 userInfo:[NSDictionary dictionaryWithObject:keyPath forKey:kMTNotificationKeyPreferencesChanged]
                                                                  options:NSNotificationDeliverImmediately
     ];
}

#pragma mark Exported methods

- (void)connectWithEndpointReply:(void (^)(NSXPCListenerEndpoint *endpoint))reply
{
    if (reply) { reply([_listener endpoint]); }
}

- (void)requestAdminRightsWithReason:(NSString*)reason completionHandler:(void(^)(BOOL success))completionHandler
{
    BOOL isRestricted = [_privilegesApp useIsRestrictedForUser:[_privilegesApp currentUser]];
    BOOL adminEnforced = [[_privilegesApp enforcedPrivilegeType] isEqualToString:kMTEnforcedPrivilegeTypeAdmin];
    
    if (!isRestricted || adminEnforced) {
        
        [_daemonConnection connectToDaemonAndExecuteCommandBlock:^{
            
            [[[self->_daemonConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
                
                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to daemon: %{public}@", error);
                if (completionHandler) { completionHandler(NO); }
                
            }] grantAdminRightsToUser:[[self->_privilegesApp currentUser] userName]
                               reason:reason
                    completionHandler:^(BOOL success) {
                
                if (!isRestricted && !adminEnforced) {
                    
                    [self displayNotificationOfType:(success) ? MTLocalNotificationTypeGrantSuccess : MTLocalNotificationTypeError];
                }
                
                if (success) {
                    
                    // post a notification to inform the Dock tile plugin
                    [self postPrivilegesChangedNotification];
                    
                    if (!isRestricted && !adminEnforced) {
                        
                        NSUInteger removeAfterMinutes = [self->_privilegesApp expirationInterval];
                        
                        if (removeAfterMinutes > 0) {
                            
                            NSMeasurement *durationMeasurement = [[NSMeasurement alloc] initWithDoubleValue:removeAfterMinutes
                                                                                                       unit:[NSUnitDuration minutes]];
                            
                            NSMeasurementFormatter *durationFormatter = [[NSMeasurementFormatter alloc] init];
                            [[durationFormatter numberFormatter] setMaximumFractionDigits:0];
                            [durationFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
                            [durationFormatter setUnitStyle:NSFormattingUnitStyleLong];
                            [durationFormatter setUnitOptions:NSMeasurementFormatterUnitOptionsProvidedUnit];
                            
                            os_log(OS_LOG_DEFAULT, "SAPCorp: Administrator privileges are automatically revoked in %{public}@", [durationFormatter stringFromMeasurement:durationMeasurement]);
                            [self scheduleExpirationTimerWithInterval:removeAfterMinutes isExisitingTimer:NO];
                        }
                        
                        // remote logging
                        if ([self->_privilegesApp remoteLoggingConfiguration]) {
                            [self remoteLoggingTaskWithReason:reason];
                        }
                        
                        // run a script or application if configured
                        if (completionHandler && [self->_privilegesApp postChangeExecutablePath]) {
                            [self launchExecutable];
                        }
                    }
                }
                
                if (completionHandler) { completionHandler(success); }
                
            }];
        }];
        
    } else {
        
        if (completionHandler) { completionHandler(NO); }
    }
}

- (void)revokeAdminRightsWithCompletionHandler:(void(^)(BOOL success))completionHandler
{
    BOOL isRestricted = [_privilegesApp useIsRestrictedForUser:[_privilegesApp currentUser]];
    BOOL userEnforced = [[_privilegesApp enforcedPrivilegeType] isEqualToString:kMTEnforcedPrivilegeTypeUser];
    NSString *reason = ([self privilegesTimeLeft] > 0) ? @"requested by user" : @"privileges expired";
    
    if (!isRestricted || userEnforced) {
        
        if (_expirationTimer) {
            
            [_expirationTimer invalidate];
            _expirationTimer = nil;
            _timerExpirationDate = nil;
        }
        
        [_userDefaults removeObjectForKey:kMTDefaultsAgentTimerExpirationKey];
        
        [_daemonConnection connectToDaemonAndExecuteCommandBlock:^{
            
            [[[self->_daemonConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
                
                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to daemon: %{public}@", error);
                if (completionHandler) { completionHandler(NO); }
                
            }] removeAdminRightsFromUser:[[self->_privilegesApp currentUser] userName]
                                  reason:reason
                       completionHandler:^(BOOL success) {
                
                if (!isRestricted && !userEnforced) {
                    
                    [self displayNotificationOfType:(success) ? MTLocalNotificationTypeRevokeSuccess : MTLocalNotificationTypeError];
                }
                
                if (success) {
                    
                    // post a notification to inform the Dock tile plugin
                    [self postPrivilegesChangedNotification];
                    
                    if (!isRestricted && !userEnforced) {
                        
                        // remote logging
                        if ([self->_privilegesApp remoteLoggingConfiguration]) {
                            [self remoteLoggingTaskWithReason:reason];
                        }
                        
                        // run a script or application if configured
                        if (![self->_privilegesApp runActionAfterGrantOnly]) {
                            
                            if (completionHandler && [self->_privilegesApp postChangeExecutablePath]) {
                                [self launchExecutable];
                            }
                        }
                    }
                }
                
                if (completionHandler) { completionHandler(success); }
                
            }];
        }];
        
    } else {
        
        if (completionHandler) { completionHandler(NO); }
    }
}

- (void)authenticateUserWithCompletionHandler:(void(^)(BOOL success))completionHandler
{
    if (![_privilegesApp useIsRestrictedForUser:[_privilegesApp currentUser]]) {
        
        [MTIdentity authenticateUserWithReason:[NSString localizedStringWithFormat:NSLocalizedString(@"authenticationText", nil), [[_privilegesApp currentUser] userName]]
                             completionHandler:^(BOOL success, NSError *error) {
            
            if (completionHandler) { completionHandler(success); }
        }];
        
    } else {
        
        if (completionHandler) { completionHandler(NO); }
    }
}

- (void)expirationWithReply:(void(^)(NSDate *expire, NSUInteger remaining))reply;
{
    NSUInteger remainingTime = 0;
    
    if (_timerExpirationDate) { remainingTime = [self privilegesTimeLeft]; }
    if (reply) { reply(_timerExpirationDate, remainingTime); }
}

- (void)isExecutableFileAtURL:(NSURL*)url reply:(void(^)(BOOL isExecutable))reply
{
    if (reply) {
        
        BOOL executable = [MTSystemInfo isExecutableFileAtURL:url];
        reply(executable);
    }
}

@end
