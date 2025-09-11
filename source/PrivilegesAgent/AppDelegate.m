/*
    AppDelegate.m
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

#import "AppDelegate.h"
#import "MTPrivileges.h"
#import "MTCodeSigning.h"
#import "MTDaemonConnection.h"
#import "MTSystemInfo.h"
#import "Constants.h"
#import "MTIdentity.h"
#import "PrivilegesAgentProtocol.h"
#import "MTSyslog.h"
#import "MTWebhook.h"
#import "MTStatusItemMenu.h"
#import "MTRemoteLoggingManager.h"
#import <os/log.h>

@interface AppDelegate ()
@property (nonatomic, strong, readwrite) MTPrivileges *privilegesApp;
@property (nonatomic, strong, readwrite) NSArray *keysToObserve;
@property (nonatomic, strong, readwrite) NSArray *appGroupToObserve;
@property (nonatomic, strong, readwrite) NSTimer *expirationTimer;
@property (nonatomic, strong, readwrite) NSTimer *statusItemTimer;
@property (nonatomic, strong, readwrite) NSTimer *animationTimer;
@property (nonatomic, strong, readwrite) NSDate *timerExpirationDate;
@property (nonatomic, strong, readwrite) NSUserDefaults *userDefaults;
@property (nonatomic, strong, readwrite) NSUserDefaults *appGroupDefaults;
@property (nonatomic, strong, readwrite) MTLocalNotification *userNotification;
@property (nonatomic, strong, readwrite) MTDaemonConnection *daemonConnection;
@property (nonatomic, strong, readwrite) NSStatusItem *statusItem;
@property (nonatomic, strong, readwrite) MTStatusItemMenu *statusMenu;
@property (nonatomic, strong, readwrite) MTRemoteLoggingManager *logManager;
@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (retain) id adminGroupObserver;
@property (assign) BOOL observingStatusItem;
@property (assign) BOOL adminRightsExpected;
@property (assign) BOOL ignoreAdminGroupChanges;
@end

@interface ExtendedNSXPCConnection : NSXPCConnection
@property audit_token_t auditToken;
@end

OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification 
{
    _privilegesApp = [[MTPrivileges alloc] init];
    
    if (!_privilegesApp) {
        
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Fatal error! Unable to continue");
        
    } else {
        
        os_log(OS_LOG_DEFAULT, "SAPCorp: Launched for user %{public}@", [[_privilegesApp currentUser] userName]);
        
        _listener = [[NSXPCListener alloc] initWithMachServiceName:kMTAgentMachServiceName];
        [_listener setDelegate:self];
        [_listener resume];
        
        _daemonConnection = [[MTDaemonConnection alloc] init];
        _userDefaults = [NSUserDefaults standardUserDefaults];
        _appGroupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppGroupIdentifier];
        
        _userNotification = [[MTLocalNotification alloc] init];
        [_userNotification setDelegate:self];
        [_userNotification requestAuthorizationWithCompletionHandler:nil];
        [_userNotification setCategoryIdentifier:kMTNotificationCategoryIdentifier];
        [_userNotification setActions:[NSArray arrayWithObject:
                                           [UNNotificationAction actionWithIdentifier:kMTNotificationActionIdentifierRenew
                                                                                title:NSLocalizedString(@"renewButton", nil)
                                                                              options:0
                                           ]
                                      ]
        ];
        
        BOOL removeSavedTimer = YES;
        _adminRightsExpected = [self userHasAdminPrivileges];
        
        // enforce fixed privileges
        if ([[_privilegesApp currentUser] useIsRestricted]) {
            
            [self enforceFixedPrivileges];
            
        } else if (_adminRightsExpected) {
            
            // revoke administrator privileges if needed
            if ([_privilegesApp privilegesShouldBeRevokedAtLogin] &&
                [[NSDate date] timeIntervalSinceDate:[MTSystemInfo sessionStartDate]] < kMTRevokeAtLoginThreshold) {
                
                [self revokeAdminRightsWithCompletionHandler:^(BOOL success) {
                    if (success) { self->_adminRightsExpected = NO; }
                }];
                
            // check for a running timer
            } else {
                
                NSDate *previousDate = [_userDefaults objectForKey:kMTDefaultsAgentTimerExpirationKey];
                
                if (previousDate) {
                    
                    // is the timer still valid?
                    if ([[NSDate date] compare:previousDate] == NSOrderedAscending) {
                        
                        removeSavedTimer = NO;
                        NSUInteger remainingTime = ceil([previousDate timeIntervalSinceNow]/60.0);
                        if (remainingTime > [_privilegesApp expirationInterval]) { remainingTime = [_privilegesApp expirationInterval]; }
                        [self scheduleExpirationTimerWithInterval:remainingTime isSavedTimer:YES];
                        
                    } else {
                        
                        [self revokeAdminRightsWithCompletionHandler:^(BOOL success) {
                            if (success) { self->_adminRightsExpected = NO; }
                        }];
                    }
                }
            }
        }
        
        // remove invalid (expired) timers
        if (removeSavedTimer) { [_userDefaults removeObjectForKey:kMTDefaultsAgentTimerExpirationKey]; }
        
        // define the keys in our prefs we need to observe
        _keysToObserve = [[NSArray alloc] initWithObjects:
                              kMTDefaultsExpirationIntervalKey,
                              kMTDefaultsExpirationIntervalMaxKey,
                              kMTDefaultsAllowPrivilegeRenewalKey,
                              kMTDefaultsHideOtherWindowsKey,
                              kMTDefaultsRevokeAtLoginKey,
                              kMTDefaultsRevokeAtLoginExcludedUsersKey,
                              kMTDefaultsPostChangeExecutablePathKey,
                              kMTDefaultsPostChangeActionOnGrantOnlyKey,
                              kMTDefaultsEnforcePrivilegesKey,
                              kMTDefaultsLimitToUserKey,
                              kMTDefaultsLimitToGroupKey,
                              kMTDefaultsShowInMenuBarKey,
                              kMTDefaultsShowRemainingTimeInMenuBarKey,
                              kMTDefaultsRemoteLoggingKey,
                              nil
        ];
        
        // start observing our preferences to make sure we'll get notified as soon as
        // something changes (e.g. a configuration profile has been installed).
        for (NSString *aKey in _keysToObserve) {
            
            [[_privilegesApp userDefaults] addObserver:self
                                            forKeyPath:aKey
                                               options:NSKeyValueObservingOptionNew
                                               context:nil
            ];
        }
        
        // define the keys in our app group we need to observe
        _appGroupToObserve = [[NSArray alloc] initWithObjects:
                                  kMTDefaultsShowInMenuBarKey,
                                  kMTDefaultsShowRemainingTimeInMenuBarKey,
                                  nil
        ];
        
        for (NSString *aKey in _appGroupToObserve) {
            
            [_appGroupDefaults addObserver:self
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
        
        // add an observer to detect changes to the system time
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(systemTimeChanged:)
                                                     name:NSSystemClockDidChangeNotification
                                                   object:nil
        ];
        
#pragma mark - check for unexpected permission changes
        
        _adminGroupObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:kMTNotificationNameAdminGroupDidChange
                                                                                           object:nil
                                                                                            queue:nil
                                                                                       usingBlock:^(NSNotification *notification) {
            
            if (!self->_ignoreAdminGroupChanges && [self userHasAdminPrivileges] != self->_adminRightsExpected) {
                
                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Administrator privileges for user %{public}@ have been changed by another process", [[self->_privilegesApp currentUser] userName]);
                [[self->_privilegesApp currentUser] setUnexpectedPrivilegeState:YES];
                
                self->_adminRightsExpected = [self userHasAdminPrivileges];
                
                // remote logging
                if ([self->_privilegesApp remoteLoggingConfiguration]) {
                    [self remoteLoggingTaskWithReason:@"changed by another process"];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [self invalidateExpirationTimer];
                    
                    // update the status item
                    [self showStatusItem:[self->_privilegesApp showInMenuBar]];
                });
                
                // post a notification to inform the Dock tile plugin
                [self postPrivilegesChangedNotification];
            }
        }];
        
        // show the status item (if enabled)
        [self showStatusItem:[_privilegesApp showInMenuBar]];
        
        // initialize the logging manager
        [self initializeLogManager];
    }
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

- (void)scheduleExpirationTimerWithInterval:(NSUInteger)interval isSavedTimer:(BOOL)savedTimer
{
    if (_expirationTimer) {
        
        if (!savedTimer) {
            
            os_log(OS_LOG_DEFAULT, "SAPCorp: Administrator privileges for user %{public}@ have been renewed (%{public}@)", [[self->_privilegesApp currentUser] userName], [MTPrivileges stringForDuration:[_privilegesApp expirationInterval] localized:NO naturalScale:NO]);
            
            // remote logging
            if ([self->_privilegesApp remoteLoggingConfiguration]) {
                [self remoteLoggingTaskWithReason:@"renewed by user"];
            }
        }
        
        [self invalidateExpirationTimer];
    }
    
    self->_timerExpirationDate = [NSDate dateWithTimeIntervalSinceNow:(interval * 60)];
    
    [self->_userDefaults setObject:self->_timerExpirationDate
                            forKey:kMTDefaultsAgentTimerExpirationKey
    ];

    // post a notification to update the Dock tile
    [self postAutoRevokeIntervalUpdateNotificationWithInterval:interval];
        
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSInteger renewalNotificationTime = [self->_privilegesApp renewalNotificationInterval];
        
        self->_expirationTimer = [NSTimer scheduledTimerWithTimeInterval:60
                                                                 repeats:YES
                                                                   block:^(NSTimer *timer) {
            
            NSInteger minutesLeft = [self privilegesTimeLeft];

            if (minutesLeft > 0) {
                
                // post a notification to update the Dock tile
                [self postAutoRevokeIntervalUpdateNotificationWithInterval:minutesLeft];
                
                // update the status item's tooltip
                if ([self->_privilegesApp showInMenuBar]) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showStatusItem:YES];
                    });
                }
                
                // if the administrator privileges are about to expire and privilege renewal
                // is allowed, we post a notification and ask the user to renew the privileges.
                // if a custom renewal workflow has been configured, we run the configured
                // executable instead of posting the user notification.
                if (minutesLeft == renewalNotificationTime &&
                    [self->_privilegesApp expirationInterval] > renewalNotificationTime &&
                    [self->_privilegesApp privilegeRenewalAllowed]) {
                    
                    NSDictionary *renewalCustomAction = [self->_privilegesApp renewalCustomAction];
                    NSString *actionPath = [renewalCustomAction objectForKey:kMTDefaultsRenewalCustomActionPathKey];
                    
                    if ([actionPath length] > 0) {
                        
                        [self launchExecutableAtPath:actionPath
                                           arguments:[NSArray arrayWithObject:[NSString stringWithFormat:@"%ld", renewalNotificationTime]]
                        ];
                        
                    } else {
                        
                        [self displayNotificationOfType:MTLocalNotificationTypeRenew];
                    }
                }
                
            }  else {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [self revokeAdminRightsWithCompletionHandler:^(BOOL success) {
                        
                        os_log(OS_LOG_DEFAULT, "SAPCorp: Administrator privileges for user %{public}@ have expired", [[self->_privilegesApp currentUser] userName]);
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

- (void)invalidateExpirationTimer
{
    if (_expirationTimer) {
        
        [_expirationTimer invalidate];
        _expirationTimer = nil;
        _timerExpirationDate = nil;
        
        [self postAutoRevokeIntervalUpdateNotificationWithInterval:0];
    }
    
    [self->_userDefaults removeObjectForKey:kMTDefaultsAgentTimerExpirationKey];
}

- (void)enforceFixedPrivileges
{
    NSString *enforcedPrivileges = [_privilegesApp enforcedPrivilegeType];
    BOOL userHasAdminPrivileges = [self userHasAdminPrivileges];
    
    if (enforcedPrivileges || [[_privilegesApp currentUser] useIsRestricted]) {
        
        [self invalidateExpirationTimer];
        
        if ([enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeAdmin] && !userHasAdminPrivileges) {
            
            [self requestAdminRightsWithReason:nil completionHandler:nil];
            
        } else if ([enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeUser] && userHasAdminPrivileges) {
            
            [self revokeAdminRightsWithCompletionHandler:^(BOOL success) { return; }];
        }
        
    } else {
        
        // if the user had admin privileges assigned, make sure the
        // expiration interval is applied after the profile is removed
        if (userHasAdminPrivileges && [_privilegesApp expirationInterval] > 0) {
        
            [self scheduleExpirationTimerWithInterval:[_privilegesApp expirationInterval] isSavedTimer:NO];
        }
    }
}

- (void)launchExecutableAtPath:(NSString*)executablePath arguments:(NSArray*)launchArguments
{
    if (executablePath) {
        
        NSURL *executableURL = [NSURL fileURLWithPath:executablePath];
        
        if (executableURL) {
            
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
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Failed to launch %{public}@: %{public}@", [executableURL path], error);
                }
            }
            
        } else {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Failed to launch executable: Invalid file url");
        }
    }
}

- (void)initializeLogManager
{
    if (_logManager) {
        
        [_logManager cancelRetries];
        _logManager = nil;
    }
        
    MTPrivilegesLoggingConfiguration *remoteLoggingConfiguration = [_privilegesApp remoteLoggingConfiguration];
    
    if (remoteLoggingConfiguration) {
        
        _logManager = [[MTRemoteLoggingManager alloc] initWithRetryIntervals:kMTRemoteLoggingRetryIntervals];
        [_logManager setQueueUnsentEvents:[remoteLoggingConfiguration queueUnsentEvents]];
        BOOL success = [_logManager start];
    
        if (success) {
            os_log(OS_LOG_DEFAULT, "SAPCorp: Successfully initialized remote logging manager");
        } else {
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to initialize remote logging manager");
        }
    }
}

- (void)remoteLoggingTaskWithReason:(NSString*)reason
{
    if (!_logManager) { [self initializeLogManager]; }
    
    // check if remote logging is configured
    MTPrivilegesLoggingConfiguration *remoteLoggingConfiguration = [_privilegesApp remoteLoggingConfiguration];
    
    if (remoteLoggingConfiguration) {
        
        NSDictionary *eventToSend = nil;
                
        if ([[remoteLoggingConfiguration serverType] isEqualToString:kMTRemoteLoggingServerTypeSyslog]) {
            
            MTSyslogOptions *syslogOptions = [remoteLoggingConfiguration syslogOptions];
            
            // create the syslog message
            NSString *logMessage = nil;
            
            if ([[self->_privilegesApp currentUser] hasAdminPrivileges]) {
                
                logMessage = [NSString stringWithFormat:@"SAPCorp: User %@ now has administrator privileges", [[self->_privilegesApp currentUser] userName]];
                if ([reason length] > 0) { logMessage = [logMessage stringByAppendingFormat:@" for the following reason: \"%@\"", reason]; }
                
            } else {
                
                logMessage = [NSString stringWithFormat:@"SAPCorp: User %@ now has standard user privileges", [[self->_privilegesApp currentUser] userName]];
                if ([reason length] > 0) { logMessage = [logMessage stringByAppendingFormat:@" (%@)", reason]; }
            }
            
            MTSyslogMessage *syslogMessage = [[MTSyslogMessage alloc] init];
            [syslogMessage setFormat:[syslogOptions messageFormat]];
            [syslogMessage setFacility:[syslogOptions logFacility]];
            [syslogMessage setSeverity:[syslogOptions logSeverity]];
            [syslogMessage setAppName:kMTAppName];
            [syslogMessage setMessageID:([[_privilegesApp currentUser] hasAdminPrivileges]) ? @"PRIV_A" : @"PRIV_S"];
            [syslogMessage setMaxSize:[syslogOptions maxSize]];
            [syslogMessage setEventMessage:logMessage];
            
            MTSyslogMessageStructuredData *syslogSD = [[MTSyslogMessageStructuredData alloc] init];
            [syslogSD structuredDataWithDictionary:[syslogOptions structuredData]];
            [syslogMessage setStructuredData:syslogSD];
            
            NSData *syslogData = [[syslogMessage composedMessage] dataUsingEncoding:NSUTF8StringEncoding];
            
            if (syslogData) {
                
                eventToSend = [NSDictionary dictionaryWithObject:syslogData
                                                          forKey:kMTRemoteLoggingServerTypeSyslog
                ];
            }
            
        } else if ([[remoteLoggingConfiguration serverType] isEqualToString:kMTRemoteLoggingServerTypeWebhook]) {

            MTWebhook *webhookEvent = [[MTWebhook alloc] initWithURL:nil];
            [webhookEvent setPrivilegesUser:[self->_privilegesApp currentUser]];
            [webhookEvent setReason:reason];
            [webhookEvent setExpirationDate:self->_timerExpirationDate];
            [webhookEvent setCustomData:[remoteLoggingConfiguration webhookCustomData]];
            
            NSData *webhookData = [webhookEvent composedData];
            
            if (webhookData) {
                
                eventToSend = [NSDictionary dictionaryWithObject:webhookData
                                                          forKey:kMTRemoteLoggingServerTypeWebhook
                ];
            }
        }
        
        // send the event
        [_logManager sendEvent:eventToSend completionHandler:^(BOOL success, NSError *error) {
            
            if (!success) {
                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Remote logging failed: %{public}@", error);
            }
        }];
    }
}

- (void)displayNotificationOfType:(MTLocalNotificationType)type
{
    NSString *notificationMessage = nil;
    BOOL hasAction = NO;
    
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
            
        case MTLocalNotificationTypeRenew:
            notificationMessage = NSLocalizedString(@"notificationMessage_Renew", nil);
            hasAction = YES;
            break;
            
        case MTLocalNotificationTypeRenewSuccess:
            notificationMessage = NSLocalizedString(@"notificationMessage_RenewSuccess", nil);
            break;
            
        default:
            break;
    }
    
    if (notificationMessage) {
        
        [_userNotification sendNotificationWithTitle:kMTAppName
                                             message:notificationMessage
                                            userInfo:nil
                                     replaceExisting:YES
                                           action:hasAction
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
                   [keyPath isEqualToString:kMTDefaultsExpirationIntervalMaxKey]) {
            
            // invalidate or (re)schedule our timer if needed
            if ([_privilegesApp expirationInterval] == 0) {
                
                [self invalidateExpirationTimer];
                                
            } else if ([self privilegesTimeLeft] > [_privilegesApp expirationInterval] ||
                       ([self userHasAdminPrivileges] && [self privilegesTimeLeft] == 0)) {
             
                [self scheduleExpirationTimerWithInterval:[_privilegesApp expirationInterval] isSavedTimer:NO];
            }
            
        } else if ([keyPath isEqualToString:kMTDefaultsRemoteLoggingKey]) {

            [self initializeLogManager];
        }
        
        // update the status item if needed
        [self showStatusItem:[self->_privilegesApp showInMenuBar]];

        [self postConfigurationChangeNotificationForKeyPath:keyPath];
        
    } else if ((object == _appGroupDefaults && ([keyPath isEqualToString:kMTDefaultsShowInMenuBarKey] ||
                                                [keyPath isEqualToString:kMTDefaultsShowRemainingTimeInMenuBarKey])) ||
               (object == _statusItem && [keyPath isEqualToString:@"visible"])) {
        
        if (object == _statusItem) { [_appGroupDefaults setBool:NO forKey:kMTDefaultsShowInMenuBarKey]; }
        [self showStatusItem:[self->_privilegesApp showInMenuBar]];
        
        if ([keyPath isEqualToString:kMTDefaultsShowRemainingTimeInMenuBarKey]) {
            
            [self postConfigurationChangeNotificationForKeyPath:kMTDefaultsShowRemainingTimeInMenuBarKey];
            
        } else {
            
            [self postConfigurationChangeNotificationForKeyPath:kMTDefaultsShowInMenuBarKey];
        }
    }
}

#pragma mark - AppleScriptDataProvider

- (NSUInteger)privilegesTimeLeft
{
    return (NSUInteger)(ceil([_timerExpirationDate timeIntervalSinceNow]/60.0));
}

- (BOOL)userHasAdminPrivileges
{
    return ([[_privilegesApp currentUser] hasAdminPrivileges]);
}

#pragma mark - NSStatusItem

- (void)showStatusItem:(BOOL)status
{
    if (status) {
        
        if (!_statusItem) {
            
            _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];            
            [_statusItem button];
            
            _statusMenu = [[MTStatusItemMenu alloc] init];
            
            NSMenuItem *privilegesItem = [[NSMenuItem alloc] init];
            [privilegesItem setTitle:NSLocalizedStringFromTable(@"requestMenuItem", @"LocalizableMenu", nil)];
            [privilegesItem setAction:@selector(changePrivilegesFromStatusItem)];
            [privilegesItem setTarget:self];
            [privilegesItem setTag:1000];
            [_statusMenu addItem:privilegesItem];
            
            NSMenuItem *renewalItem = [[NSMenuItem alloc] init];
            [renewalItem setTitle:NSLocalizedStringFromTable(@"renewMenuItem", @"LocalizableMenu", nil)];
            [renewalItem setAction:@selector(renewPrivilegesFromStatusItem)];
            [renewalItem setTarget:self];
            [renewalItem setAlternate:YES];
            [renewalItem setKeyEquivalentModifierMask:NSEventModifierFlagOption];
            [renewalItem setTag:2000];
            [_statusMenu addItem:renewalItem];
            
            NSURL *executableURL = [[[[[NSBundle mainBundle] bundleURL] URLByDeletingLastPathComponent] URLByDeletingLastPathComponent] URLByDeletingLastPathComponent];
            
            if (executableURL && ![_privilegesApp hideSettingsFromStatusItem]) {
                
                NSNumber *isBundle = nil;
                
                if ([executableURL getResourceValue:&isBundle forKey:NSURLIsPackageKey error:nil] && [isBundle boolValue]) {
                    
                    NSMenuItem *settingsItem = [[NSMenuItem alloc] init];
                    [settingsItem setTitle:NSLocalizedStringFromTable(@"settingsMenuItem", @"LocalizableMenu", nil)];
                    [settingsItem setAction:@selector(showSettings:)];
                    [settingsItem setRepresentedObject:executableURL];
                    [settingsItem setTarget:self];
                    
                    [_statusMenu addItem:[NSMenuItem separatorItem]];
                    [_statusMenu addItem:settingsItem];
                }
            }
            
            [_statusItem setMenu:_statusMenu];
            
        } else if (_statusMenu) {
            
            [_statusMenu updateMenu];
        }
        
        // set the tooltip or the menu bar timer
        [self updateRemainingTimeForStatusItem];
        
        // set the behavior
        if (![_privilegesApp showInMenuBarIsForced]) {

            [_statusItem setBehavior:NSStatusItemBehaviorRemovalAllowed];

            if (!_observingStatusItem) {
                
                [_statusItem addObserver:self
                              forKeyPath:@"visible"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil
                ];
                
                _observingStatusItem = YES;
            }
            
        } else {
            
            [_statusItem setBehavior:0];
            
            // remove our observer
            if (_observingStatusItem) {
                
                [_statusItem removeObserver:self forKeyPath:@"visible" context:nil];
                _observingStatusItem = NO;
            }
        }
                
        // set the image
        [self updateImageForStatusItem];
        
    } else {
        
        if (_statusItem) {

            // remove the status item
            [[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
            _statusMenu = nil;
            _statusItem = nil;
            _observingStatusItem = NO;
        }
    }
}

- (void)updateRemainingTimeForStatusItem
{
    if (_statusItemTimer) {
        [_statusItemTimer invalidate];
        _statusItemTimer = nil;
    }
    
    if ([_privilegesApp showRemainingTimeInMenuBar]) {
        
        [[_statusItem button] setToolTip:nil];
        
        if ([self privilegesTimeLeft] > 0) {
            
            [self updateStatusItemTimerWithAttributedString:[self timeStringForStatusItem]];
            
            _statusItemTimer = [NSTimer scheduledTimerWithTimeInterval:.5
                                                               repeats:YES
                                                                 block:^(NSTimer *timer) {
                
                    [self updateStatusItemTimerWithAttributedString:[self timeStringForStatusItem]];
            }];
            
            // make sure the timer is updating even if the status item's menu is open
            [[NSRunLoop currentRunLoop] addTimer:_statusItemTimer forMode:NSEventTrackingRunLoopMode];
            
        } else {
            
            [self updateStatusItemTimerWithAttributedString:nil];
        }
        
    } else {
        
        [self updateStatusItemTimerWithAttributedString:nil];
        [[_statusItem button] setToolTip:([self privilegesTimeLeft] > 0) ? [MTPrivileges stringForDuration:[self privilegesTimeLeft]
                                                                                                 localized:YES
                                                                                              naturalScale:NO
                                                                           ] : nil
        ];
    }
}

- (void)updateImageForStatusItem
{
    NSString *iconName = ([[_privilegesApp currentUser] hasAdminPrivileges]) ? @"unlocked" : @"locked";
    if ([[_privilegesApp currentUser] useIsRestricted]) { iconName = [iconName stringByAppendingString:@"_managed"]; }
    [[_statusItem button] setImage:[NSImage imageNamed:iconName]];
}

- (NSAttributedString*)timeStringForStatusItem
{
    NSAttributedString *timeString = [[NSAttributedString alloc] initWithString:@""];
    
    if ([self privilegesTimeLeft] > 0) {
        
        NSTimeInterval interval = [_timerExpirationDate timeIntervalSinceNow];
        NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
        [formatter setAllowedUnits:NSCalendarUnitMinute | NSCalendarUnitSecond];
        [formatter setUnitsStyle:NSDateComponentsFormatterUnitsStylePositional];
        [formatter setZeroFormattingBehavior:NSDateComponentsFormatterZeroFormattingBehaviorPad];

        NSDictionary *textAttributes = [NSDictionary dictionaryWithObject:[NSFont monospacedDigitSystemFontOfSize:[NSFont systemFontSize]
                                                                                                           weight:NSFontWeightRegular
                                                                          ]
                                                                   forKey:NSFontAttributeName
        ];
        
        timeString = [[NSAttributedString alloc] initWithString:[formatter stringFromTimeInterval:interval]
                                                     attributes:textAttributes
        ];
    }
    
    return timeString;
}

- (void)updateStatusItemTimerWithAttributedString:(NSAttributedString*)timerString
{
    if (_animationTimer) {
        [_animationTimer invalidate];
        _animationTimer = nil;
    }
    
    if (timerString) {
        
        NSAttributedString *currentString = [[_statusItem button] attributedTitle];
        NSInteger timerStringLength = [timerString length];
        NSInteger currentStringLength = [currentString length];
        BOOL showTimer = (timerStringLength > 0);
        
        BOOL canBeAnimated = (showTimer && currentStringLength == 0) || (!showTimer && currentStringLength > 0);
        
        if (canBeAnimated) {

            __block NSInteger i = (showTimer) ? 0 : timerStringLength;
            if (!showTimer) { i = currentStringLength; }
            
            _animationTimer = [NSTimer scheduledTimerWithTimeInterval:.03
                                                              repeats:YES
                                                                block:^(NSTimer *timer) {
                
                if (showTimer && i < timerStringLength) {
                    
                    [[self->_statusItem button] setAttributedTitle:[timerString attributedSubstringFromRange:NSMakeRange(0, ++i)]];
                    
                } else if (!showTimer && i > 0) {
                    
                    [[self->_statusItem button] setAttributedTitle:[currentString attributedSubstringFromRange:NSMakeRange(0, i--)]];
                    
                } else {
                    
                    if (!showTimer) { [[self->_statusItem button] setTitle:@""]; }
                    [timer invalidate];
                    timer = nil;
                }
            }];
                        
        } else {
            
            [[_statusItem button] setAttributedTitle:timerString];
        }
        
    } else {
        
        [[_statusItem button] setTitle:@""];
    }
}

- (void)changePrivilegesFromStatusItem
{
    if ([self userHasAdminPrivileges]) {
        
        // we provide dummy completion handlers here instead of nil,
        // to make sure the script or application runs after privileges
        // changed (if configured)
        [self revokeAdminRightsWithCompletionHandler:^(BOOL success) { return; }];
        
    } else {
        
        // in some cases we cannot request admin privileges from the Dock Tile.
        // in these cases we just open the Privileges app instead to allow the
        // user to request admin privileges there.
        if ([_privilegesApp reasonRequired]) {
            
            [MTPrivileges openMainApplication];
            
        } else if ([_privilegesApp authenticationRequired]) {
            
            [self authenticateUserWithCompletionHandler:^(BOOL success) {
                
                if (success) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self requestAdminRightsWithReason:nil completionHandler:^(BOOL success) { return; }];
                    });
                }
            }];
            
        } else {
            
            [self requestAdminRightsWithReason:nil completionHandler:^(BOOL success) { return; }];
        }
    }
}

- (void)renewPrivilegesFromStatusItem
{
    if ([_privilegesApp authenticationRequired] && [_privilegesApp renewalFollowsAuthSetting]) {
        
        [self authenticateUserWithCompletionHandler:^(BOOL success) {
            
            if (success) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self renewAdminRightsWithCompletionHandler:nil];
                });
            }
        }];
        
    } else {
        
        [self renewAdminRightsWithCompletionHandler:nil];
    }
}

- (void)showSettings:(id)sender
{
    NSURL *executableURL = [sender representedObject];
    
    if (executableURL) {

        NSWorkspaceOpenConfiguration *openConfiguration = [NSWorkspaceOpenConfiguration configuration];
        [openConfiguration setArguments:[NSArray arrayWithObject:@"--showSettings"]];
        
        [[NSWorkspace sharedWorkspace] openApplicationAtURL:executableURL
                                              configuration:openConfiguration
                                          completionHandler:nil
        ];
    }
}

#pragma mark - Notifications

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

#pragma mark - System time changed

- (void)systemTimeChanged:(NSNotification*)notification
{
    if ([[_privilegesApp currentUser] hasAdminPrivileges] &&
        [_privilegesApp privilegesShouldBeRevokedAfterSystemTimeChange]) {
        
        os_log(OS_LOG_DEFAULT, "SAPCorp: Revoking administrator privileges because system time changed");
        
        // remove admin rights
        [self revokeAdminRightsWithCompletionHandler:^(BOOL success) { return; }];
    }
}

#pragma mark - Exported methods

- (void)connectWithEndpointReply:(void (^)(NSXPCListenerEndpoint *endpoint))reply
{
    if (reply) { reply([_listener endpoint]); }
}

- (void)requestAdminRightsWithReason:(NSString*)reason completionHandler:(void(^)(BOOL success))completionHandler
{
    BOOL isRestricted = [[_privilegesApp currentUser] useIsRestricted];
    BOOL adminEnforced = [[_privilegesApp enforcedPrivilegeType] isEqualToString:kMTEnforcedPrivilegeTypeAdmin];
    
    if (!isRestricted || adminEnforced) {
        
        _ignoreAdminGroupChanges = YES;
        
        [_daemonConnection connectToDaemonAndExecuteCommandBlock:^{
            
            [[[self->_daemonConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
                
                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to daemon: %{public}@", error);
                self->_ignoreAdminGroupChanges = NO;
                if (completionHandler) { completionHandler(NO); }
                
            }] grantAdminRightsToUser:[[self->_privilegesApp currentUser] userName]
                               reason:reason
                    completionHandler:^(BOOL success) {
                                
                self->_adminRightsExpected = success;
                
                if (!isRestricted && !adminEnforced) {
                    
                    [self displayNotificationOfType:(success) ? MTLocalNotificationTypeGrantSuccess : MTLocalNotificationTypeError];
                }
                
                if (success) {
                    
                    [[self->_privilegesApp currentUser] setUnexpectedPrivilegeState:NO];
                    
                    // post a notification to inform the Dock tile plugin
                    [self postPrivilegesChangedNotification];
                    
                    // update the status item
                    dispatch_async(dispatch_get_main_queue(), ^{ [self showStatusItem:[self->_privilegesApp showInMenuBar]]; });
                    
                    if (!isRestricted && !adminEnforced) {
                        
                        NSUInteger removeAfterMinutes = [self->_privilegesApp expirationInterval];
                        
                        if (removeAfterMinutes > 0) {
                            
                            os_log(OS_LOG_DEFAULT, "SAPCorp: Administrator privileges are automatically revoked in %{public}@", [MTPrivileges stringForDuration:removeAfterMinutes localized:NO naturalScale:NO]);
                            [self scheduleExpirationTimerWithInterval:removeAfterMinutes isSavedTimer:NO];
                        }
                        
                        // remote logging
                        if ([self->_privilegesApp remoteLoggingConfiguration]) {
                            [self remoteLoggingTaskWithReason:reason];
                        }
                        
                        // run a script or application if configured
                        if (completionHandler && [self->_privilegesApp postChangeExecutablePath]) {
                            
                            NSMutableArray *launchArguments = [NSMutableArray arrayWithObjects:
                                                                   [[self->_privilegesApp currentUser] userName],
                                                                   @"admin",
                                                                   nil
                            ];
                                
                            if ([self->_privilegesApp passReasonToExecutable] && [reason length] > 0) { [launchArguments addObject:reason]; }
                            
                            [self launchExecutableAtPath:[self->_privilegesApp postChangeExecutablePath]
                                               arguments:launchArguments
                            ];
                        }
                    }
                }
                
                self->_ignoreAdminGroupChanges = NO;
                
                if (completionHandler) { completionHandler(success); }
                
            }];
        }];
        
    } else {
        
        if (completionHandler) { completionHandler(NO); }
    }
}

- (void)revokeAdminRightsWithCompletionHandler:(void(^)(BOOL success))completionHandler
{
    BOOL isRestricted = [[_privilegesApp currentUser] useIsRestricted];
    BOOL userEnforced = [[_privilegesApp enforcedPrivilegeType] isEqualToString:kMTEnforcedPrivilegeTypeUser];
    NSString *reason = ([self privilegesTimeLeft] > 0) ? @"requested by user" : @"privileges expired";
    
    if (!isRestricted || userEnforced) {
        
        [self invalidateExpirationTimer];
        _ignoreAdminGroupChanges = YES;
        
        [_daemonConnection connectToDaemonAndExecuteCommandBlock:^{
            
            [[[self->_daemonConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
                
                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to daemon: %{public}@", error);
                self->_ignoreAdminGroupChanges = NO;
                if (completionHandler) { completionHandler(NO); }
                
            }] removeAdminRightsFromUser:[[self->_privilegesApp currentUser] userName]
                                  reason:reason
                       completionHandler:^(BOOL success) {
                
                self->_adminRightsExpected = !success;
                
                if (!isRestricted && !userEnforced) {
                    
                    [self displayNotificationOfType:(success) ? MTLocalNotificationTypeRevokeSuccess : MTLocalNotificationTypeError];
                }
                
                if (success) {
                    
                    [[self->_privilegesApp currentUser] setUnexpectedPrivilegeState:NO];
                    
                    // post a notification to inform the Dock tile plugin
                    [self postPrivilegesChangedNotification];
                    
                    // update the status item
                    dispatch_async(dispatch_get_main_queue(), ^{ [self showStatusItem:[self->_privilegesApp showInMenuBar]]; });
                    
                    if (!isRestricted && !userEnforced) {
                        
                        // remote logging
                        if ([self->_privilegesApp remoteLoggingConfiguration]) {
                            [self remoteLoggingTaskWithReason:reason];
                        }
                        
                        // run a script or application if configured
                        if (![self->_privilegesApp runActionAfterGrantOnly]) {
                            
                            if (completionHandler && [self->_privilegesApp postChangeExecutablePath]) {
                                
                                NSMutableArray *launchArguments = [NSMutableArray arrayWithObjects:
                                                                       [[self->_privilegesApp currentUser] userName],
                                                                       @"user",
                                                                       nil
                                ];
                                    
                                if ([self->_privilegesApp passReasonToExecutable]) { [launchArguments addObject:reason]; }
                                
                                [self launchExecutableAtPath:[self->_privilegesApp postChangeExecutablePath]
                                                   arguments:launchArguments
                                ];
                            }
                        }
                    }
                }
                
                self->_ignoreAdminGroupChanges = NO;
                
                if (completionHandler) { completionHandler(success); }
                
            }];
        }];
        
    } else {
        
        if (completionHandler) { completionHandler(NO); }
    }
}

- (void)renewAdminRightsWithCompletionHandler:(void(^)(BOOL success))completionHandler
{
    BOOL success = NO;
    
    if ([self userHasAdminPrivileges] && [_expirationTimer isValid]) {
            
        [self scheduleExpirationTimerWithInterval:[_privilegesApp expirationInterval] isSavedTimer:NO];
        success = YES;
    }
    
    [self displayNotificationOfType:(success) ? MTLocalNotificationTypeRenewSuccess : MTLocalNotificationTypeError];
    
    if (completionHandler) { completionHandler(success); }
    
}

- (void)authenticateUserWithCompletionHandler:(void(^)(BOOL success))completionHandler
{
    if (![[_privilegesApp currentUser] useIsRestricted]) {
                
        if ([_privilegesApp smartCardSupportEnabled]) {
            
            NSString *reasonString = [NSString localizedStringWithFormat:NSLocalizedString(@"authenticationTextPIV", nil), kMTAppName,
                                      [NSString localizedStringWithFormat:NSLocalizedString(@"authenticationText", nil), [[_privilegesApp currentUser] userName]]
            ];
            
            [MTIdentity authenticatePIVUserWithReason:reasonString
                                    completionHandler:^(BOOL success, NSError *error) {
                
                if (completionHandler) { completionHandler(success); }
            }];
            
        } else {
            
            NSString *reasonString = [NSString localizedStringWithFormat:NSLocalizedString(@"authenticationText", nil), [[_privilegesApp currentUser] userName]];
            
            [MTIdentity authenticateUserWithReason:reasonString
                                 requireBiometrics:[_privilegesApp biometricAuthenticationRequired]
                                 completionHandler:^(BOOL success, NSError *error) {
                
                if (completionHandler) { completionHandler(success); }
            }];
        }
        
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

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter*)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    completionHandler(UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler
{
    if ([[response actionIdentifier] isEqualToString:kMTNotificationActionIdentifierRenew]) {
        
        if ([_privilegesApp authenticationRequired] && [_privilegesApp renewalFollowsAuthSetting]) {
            
            [self authenticateUserWithCompletionHandler:^(BOOL success) {
                
                if (success) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self renewAdminRightsWithCompletionHandler:nil];
                    });
                }
            }];
            
        } else {
            
            [self renewAdminRightsWithCompletionHandler:nil];
        }
    }
    
    completionHandler();
}

@end
