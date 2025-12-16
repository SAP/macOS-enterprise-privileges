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
#import "MTReasonAccessoryController.h"
#import "MTLocalNotification.h"
#import "Constants.h"

@interface AppDelegate ()
@property (nonatomic, strong, readwrite) NSWindowController *settingsWindowController;
@property (nonatomic, strong, readwrite) MTPrivileges *privilegesApp;
@property (nonatomic, strong, readwrite) MTReasonAccessoryController *accessoryController;
@property (nonatomic, strong, readwrite) NSOperationQueue *operationQueue;
@property (nonatomic, strong, readwrite) NSAlert *alert;
@property (nonatomic, strong, readwrite) NSEvent *eventMonitor;
@property (retain) id configurationObserver;
@property (retain) id privilegesObserver;
@property (assign) NSUInteger minReasonLength;
@property (assign) NSUInteger maxReasonLength;
@property (assign) BOOL enableRequestButton;
@property (assign) BOOL authSuccess;
@end

extern void CoreDockSendNotification(CFStringRef, void*);

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification 
{
    // load the settings controller to make sure all interface
    // elements are updated (especially those elements that belong
    // to a daemon connection) when the user accesses the settings
    // for the first time
    if (!_settingsWindowController) {
        
        NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
        _settingsWindowController = [storyboard instantiateControllerWithIdentifier:@"corp.sap.Privileges.SettingsController"];
    }
            
    if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--showSettings"]) {
        
        [self showSettingsWindow];
        
    } else {
        
        _privilegesApp = [[MTPrivileges alloc] init];
        
        if (!_privilegesApp) {
            
            _alert = [[NSAlert alloc] init];
            [_alert setMessageText:NSLocalizedString(@"fatalErrorDialogTitle", nil)];
            [_alert addButtonWithTitle:NSLocalizedString(@"okButton", nil)];
            [_alert setAlertStyle:NSAlertStyleCritical];
            [_alert runModal];
            [NSApp terminate:self];
            
        } else {
            
            _operationQueue = [[NSOperationQueue alloc] init];
            
            _minReasonLength = [_privilegesApp reasonMinLength];
            _maxReasonLength = [_privilegesApp reasonMaxLength];
            
            _configurationObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:kMTNotificationNameConfigDidChange
                                                                                                  object:nil
                                                                                                   queue:nil
                                                                                              usingBlock:^(NSNotification *notification) {
                
                NSDictionary *userInfo = [notification userInfo];
                
                if (userInfo) {
                    
                    NSString *changedKey = [userInfo objectForKey:kMTNotificationKeyPreferencesChanged];
                    NSArray *keysToObserve = [[NSArray alloc] initWithObjects:
                                              kMTDefaultsEnforcePrivilegesKey,
                                              kMTDefaultsLimitToUserKey,
                                              kMTDefaultsLimitToGroupKey,
                                              nil
                    ];
                    
                    if (changedKey && [keysToObserve containsObject:changedKey]) {
                        
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            
                            if (![[self->_settingsWindowController window] isVisible]) {
                                
                                [[self->_alert window] close];
                                [self showMainWindow];
                            }
                        });
                    }
                }
            }];
            
            _privilegesObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:kMTNotificationNamePrivilegesDidChange
                                                                                               object:nil
                                                                                                queue:nil
                                                                                           usingBlock:^(NSNotification *notification) {
                
                if ([self->_alert window]) { [NSApp endSheet:[self->_alert window]]; }
                [self showMainWindow];
            }];
            
            [self showMainWindow];
        }
    }
}

- (void)showMainWindow
{
    // hide all other windows (only if VoiceOver is disabled)
    if ([_privilegesApp hideOtherWindows] &&
        ![[NSWorkspace sharedWorkspace] isVoiceOverEnabled] &&
        ![[NSUserDefaults standardUserDefaults] boolForKey:kMTDefaultsUnhideOtherWindowsKey]) {
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kMTDefaultsUnhideOtherWindowsKey];
        CoreDockSendNotification(CFSTR("com.apple.showdesktop.awake"), NULL);
    }
    
#pragma mark - Build dialog
    
    BOOL hasAdminRights = [[_privilegesApp currentUser] hasAdminPrivileges];
    __block BOOL renewAdminPrivileges = NO;
    
    _alert = [[NSAlert alloc] init];
    
    // don't run this as root
    if (getuid() == 0) {
        
        [_alert setMessageText:NSLocalizedString(@"rootDialogTitle", nil)];
        [_alert addButtonWithTitle:NSLocalizedString(@"okButton", nil)];
        [_alert setAlertStyle:NSAlertStyleCritical];
        
    }  else if ([[_privilegesApp currentUser] useIsRestricted]) {
        
        NSString *enforcedPrivileges = [_privilegesApp enforcedPrivilegeType];
        
        [_alert setMessageText:NSLocalizedString(@"restrictedDialogTitle", nil)];
        
        if ([enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeAdmin] ||
            [enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeUser]) {
            
            [_alert setInformativeText:([enforcedPrivileges isEqualToString:kMTEnforcedPrivilegeTypeAdmin]) ?
             NSLocalizedString(@"restrictedDialogMessageAdmin", nil) :
                 NSLocalizedString(@"restrictedDialogMessageUser", nil)
            ];
            
        } else {
            
            [_alert setInformativeText:NSLocalizedString(@"restrictedDialogMessage", nil)];
        }
        
        [_alert addButtonWithTitle:NSLocalizedString(@"okButton", nil)];
        [_alert setAlertStyle:NSAlertStyleCritical];
        
    } else {
        
        if (hasAdminRights) {
            
            [_alert setMessageText:NSLocalizedString(@"privilegesDialogRemoveTitle", nil)];
            [_alert setInformativeText:NSLocalizedString(@"privilegesDialogRemoveMessage", nil)];
            NSButton *removeButton = [_alert addButtonWithTitle:NSLocalizedString(@"removeButton", nil)];
            
            if ([_privilegesApp privilegeRenewalAllowed] && [_privilegesApp expirationInterval] > 0 && ![[_privilegesApp currentUser] hasUnexpectedPrivilegeState]) {
                
                _eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskFlagsChanged handler:^NSEvent *(NSEvent *event) {

                    if ([event modifierFlags] & NSEventModifierFlagOption) {
                        
                        [self->_alert setMessageText:NSLocalizedString(@"privilegesDialogRenewTitle", nil)];
                        [self->_alert setInformativeText:[NSString localizedStringWithFormat:NSLocalizedString(@"privilegesDialogRenewMessage", nil), [MTPrivileges stringForDuration:[self->_privilegesApp expirationInterval]
                                                                                                                                                                            localized:YES
                                                                                                                                                                         naturalScale:NO
                                                                                                                                                      ]
                                                         ]
                        ];
                        [removeButton setTitle:NSLocalizedString(@"renewButton", nil)];
                        renewAdminPrivileges = YES;
                        
                    } else {
                        
                        [self->_alert setMessageText:NSLocalizedString(@"privilegesDialogRemoveTitle", nil)];
                        [self->_alert setInformativeText:NSLocalizedString(@"privilegesDialogRemoveMessage", nil)];
                        [removeButton setTitle:NSLocalizedString(@"removeButton", nil)];
                        renewAdminPrivileges = NO;
                    }
                    
                    [self->_alert layout];
                    
                    return event;
                }];
            }
            
        } else {
            
            NSString *autoRemoveText = @"";
            
            if ([_privilegesApp expirationInterval] > 0) {
                
                autoRemoveText = [NSString localizedStringWithFormat:NSLocalizedString(@"privilegesDialogRequestTimeoutMessage", nil), [MTPrivileges stringForDuration:[_privilegesApp expirationInterval]
                                                                                                                                                             localized:YES
                                                                                                                                                          naturalScale:NO
                                                                                                                                       ]
                ];
                autoRemoveText = [@" " stringByAppendingString:autoRemoveText];
            }
            
            [_alert setMessageText:NSLocalizedString(@"privilegesDialogRequestTitle", nil)];
            NSButton *requestButton = [_alert addButtonWithTitle:NSLocalizedString(@"requestButton", nil)];
            [requestButton bind:NSEnabledBinding toObject:self withKeyPath:@"self.enableRequestButton" options:nil];
            [requestButton setHasDestructiveAction:YES];
            
            if ([_privilegesApp reasonRequired]) {

                // load the nib file
                _accessoryController = [[MTReasonAccessoryController alloc] initWithNibName:@"MTReasonAccessory" bundle:nil];
                
                NSView *accessoryView = [_accessoryController view];
                [[_accessoryController reasonTextField] setDelegate:self];
                [[[_accessoryController predefinedReasonsButton] menu] setDelegate:self];
                [accessoryView setFrameSize:NSMakeSize(
                                                       NSWidth([[_alert window] frame]),
                                                       NSHeight([accessoryView frame])
                                                       )
                ];
                [_alert setAccessoryView:accessoryView];

                if ([[_accessoryController predefinedReasonsButton] isHidden]) {
                    
                    [_alert setInformativeText:[NSLocalizedString(@"privilegesDialogRequestMessageReason", nil) stringByAppendingString:autoRemoveText]];
                    
                    self.enableRequestButton = ([[[_accessoryController reasonTextField] stringValue] length] >= _minReasonLength);
                                        
                } else {
                    
                    [_alert setInformativeText:[NSLocalizedString(@"privilegesDialogRequestMessageReasonPre", nil) stringByAppendingString:autoRemoveText]];
                    
                    if ([[_accessoryController predefinedReasonsButton] indexOfSelectedItem] == 0) {
                        
                        self.enableRequestButton = ([[[_accessoryController reasonTextField] stringValue] length] >= _minReasonLength);
                        
                    } else {
                        
                        self.enableRequestButton = YES;
                    }
                }
                
            } else {
                
                [_alert setInformativeText:[NSLocalizedString(@"privilegesDialogRequestMessage", nil) stringByAppendingString:autoRemoveText]];
                self.enableRequestButton = YES;
            }
        }
        
        if (![_privilegesApp hideSettingsButton]) { [_alert addButtonWithTitle:NSLocalizedString(@"settingsButton", nil)]; }
        NSButton *cancelButton = [_alert addButtonWithTitle:NSLocalizedString(@"cancelButton", nil)];
        [_alert setAlertStyle:NSAlertStyleInformational];
        if (![[NSWorkspace sharedWorkspace] isVoiceOverEnabled] && ![_privilegesApp hideHelpButton]) { [_alert setShowsHelp:YES]; }
        [_alert setDelegate:self];
        
        // VoiceOver
        [[_alert window] setAccessibilityLabel:kMTAppName];
        [[_alert window] setAccessibilityEnabled:YES];
        
        if ([_alert accessoryView]) {
            
            [_alert layout];
            NSRect accRectInWindow = [[_alert accessoryView] convertRect:[[_alert accessoryView] frame] toView:nil];
            [[_alert accessoryView] setFrameSize:NSMakeSize(
                                                            NSWidth([[_alert window] frame]) - NSMinX(accRectInWindow) - 20,
                                                            NSHeight([[_alert accessoryView] frame])
                                                            )
            ];
            
            // make sure the text field is selected
            [cancelButton setRefusesFirstResponder:YES];
        }
    }

    // workaround for FB15426079 (https://github.com/SAP/macOS-enterprise-privileges/issues/128)
    [_alert layout];
    NSWindow *transparentDummyWindow = [[NSWindow alloc] initWithContentRect:[[_alert window] frame]
                                                                   styleMask:NSWindowStyleMaskBorderless
                                                                     backing:NSBackingStoreBuffered
                                                                       defer:NO
    ];
    [transparentDummyWindow setAccessibilityElement:NO];
    [transparentDummyWindow setAlphaValue:0];
    [transparentDummyWindow setReleasedWhenClosed:NO];
    [transparentDummyWindow center];

    [_alert beginSheetModalForWindow:transparentDummyWindow
                   completionHandler:^(NSModalResponse returnCode) {

        // remove the event monitor
        if (self->_eventMonitor) {
            
            [NSEvent removeMonitor:self->_eventMonitor];
            self->_eventMonitor = nil;
        }
        
        // remove the privilege observer
        if (returnCode != NSModalResponseStop && returnCode != NSModalResponseAbort) {

            [[NSDistributedNotificationCenter defaultCenter] removeObserver:self->_privilegesObserver];
            self->_privilegesObserver = nil;
        }
        
        if ([self->_alert alertStyle] == NSAlertStyleInformational) {
            
            if (returnCode == NSAlertFirstButtonReturn) {
              
#pragma mark - Remove admin rights
                
                // remove privileges if the user is admin…
                if (hasAdminRights && !renewAdminPrivileges) {
                    
                    [[self->_privilegesApp currentUser] revokeAdminPrivilegesWithCompletionHandler:^(BOOL success) {
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [NSApp terminate:self];
                        });
                    }];
                    
                // …otherwise, check if we can grant admin privileges
                } else {
                    
#pragma mark - Authentication
                    
                    NSBlockOperation *authOperation = [[NSBlockOperation alloc] init];
                    [authOperation addExecutionBlock:^{
                        
                        if (([self->_privilegesApp authenticationRequired] && !renewAdminPrivileges) ||
                            ([self->_privilegesApp authenticationRequired] && renewAdminPrivileges && [self->_privilegesApp renewalFollowsAuthSetting])) {
                            
                            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                            self->_authSuccess = NO;
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                
                                [[self->_privilegesApp currentUser] authenticateWithCompletionHandler:^(BOOL success, NSError *error) {
                                    
                                    self->_authSuccess = success;
                                    dispatch_semaphore_signal(semaphore);
                                }];
                            });
                            
                            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                            
                        } else {
                            
                            self->_authSuccess = YES;
                        }
                    }];
            
#pragma mark - Grant admin rights
                    
                    NSBlockOperation *adminOperation = [[NSBlockOperation alloc] init];
                    [adminOperation addExecutionBlock:^{
                        
                        if (self->_authSuccess) {
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                
                                if (renewAdminPrivileges) {
                                    
                                    [[self->_privilegesApp currentUser] renewAdminPrivilegesWithCompletionHandler:^(BOOL success) {
                                      
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [NSApp terminate:self];
                                        });
                                    }];
                                    
                                } else {
                                    
                                    NSString *reason = nil;
                                    
                                    if ([self->_privilegesApp reasonRequired]) {
                                        
                                        reason = ([[self->_accessoryController reasonTextField] isEnabled]) ?
                                        [[self->_accessoryController reasonTextField] stringValue] :
                                        [[[self->_accessoryController predefinedReasonsButton] selectedItem] title];
                                    }
                                    
                                    [[self->_privilegesApp currentUser] requestAdminPrivilegesWithReason:reason
                                                                                       completionHandler:^(BOOL success) {
                                        
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [NSApp terminate:self];
                                        });
                                    }];
                                }
                            });
                            
                        } else {
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [NSApp terminate:self];
                            });
                        }
                    }];
                    
                    [adminOperation addDependency:authOperation];
                    [self->_operationQueue addOperations:[NSArray arrayWithObjects:authOperation, adminOperation, nil]
                                       waitUntilFinished:NO
                    ];
                }
      
            } else if (returnCode == NSAlertSecondButtonReturn && ![self->_privilegesApp hideSettingsButton]) {
                
                [self showSettingsWindow];
                
            } else if (returnCode != NSModalResponseStop && returnCode != NSModalResponseAbort) {
                
                [NSApp terminate:self];
            }
            
        } else {
            
            [NSApp terminate:self];
        }
        
        [transparentDummyWindow close];
    }];
}

- (BOOL)alertShowHelp:(NSAlert *)alert
{
    NSURL *helpButtonURL = [_privilegesApp helpButtonURL];
    
    if (helpButtonURL) {
        
        [[NSWorkspace sharedWorkspace] openURL:helpButtonURL];
        
    } else {
        
        [self openGitHub:nil];
    }
    
    return YES;
}

- (IBAction)openGitHub:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kMTGitHubURL]];
}

- (void)showSettingsWindow
{
    if (![[[NSProcessInfo processInfo] arguments] containsObject:@"--showSettings"] &&
        [[NSUserDefaults standardUserDefaults] boolForKey:kMTDefaultsUnhideOtherWindowsKey]) {
        CoreDockSendNotification(CFSTR("com.apple.expose.front.awake"), NULL);
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kMTDefaultsUnhideOtherWindowsKey];
    }
    
    [_settingsWindowController showWindow:nil];
    [[_settingsWindowController window] makeKeyAndOrderFront:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsWindowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:[_settingsWindowController window]
    ];
}

- (void)settingsWindowWillClose:(NSNotification*)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSWindowWillCloseNotification
                                                  object:[_settingsWindowController window]
    ];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--showSettings"]) {
            
            [NSApp terminate:self];
            
        } else {
            
            [self showMainWindow];
        }
    });
    
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification*)aNotification
{
    NSTextField *reasonTextField = [aNotification object];
    NSString *cleanedReasonString = [_privilegesApp cleanedReasonStringWithString:[reasonTextField stringValue]];

    if ([cleanedReasonString length] >= _minReasonLength) {
                
        // we limit the number of characters here
        if ([cleanedReasonString length] > _maxReasonLength) {

            cleanedReasonString = [cleanedReasonString substringWithRange:NSMakeRange(0, _maxReasonLength)];
            [reasonTextField setStringValue:cleanedReasonString];
        }
        
        self.enableRequestButton = [_privilegesApp checkReasonString:cleanedReasonString];
        
    } else {
        
        self.enableRequestButton = NO;
    }
}

#pragma mark - NSMenuDelegate

- (void)menuDidClose:(NSMenu *)menu
{
    if ([[_accessoryController predefinedReasonsButton] indexOfSelectedItem] == 0) {
        
        self.enableRequestButton = ([[[_accessoryController reasonTextField] stringValue] length] >= _minReasonLength);
        
    } else {
        
        self.enableRequestButton = YES;
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kMTDefaultsUnhideOtherWindowsKey];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:_configurationObserver];
    _configurationObserver = nil;
    
    // unhide the other applications if needed
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kMTDefaultsUnhideOtherWindowsKey]) {
        CoreDockSendNotification(CFSTR("com.apple.expose.front.awake"), NULL);
    }
        
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kMTDefaultsUnhideOtherWindowsKey];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app 
{
    return YES;
}

@end
