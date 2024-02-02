/*
 AppDelegate.m
 Copyright 2016-2023 SAP SE
 
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
#import "MTIdentity.h"
#import "MTAuthCommon.h"
#import "Constants.h"
#import "MTNotification.h"
#import "MTVoiceOver.h"
#import "PrivilegesHelper.h"
#import "PrivilegesXPC.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <os/log.h>

@interface AppDelegate ()
@property (assign) AuthorizationRef authRef;
@property (atomic, copy, readwrite) NSData *authorization;
@property (atomic, strong, readwrite) NSXPCConnection *helperToolConnection;
@property (atomic, strong, readwrite) NSXPCConnection *xpcServiceConnection;
@property (atomic, strong, readwrite) NSMutableArray *toggleTimeouts;
@property (atomic, strong, readwrite) NSArray *keysToObserve;
@property (atomic, strong, readwrite) NSUserDefaults *userDefaults;
@property (atomic, strong, readwrite) NSTimer *fixTimeoutObserverTimer;
@property (atomic, strong, readwrite) NSTimer *fixEnforceObserverTimer;
@property (atomic, strong, readwrite) NSString *currentUser;
@property (atomic, strong, readwrite) NSString *adminReason;
@property (atomic, assign) NSUInteger minReasonLength;
@property (atomic, assign) NSUInteger maxReasonLength;
@property (atomic, assign) BOOL autoApplyPrivileges;

@property (weak) IBOutlet NSWindow *aboutWindow;
@property (weak) IBOutlet NSWindow *mainWindow;
@property (weak) IBOutlet NSWindow *prefsWindow;
@property (weak) IBOutlet NSWindow *reasonWindow;
@property (weak) IBOutlet NSButton *defaultButton;
@property (weak) IBOutlet NSButton *alternateButton;
@property (weak) IBOutlet NSTextField *notificationHead;
@property (weak) IBOutlet NSTextField *notificationBody;
@property (weak) IBOutlet NSButton *reasonButton;
@property (weak) IBOutlet NSTextField *reasonText;
@property (weak) IBOutlet NSTextField *reasonDescription;
@property (unsafe_unretained) IBOutlet NSTextView *aboutText;
@property (weak) IBOutlet NSTextField *appNameAndVersion;
@property (weak) IBOutlet NSPopUpButton *toggleTimeoutMenu;
@property (weak) IBOutlet NSToolbarItem *generalPrefsButton;
@property (weak) IBOutlet NSPopUpButton *predefinedReasonsMenu;
@property (weak) IBOutlet NSLayoutConstraint *reasonPopupHeight;
@property (weak) IBOutlet NSLayoutConstraint *reasonTextHeight;
@end

extern void CoreDockSendNotification(CFStringRef, void*);

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{    
    // check if we were launched because the user clicked one of our notifications.
    // if so, we just quit.
    NSUserNotification *userNotification = [[aNotification userInfo] objectForKey:NSApplicationLaunchUserNotificationKey];
    if (userNotification) {
        [NSApp terminate:self];
        
    } else {
        
        // get the name of the current user
        _currentUser = NSUserName();
        
        // initialize our userDefaults and remove an existing "EnforcePrivileges" key
        // form our plist. This key should just be used in a configuration profile.
        _userDefaults = [NSUserDefaults standardUserDefaults];
        [_userDefaults removeObjectForKey:kMTDefaultsEnforcePrivileges];

        // set the content of our "about" window
        NSString *creditsPath = [[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtfd"];
        [_aboutText readRTFDFromFile:creditsPath];
        [_aboutText setTextColor:[NSColor textColor]];
        
        // set app name and version for the "about" window
        NSString *appName = [[NSRunningApplication currentApplication] localizedName];
        NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        NSString *appBuild = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        [_appNameAndVersion setStringValue:[NSString stringWithFormat:@"%@ %@ (%@)", appName, appVersion, appBuild]];
                
        // set initial window positions
        NSRect screenRect = [[NSScreen mainScreen] visibleFrame];
        [_aboutWindow setFrameTopLeftPoint:(NSMakePoint(20 + screenRect.origin.x, screenRect.size.height - 20 + screenRect.origin.y))];
        [_prefsWindow setFrameTopLeftPoint:(NSMakePoint(20 + screenRect.origin.x, screenRect.size.height - 20 + screenRect.origin.y))];
        
        // create the initial timeout menu
        [self createTimeoutMenu];
        
        // create the menu with pre-defined reasons (if configured)
        if ([_userDefaults boolForKey:kMTDefaultsRequireReason]) {
            NSArray *predefinedReasons = [_userDefaults arrayForKey:kMTDefaultsReasonPresets];
        
            if (predefinedReasons && [predefinedReasons count] > 0) {
                
                NSMutableArray *allReasons = [[NSMutableArray alloc] init];
                NSString *languageCode = [[NSLocale currentLocale] languageCode];
                
                for (NSDictionary *aReason in predefinedReasons) {

                    if ([aReason isKindOfClass:[NSDictionary class]]) {
                        NSString *localizedReasonString = [aReason objectForKey:languageCode];
                        if (!localizedReasonString) { localizedReasonString = [aReason objectForKey:@"default"]; }
                        if (!localizedReasonString) { localizedReasonString = [aReason objectForKey:@"en"]; }
                        if (localizedReasonString) { [allReasons addObject:localizedReasonString]; }
                    }
                }
                
                if ([allReasons count] > 0) { [allReasons insertObject:NSLocalizedString(@"otherMenuEntry", nil) atIndex:0]; }
           
                for (NSString *aReason in allReasons) {
                     NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:aReason
                                                                       action:nil
                                                                keyEquivalent:@""];
                     [[_predefinedReasonsMenu menu] addItem:menuItem];
                }
                
                // make the menu visible
                [_reasonPopupHeight setConstant:22];
            }
        }
        
        // define the keys in our prefs we need to observe
        _keysToObserve = [[NSArray alloc] initWithObjects:
                          kMTDefaultsToggleTimeout,
                          kMTDefaultsToggleMaxTimeout,
                          kMTDefaultsEnforcePrivileges,
                          kMTDefaultsLimitToUser,
                          kMTDefaultsLimitToGroup,
                          nil
                          ];
        
        // Start observing our preferences to make sure we'll get notified as soon as someting changes (e.g. a configuration
        // profile has been installed). Unfortunately we cannot use the NSUserDefaultsDidChangeNotification here, because
        // it wouldn't be called if changes to our prefs would be made from outside this application.
        for (NSString *aKey in _keysToObserve) {
            [_userDefaults addObserver:self
                            forKeyPath:aKey
                               options:NSKeyValueObservingOptionNew
                               context:nil];
        }
        
        // make sure that we are frontmost
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        
        // observe if we are sent to background because in this case we'll not have to unhide other apps
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidDeactivateApplicationNotification
                                                                        object:nil
                                                                         queue:nil
                                                                    usingBlock:^(NSNotification *_Nonnull note) {
            [self->_userDefaults setBool:YES forKey:@"dontUnhideApps"];
        }];
           
        // hide all other windows (only if VoiceOver is disabled)
        if (![MTVoiceOver isEnabled]) {
            CoreDockSendNotification(CFSTR("com.apple.showdesktop.awake"), NULL);
        }
        
        // change privileges immediately if needed and if
        // privileges are enforced or just update our dialog
        if ([_userDefaults objectIsForcedForKey:kMTDefaultsEnforcePrivileges] && ([[self->_userDefaults stringForKey:kMTDefaultsEnforcePrivileges] isEqualToString:@"admin"] || [[self->_userDefaults stringForKey:kMTDefaultsEnforcePrivileges] isEqualToString:@"user"])) {
            _autoApplyPrivileges = YES;
            [self performSelectorOnMainThread:@selector(checkForHelper) withObject:nil waitUntilDone:NO];
        } else {
            _autoApplyPrivileges = NO;
        }
        
        [self createDialog];
    }
}

- (void)changeAdminGroup:(NSString*)userName remove:(BOOL)remove
{
    [self connectAndExecuteCommandBlock:^(NSError *connectError) {
        
          if (connectError) {
              os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: %{public}@", connectError);
              [self displayErrorNotificationAndExit];
              
          } else {
              
              [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
                  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: %{public}@", proxyError);
                  [self displayErrorNotificationAndExit];
                  
              }] changeAdminRightsForUser:userName
                                   remove:remove
                                   reason:self->_adminReason
                            authorization:self->_authorization
                                withReply:^(NSError *error) {
                  
                  if (error) {
                      os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Unable to change privileges: %{public}@", error);
                      [self displayErrorNotificationAndExit];
                
                  } else {
                  
                      if ( remove == FALSE ) {
                          [self installExpirationLaunchAgent];
                      } else {
                          [self removeExpirationLaunchAgentFile];
                      }

                      // send a notification to update the Dock tile
                      [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"corp.sap.PrivilegesChanged"
                                                                                     object:userName
                                                                                   userInfo:nil
                                                                                    options:NSNotificationDeliverImmediately
                       ];
                      
                      [self displaySuccessNotificationAndExit];
                  }
              }];
          }
    }];
}

- (void)checkForHelper
{
    // set the required helper version (this must match the app version)
    NSString *requiredVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];

    // create authorization reference
    AuthorizationExternalForm extForm;
    OSStatus err = AuthorizationCreate(NULL, NULL, 0, &self->_authRef);
    
    if (err == errAuthorizationSuccess) {
        err = AuthorizationMakeExternalForm(self->_authRef, &extForm);
    }
    
    if (err == errAuthorizationSuccess) {
        self.authorization = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
    }

    if (err == errAuthorizationSuccess && self->_authRef) {
        
        [self connectToXPCService];
        [[self.xpcServiceConnection remoteObjectProxy] setupAuthorizationRights];

        [self connectAndExecuteCommandBlock:^(NSError *connectError) {

            if (connectError) {
                [self performSelectorOnMainThread:@selector(helperCheckFailed:) withObject:connectError waitUntilDone:NO];
                
            } else {
                
                [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
                    [self performSelectorOnMainThread:@selector(helperCheckFailed:) withObject:proxyError waitUntilDone:NO];
                    
                }] helperVersionWithReply:^(NSString *helperVersion) {

                    if ([helperVersion isEqualToString:requiredVersion]) {
                        
                        // everything seems to be good, so set the privileges
                        [self performSelectorOnMainThread:@selector(setPrivileges) withObject:nil waitUntilDone:NO];
                        
                    } else {
                        NSString *errorMsg = [NSString stringWithFormat:@"Helper version mismatch (is %@, should be %@)", helperVersion, requiredVersion];
                        [self performSelectorOnMainThread:@selector(helperCheckFailed:) withObject:errorMsg waitUntilDone:NO];
                    }
                }];
            }
        }];
        
    } else {
    
        // display an error dialog and exit
        [self displayDialog:NSLocalizedString(@"notificationText_Error", nil)
                messageText:nil
          withDefaultButton:NSLocalizedString(@"okButton", nil)
         andAlternateButton:nil
         ];
    }
}

- (void)helperCheckFailed:(NSString*)errorMessage
{
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: %{public}@", errorMessage);
    
    [self connectToXPCService];
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
        
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: %{public}@", proxyError);
        
        [self displayDialog:NSLocalizedString(@"notificationText_Error", nil)
                messageText:nil
          withDefaultButton:NSLocalizedString(@"okButton", nil)
         andAlternateButton:nil
         ];
        
    }] installHelperToolWithReply:^(NSError *installError) {
        
        if (!installError) {
            
            os_log(OS_LOG_DEFAULT, "SAPCorp: The helper tool has been successfully installed");
            
            // check for the helper again
            [self performSelectorOnMainThread:@selector(checkForHelper) withObject:nil waitUntilDone:NO];
            
        } else {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Installation of the helper tool failed: %{public}@", installError);
            
            [self displayDialog:NSLocalizedString(@"notificationText_Error", nil)
                    messageText:nil
              withDefaultButton:NSLocalizedString(@"okButton", nil)
             andAlternateButton:nil
             ];
        }
    }];
}

- (void)createTimeoutMenu
{
    // remove all menu entries
    [[_toggleTimeoutMenu menu] removeAllItems];
    
    // define the default timeout
    NSInteger timeoutValue = kMTDockTimeoutDefault;
    
    // get the configured timeout
    if ([_userDefaults objectForKey:kMTDefaultsToggleTimeout]) {

        // get the currently configured timeout
        timeoutValue = [_userDefaults integerForKey:kMTDefaultsToggleTimeout];
        if (timeoutValue < 0) { timeoutValue = 0; }
        
        // disable the menu if the setting is managed
        [_toggleTimeoutMenu setEnabled:![_userDefaults objectIsForcedForKey:kMTDefaultsToggleTimeout]];
        
    } else {
        
        // write the default timeout to file
        [_userDefaults setValue:[NSNumber numberWithInteger:timeoutValue] forKey:kMTDefaultsToggleTimeout];
    }

    // check if the configured timeout has already an entry in our menu. if not,
    // add the new value
    _toggleTimeouts = [NSMutableArray arrayWithArray:kMTFixedTimeoutValues];
    
    if (![_toggleTimeouts containsObject:[NSNumber numberWithInteger:timeoutValue]]) {
        [_toggleTimeouts addObject:[NSNumber numberWithInteger:timeoutValue]];
    }
    
    // get the maximum timeout value (if configured)
    NSInteger maxTimeoutValue = 0;
    if ([_userDefaults objectForKey:kMTDefaultsToggleMaxTimeout] && ![_userDefaults objectIsForcedForKey:kMTDefaultsToggleTimeout]) {
        maxTimeoutValue = [_userDefaults integerForKey:kMTDefaultsToggleMaxTimeout];
        if (maxTimeoutValue > 0 && timeoutValue > maxTimeoutValue) { timeoutValue = maxTimeoutValue; }
        
        if (![_toggleTimeouts containsObject:[NSNumber numberWithInteger:maxTimeoutValue]]) {
            [_toggleTimeouts addObject:[NSNumber numberWithInteger:maxTimeoutValue]]; }
    }
    
    // sort the array
    NSSortDescriptor *sortAscending = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES];
    [_toggleTimeouts sortUsingDescriptors:[NSArray arrayWithObject:sortAscending]];
    
    for (NSNumber *predefinedTimeoutValue in _toggleTimeouts) {
        
        NSInteger predefinedTimeoutValueInt = [predefinedTimeoutValue integerValue];
        
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[self localizedTimeoutStringWithMinutes:predefinedTimeoutValueInt]
                                                          action:nil
                                                   keyEquivalent:@""];
        [menuItem setTag:predefinedTimeoutValueInt];
        [[_toggleTimeoutMenu menu] addItem:menuItem];
        
        if (maxTimeoutValue > 0 && ((predefinedTimeoutValueInt > maxTimeoutValue) || predefinedTimeoutValueInt == 0)) {
            [menuItem setEnabled:NO];
        } else {
            [menuItem setEnabled:YES];
            if (predefinedTimeoutValueInt <= timeoutValue) { [_toggleTimeoutMenu selectItemWithTag:predefinedTimeoutValueInt]; }
        }
    }
}

- (void)createDialog
// create the admin dialog
{
    // check if we are restricted
    NSString *enforcedPrivileges = ([_userDefaults objectIsForcedForKey:kMTDefaultsEnforcePrivileges]) ? [_userDefaults objectForKey:kMTDefaultsEnforcePrivileges] : nil;
    NSString *limitToUser = ([_userDefaults objectIsForcedForKey:kMTDefaultsLimitToUser]) ? [_userDefaults objectForKey:kMTDefaultsLimitToUser] : nil;
    NSString *limitToGroup = ([_userDefaults objectIsForcedForKey:kMTDefaultsLimitToGroup]) ? [_userDefaults objectForKey:kMTDefaultsLimitToGroup] : nil;
    
    // we just display a dialog and quit if one of the following applies:
    //
    // - EnforcePrivileges has been set to "none"
    // - LimitToUser has a nonnull value that does not match the current user
    // - LimitToGroup has a nonnull value and the current user is not a member of that group
    //
    // Please be aware that LimitToUser has a higher priority than LimitToGroup. So if
    // both attributes have been specified, the value of LimitToGroup is ignored.
    
    if ([enforcedPrivileges isEqualToString:@"none"] ||
        (limitToUser && ([limitToUser caseInsensitiveCompare:_currentUser] != NSOrderedSame)) ||
        (!limitToUser && limitToGroup && ![MTIdentity getGroupMembershipForUser:_currentUser groupName:limitToGroup error:nil])) {
        
        // display a dialog and exit
        [self displayDialog:NSLocalizedString(@"restrictedDialog1", nil)
                messageText:NSLocalizedString(@"restrictedDialog2None", nil)
          withDefaultButton:NSLocalizedString(@"okButton", nil)
         andAlternateButton:nil
         ];
        
    } else {

        // don't run this as root
        if (getuid() != 0) {
            
            NSError *userError = nil;
            BOOL isAdmin = [MTIdentity getGroupMembershipForUser:_currentUser groupID:kMTAdminGroupID error:&userError];
            
            if (userError) {
                
                // display an error dialog and exit if we were unable to check the group membership
                [self displayDialog:NSLocalizedString(@"notificationText_Error", nil)
                        messageText:nil
                  withDefaultButton:NSLocalizedString(@"okButton", nil)
                 andAlternateButton:nil
                 ];
                
            } else {
                
                if ([enforcedPrivileges isEqualToString:@"admin"] || [enforcedPrivileges isEqualToString:@"user"]) {
                                            
                    [self displayDialog:NSLocalizedString(@"restrictedDialog1", nil)
                            messageText:([enforcedPrivileges isEqualToString:@"admin"]) ? NSLocalizedString(@"restrictedDialog2Admin", nil) : NSLocalizedString(@"restrictedDialog2User", nil)
                      withDefaultButton:NSLocalizedString(@"okButton", nil)
                     andAlternateButton:nil
                     ];
                    
                } else {
                    
                    if (isAdmin) {
                        
                        [self displayDialog:NSLocalizedString(@"unsetDialog1", nil)
                                messageText:NSLocalizedString(@"unsetDialog2", nil)
                          withDefaultButton:NSLocalizedString(@"cancelButton", nil)
                         andAlternateButton:NSLocalizedString(@"removeButton", nil)
                         ];
                        
                    } else {
                        
                        [self displayDialog:NSLocalizedString(@"setDialog1", nil)
                                messageText:NSLocalizedString(@"setDialog2", nil)
                          withDefaultButton:NSLocalizedString(@"cancelButton", nil)
                         andAlternateButton:NSLocalizedString(@"requestButton", nil)
                         ];
                    }
                }
            }

        } else {
            
            // if the user is root, display an error dialog and exit
            [self displayDialog:NSLocalizedString(@"rootError", nil)
                    messageText:nil
              withDefaultButton:NSLocalizedString(@"okButton", nil)
             andAlternateButton:nil
             ];
        }
    }
}

- (void)setPrivileges
{
    BOOL isAdmin = [MTIdentity getGroupMembershipForUser:_currentUser groupID:kMTAdminGroupID error:nil];
    BOOL changeNeeded = YES;
    
    if (_autoApplyPrivileges) {
        NSString *enforcedPrivileges = [_userDefaults objectForKey:kMTDefaultsEnforcePrivileges];
        
        if (([enforcedPrivileges isEqualToString:@"admin"] && isAdmin) || ([enforcedPrivileges isEqualToString:@"user"] && !isAdmin)) {
            changeNeeded = NO;
        }
    }
    
    // change group membership
    if (changeNeeded) {
        
        // ask for the account password to grant admin rights
        if (!isAdmin && [_userDefaults boolForKey:kMTDefaultsAuthRequired] && !_autoApplyPrivileges) {
            
            [MTIdentity authenticateUserWithReason:NSLocalizedString(@"authenticationText", nil)
                                 completionHandler:^(BOOL success, NSError *error) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    if (success) {
                        [self changeAdminGroup:self->_currentUser remove:isAdmin];
                    } else {
                        [self displayNoChangeNotificationAndExit];
                    }
                });
            }];
            
        } else {
            [self changeAdminGroup:_currentUser remove:isAdmin];
        }
        
    } else {

        // send notification that nothing has changed and exit
        [self displayNoChangeNotificationAndExit];
    }
}

- (IBAction)reasonSelected:(id)sender
{
    if ([[_predefinedReasonsMenu selectedItem] isEqualTo:[_predefinedReasonsMenu itemAtIndex:0]]) {
        [_reasonText setStringValue:@""];
        [_reasonTextHeight setConstant:100];
        [_reasonButton setEnabled:NO];
    } else {
        [_reasonTextHeight setConstant:0];
        [_reasonButton setEnabled:YES];
    }
}

- (void)getReasonForNeedingAdminRightsWithCompletionHandler:(void (^) (NSString *reason))completionHandler
{
    // set the minimum text length
    if ([_userDefaults objectIsForcedForKey:kMTDefaultsReasonMinLength]) { _minReasonLength = [_userDefaults integerForKey:kMTDefaultsReasonMinLength]; }
    if (_minReasonLength < 1 || _minReasonLength >= kMTReasonMaxLengthDefault) { _minReasonLength = kMTReasonMinLengthDefault; }
    
    // set the maximum text length
    if ([_userDefaults objectIsForcedForKey:kMTDefaultsReasonMaxLength]) { _maxReasonLength = [_userDefaults integerForKey:kMTDefaultsReasonMaxLength]; }
    if (_maxReasonLength <= _minReasonLength || _maxReasonLength > kMTReasonMaxLengthDefault) { _maxReasonLength = kMTReasonMaxLengthDefault; }
    
    _adminReason = nil;
    
    NSString *minCharacters = nil;
    
    if (_minReasonLength == 1) {
        minCharacters = [NSString localizedStringWithFormat:NSLocalizedString(@"oneChar", nil), (long)_minReasonLength];
    } else {
        
        NSString *evenMoreThreshold = NSLocalizedString(@"evenMoreCharsThreshold", nil);
        
        if (evenMoreThreshold && _minReasonLength >= [evenMoreThreshold integerValue]) {
            minCharacters = [NSString localizedStringWithFormat:NSLocalizedString(@"evenMoreChars", nil), (long)_minReasonLength];
        } else {
            minCharacters = [NSString localizedStringWithFormat:NSLocalizedString(@"moreChars", nil), (long)_minReasonLength];
        }
    }
    
    if ([_reasonPopupHeight constant] > 0) {
        [_reasonDescription setStringValue:[NSString localizedStringWithFormat:NSLocalizedString(@"reasonDescriptionPredefined", nil), NSLocalizedString(@"otherMenuEntry", nil), minCharacters, (long)_minReasonLength]];
        [_predefinedReasonsMenu selectItemAtIndex:0];
    } else {
        [_reasonDescription setStringValue:[NSString localizedStringWithFormat:NSLocalizedString(@"reasonDescription", nil), minCharacters, (long)_minReasonLength]];
    }
    [_reasonText setStringValue:@""];
    [_mainWindow beginSheet:_reasonWindow
          completionHandler:^(NSModalResponse returnCode) {
        
        NSString *reasonString = nil;
        
        if (returnCode == NSModalResponseOK) {
            reasonString = ([self->_reasonTextHeight constant] == 0) ? [[self->_predefinedReasonsMenu selectedItem] title] : [self->_reasonText stringValue];
        }
        
        if (completionHandler) {

            if ([reasonString length] > 0) {
                completionHandler(reasonString);
            } else {
                completionHandler(nil);
            }
        }
    }];
}

- (IBAction)hideReasonSheet:(id)sender
{
    if ([[sender identifier] isEqualToString:@"corp.sap.button.continue"]) {
        [_mainWindow endSheet:_reasonWindow returnCode:NSModalResponseOK];
    } else {
        [_mainWindow endSheet:_reasonWindow returnCode:NSModalResponseCancel];
    }
}

- (void)controlTextDidChange:(NSNotification*)aNotification
{
    NSTextField *reasonText = [aNotification object];
    NSString *reasonTextString = [reasonText stringValue];

    if (reasonTextString && [reasonTextString length] >= _minReasonLength) {
        [_reasonButton setEnabled:YES];
        
        // we limit the number of characters here
        if ([reasonTextString length] > _maxReasonLength) {
               [_reasonText setStringValue:[reasonTextString substringWithRange:NSMakeRange(0, _maxReasonLength)]];
        }
        
    } else {
        [_reasonButton setEnabled:NO];
    }
}

- (void)displayDialog:(NSString* _Nonnull)messageTitle messageText:(NSString*)messageText withDefaultButton:(NSString* _Nonnull)defaultButtonText andAlternateButton:(NSString*)alternateButtonText
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // hide our dialog if currently visible
        if ([self->_mainWindow isVisible]) { [self->_mainWindow orderOut:self]; }
        
        NSString *accessibilityDialogLabel = messageTitle;
        [self->_notificationHead setStringValue:messageTitle];
        
        if (messageText) {
            accessibilityDialogLabel = [accessibilityDialogLabel stringByAppendingFormat:@", %@", messageText];
            [self->_notificationBody setStringValue:messageText];
            [self->_notificationBody setHidden:NO];
        } else {
            [self->_notificationBody setHidden:YES];
        }
        
        [self->_defaultButton setTitle:defaultButtonText];

        if (alternateButtonText) {
            [self->_alternateButton setTitle:alternateButtonText];
            [self->_alternateButton setHidden:NO];
        } else {
            [self->_alternateButton setHidden:YES];
        }
        
        // VoiceOver
        [self->_mainWindow setAccessibilityLabel:accessibilityDialogLabel];
        [self->_mainWindow setAccessibilityEnabled:YES];
        [self->_defaultButton setAccessibilityFocused:YES];
        
        // make sure that we are frontmost
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        
        // display our dialog
        [self->_mainWindow setLevel:NSScreenSaverWindowLevel];
        [self->_mainWindow setAnimationBehavior:NSWindowAnimationBehaviorAlertPanel];
        [self->_mainWindow setIsVisible:YES];
        [self->_mainWindow center];
        [self->_mainWindow makeKeyAndOrderFront:self];
    });
}

- (IBAction)popupButtonPressed:(id)sender
{
    // update the preference file for the selected timeout
    [_userDefaults setValue:[NSNumber numberWithInteger:[sender selectedTag]] forKey:kMTDefaultsToggleTimeout];
}

- (IBAction)actionButtonPressed:(id)sender
{
    if (_autoApplyPrivileges) {
        [_mainWindow orderOut:self];
        [NSApp terminate:self];
        
    } else {
            
        if ([[sender identifier] isEqualToString:@"corp.sap.button.default"] && !_autoApplyPrivileges) {
        
            // send notification that nothing has changed and exit
            [_mainWindow orderOut:self];
            [self displayNoChangeNotificationAndExit];
            
        } else {

            BOOL isAdmin = [MTIdentity getGroupMembershipForUser:_currentUser groupID:kMTAdminGroupID error:nil];

            if (!isAdmin && ([_userDefaults objectIsForcedForKey:kMTDefaultsRequireReason] && [_userDefaults boolForKey:kMTDefaultsRequireReason])) {
                
                [self getReasonForNeedingAdminRightsWithCompletionHandler:^(NSString *reason) {
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            if (reason) {
                                self->_adminReason = reason;
                                [self->_mainWindow orderOut:self];

                                [self performSelectorOnMainThread:@selector(checkForHelper) withObject:nil waitUntilDone:NO];
                            }
                        });
                    }];
                
            } else {
                
                // check for the helper (and the correct version)
                [_mainWindow orderOut:self];
                [self performSelectorOnMainThread:@selector(checkForHelper) withObject:nil waitUntilDone:NO];
            }
        }
    }
}

- (NSString*)localizedTimeoutStringWithMinutes:(NSInteger)timeoutMinutes
{
    NSString *timeoutString = NSLocalizedString(@"timeoutNever", nil);
    
    if (timeoutMinutes > 0) {
        
        if (timeoutMinutes == 1) {
            timeoutString = [NSString stringWithFormat:@"%ld %@", (long)timeoutMinutes, NSLocalizedString(@"timeoutMin", nil)];
            
        } else if (timeoutMinutes < 60) {
            timeoutString = [NSString stringWithFormat:@"%ld %@", (long)timeoutMinutes, NSLocalizedString(@"timeoutMins", nil)];
            
        } else if (timeoutMinutes/60 == 1) {
            timeoutString = [NSString stringWithFormat:@"%ld %@", (long)timeoutMinutes/60, NSLocalizedString(@"timeoutHour", nil)];
            
        } else {
            timeoutString = [NSString stringWithFormat:@"%ld %@", (long)timeoutMinutes/60, NSLocalizedString(@"timeoutHours", nil)];
        }
    }
    
    return timeoutString;
}

- (void)displayNoChangeNotificationAndExit
// Display a notification that nothing has changed and exit.
{
    [MTNotification sendNotificationWithTitle:NSLocalizedString(@"notificationHead", nil)
                                   andMessage:NSLocalizedString(@"notificationText_Nothing", nil)
                              replaceExisting:YES
                                     delegate:self];
    
    if (!_autoApplyPrivileges) {
        dispatch_async(dispatch_get_main_queue(), ^{ [NSApp terminate:self]; });
    }
}

- (void)displayErrorNotificationAndExit
// Display a notification if the operation failed and exit.
{
    [MTNotification sendNotificationWithTitle:NSLocalizedString(@"notificationHead", nil)
                                   andMessage:NSLocalizedString(@"notificationText_Error", nil)
                              replaceExisting:YES
                                     delegate:self];
    
    if (!_autoApplyPrivileges) {
        dispatch_async(dispatch_get_main_queue(), ^{ [NSApp terminate:self]; });
    }
}

- (void)displaySuccessNotificationAndExit
// Display a notification if the operation was successful and exit.
{
    [MTNotification sendNotificationWithTitle:NSLocalizedString(@"notificationHead", nil)
                                   andMessage:NSLocalizedString(@"notificationText_Success", nil)
                              replaceExisting:YES
                                     delegate:self];
    
    if (!_autoApplyPrivileges) {
        dispatch_async(dispatch_get_main_queue(), ^{ [NSApp terminate:self]; });
    }
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter*)center shouldPresentNotification:(NSUserNotification*)notification
// overwrite the method to ensure that the notification will be displayed
// even if our app is frontmost.
{
    return YES;
}

- (IBAction)showAboutWindow:(id)sender {
#pragma unused(sender)
    [_aboutWindow makeKeyAndOrderFront:self];
}

- (IBAction)showPrefsWindow:(id)sender {
#pragma unused(sender)

    // VoiceOver
    NSString *accessibilityDialogLabel = [NSLocalizedStringFromTable(@"msH-HV-PaS.title", @"MainMenu", nil) stringByAppendingFormat:@", %@", NSLocalizedStringFromTable(@"FfT-JO-Ift.title", @"MainMenu", nil)];
    [_prefsWindow setAccessibilityLabel:accessibilityDialogLabel];
    [_prefsWindow setAccessibilityEnabled:YES];
    if (@available(macOS 10.16, *)) {
        [_prefsWindow setToolbarStyle:NSWindowToolbarStylePreference];
        [_generalPrefsButton setImage:[NSImage imageWithSystemSymbolName:@"gearshape"
                                                accessibilityDescription:NSLocalizedStringFromTable(@"Vpc-6G-g1s.label", @"MainMenu", nil)]];
    }

    [_prefsWindow makeKeyAndOrderFront:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _userDefaults && ([keyPath isEqualToString:kMTDefaultsToggleTimeout] ||
                                    [keyPath isEqualToString:kMTDefaultsToggleMaxTimeout])) {

        // workaround for bug that is causing observeValueForKeyPath to be called multiple times.
        // so every notification resets the timer and if we got no new notifications for 2 seconds,
        // we evaluate the changes.
        if (_fixTimeoutObserverTimer) { [_fixTimeoutObserverTimer invalidate]; };
        _fixTimeoutObserverTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                                   repeats:NO
                                                                     block:^(NSTimer* _Nonnull timer) {
            // update the timeout menu
            [self createTimeoutMenu];
         }];
        
    } else if (object == _userDefaults && ([keyPath isEqualToString:kMTDefaultsEnforcePrivileges] ||
                                           [keyPath isEqualToString:kMTDefaultsLimitToUser] ||
                                           [keyPath isEqualToString:kMTDefaultsLimitToGroup])) {
        
        // workaround for bug that is causing observeValueForKeyPath to be called multiple times.
        // so every notification resets the timer and if we got no new notifications for 2 seconds,
        // we evaluate the changes.
        if (_fixEnforceObserverTimer) { [_fixEnforceObserverTimer invalidate]; };
        _fixEnforceObserverTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                                   repeats:NO
                                                                     block:^(NSTimer* _Nonnull timer) {
            // change privileges immediately if needed and if
            // privileges are enforced or just update our dialog
            if ([self->_userDefaults objectIsForcedForKey:kMTDefaultsEnforcePrivileges] && ([[self->_userDefaults stringForKey:kMTDefaultsEnforcePrivileges] isEqualToString:@"admin"] || [[self->_userDefaults stringForKey:kMTDefaultsEnforcePrivileges] isEqualToString:@"user"])) {
                self->_autoApplyPrivileges = YES;
                [self performSelectorOnMainThread:@selector(checkForHelper) withObject:nil waitUntilDone:NO];
            } else {
                self->_autoApplyPrivileges = NO;
            }

            [self createDialog];
         }];
    }
}

-(void)applicationWillTerminate:(NSNotification *)aNotification
{
#pragma unused(aNotification)
    
    // quit the helper tool
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        
           if (connectError) {
               os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: %{public}@", connectError);
           } else {
               
               [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
                   os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: %{public}@", proxyError);
               }] quitHelperTool];
           }
       }
     ];
    
    // remove our observers
    for (NSString *aKey in _keysToObserve) { [_userDefaults removeObserver:self forKeyPath:aKey]; }
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    
    // unhide the other applications if needed
    if (![MTVoiceOver isEnabled]) {
        if ([_userDefaults boolForKey:@"dontUnhideApps"]) {
            [_userDefaults removeObjectForKey:@"dontUnhideApps"];
        } else {
            CoreDockSendNotification(CFSTR("com.apple.expose.front.awake"), NULL);
        }
    }
}

- (void)connectToXPCService
    // Ensures that we're connected to our XPC service.
{
    assert([NSThread isMainThread]);
    if (self.xpcServiceConnection == nil) {
        self.xpcServiceConnection = [[NSXPCConnection alloc] initWithServiceName:kXPCServiceName];
        self.xpcServiceConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(PrivilegesXPCProtocol)];
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-retain-cycles"
        // We can ignore the retain cycle warning because a) the retain taken by the
        // invalidation handler block is released by us setting it to nil when the block
        // actually runs, and b) the retain taken by the block passed to -addOperationWithBlock:
        // will be released when that operation completes and the operation itself is deallocated
        // (notably self does not have a reference to the NSBlockOperation).
        self.xpcServiceConnection.invalidationHandler = ^{
            // If the connection gets invalidated then, on the main thread, nil out our
            // reference to it.  This ensures that we attempt to rebuild it the next time around.
            self.xpcServiceConnection.invalidationHandler = nil;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.xpcServiceConnection = nil;
                os_log(OS_LOG_DEFAULT, "SAPCorp: XPC connection invalidated");
            }];
        };
        #pragma clang diagnostic pop
        [self.xpcServiceConnection resume];
    }
}

- (void)connectToHelperToolEndpoint:(NSXPCListenerEndpoint *)endpoint
    // Ensures that we're connected to our helper tool.
{
    assert([NSThread isMainThread]);
    if (self.helperToolConnection == nil) {
        self.helperToolConnection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
        self.helperToolConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-retain-cycles"
        self.helperToolConnection.invalidationHandler = ^{
            // If the connection gets invalidated then, on the main thread, nil out our
            // reference to it.  This ensures that we attempt to rebuild it the next time around.
            //
            // We can ignore the retain cycle warning for the reasons discussed in -connectToXPCService.
            self.helperToolConnection.invalidationHandler = nil;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.helperToolConnection = nil;
                os_log(OS_LOG_DEFAULT, "SAPCorp: Helper tool connection invalidated");
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
    if (self.helperToolConnection != nil) {
        // The helper tool connection is already in place, so we can just call the
        // command block directly.
        commandBlock(nil);
    } else {
        // There's no helper tool connection in place.  Create on XPC service and ask
        // it to give us an endpoint for the helper tool.
        [self connectToXPCService];
        [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                commandBlock(proxyError);
            }];
        }] connectWithEndpointAndAuthorizationReply:^(NSXPCListenerEndpoint *connectReplyEndpoint, NSData *connectReplyAuthorization) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                if (connectReplyEndpoint == nil) {
                    commandBlock([NSError errorWithDomain:NSPOSIXErrorDomain code:ENOTTY userInfo:nil]);
                } else {
                    // The XPC service gave us an endpoint for the helper tool.  Create a connection from that.
                    // Also, save the authorization information returned by the helper tool so that the command
                    // block can send requests that act like they're coming from the XPC service (which is allowed
                    // to use authorization services) and not the app (which isn't, 'cause it's sandboxed).
                    //
                    // It's important to realize that self.helperToolConnection could be non-nil here because some
                    // other command has connected ahead of us.  That's OK though, -connectToHelperToolEndpoint:
                    // will just ignore the new endpoint and keep using the helper tool connection that's in place.
                    [self connectToHelperToolEndpoint:connectReplyEndpoint];
                    self.authorization = connectReplyAuthorization;
                    commandBlock(nil);
                }
            }];
        }];
    }
}

-(void)installExpirationLaunchAgent {
    // installs an LaunchAgent for the current user which will be called at timeout expiration time or whenever the daemon is loaded
    // - the StartCalendarInterval covers regular computer use as well as sleep periods
    // - the RunAtLoad covers reboots or shutdowns. This is why we also need hasPrivilegeToggleTimeoutExpired to evaluate the timeout
    long timeoutValue = 0;
    if ([_userDefaults objectForKey:kMTDefaultsToggleTimeout]) {
        // get the currently configured timeout
        timeoutValue = [_userDefaults integerForKey:kMTDefaultsToggleTimeout];
        if (timeoutValue < 0) { timeoutValue = 0; }
    }

    // calculate expiration date
    NSDate *dt = [NSDate date];
    dt = [dt dateByAddingTimeInterval:timeoutValue*60];
    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *weekdayComponents =
    [gregorian components:(NSCalendarUnitDay |
                           NSCalendarUnitMonth|
                           NSCalendarUnitHour |
                           NSCalendarUnitMinute
                           ) fromDate:dt];
    NSString *cliPath = [[NSBundle mainBundle] pathForResource:@"PrivilegesCLI" ofType:nil];
    NSArray *programArguments = @[cliPath, @"--expire"];
    NSDictionary *startCalendarInterval = @{
         @"Month" : [NSNumber numberWithInteger:[weekdayComponents month]],
           @"Day" : [NSNumber numberWithInteger:[weekdayComponents day]],
          @"Hour" : [NSNumber numberWithInteger:[weekdayComponents hour]],
        @"Minute" : [NSNumber numberWithInteger:[weekdayComponents minute]]
    };
    // prepare LaunchAgent definition
    NSMutableDictionary *plistDict = [[NSMutableDictionary alloc] init];
    [plistDict setObject:@"corp.sap.privileges.expire" forKey: @"Label"];
    [plistDict setObject:@YES forKey: @"RunAtLoad"];
    [plistDict setObject:programArguments forKey: @"ProgramArguments"];
    [plistDict setObject:startCalendarInterval forKey: @"StartCalendarInterval"];
    
    NSString *launchAgentDirectoryPath = [NSString stringWithFormat:@"%@/Library/LaunchAgents", NSHomeDirectory()];
    NSString *launchAgentPath = [NSString stringWithFormat:@"%@/corp.sap.privileges.expire.plist", launchAgentDirectoryPath];
    dispatch_async(dispatch_get_main_queue(), ^{
        // remove older LaunchAgent instances
        if ([[NSFileManager defaultManager] fileExistsAtPath:launchAgentPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:launchAgentPath error:nil];
        }
        [[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:[NSArray arrayWithObjects:@"remove", @"corp.sap.privileges.expire", nil]] waitUntilExit];
        if ( timeoutValue > 0 ) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:launchAgentDirectoryPath]) {
                // create ~/Library/LaunchAgents
                [[NSFileManager defaultManager] createDirectoryAtPath:launchAgentDirectoryPath withIntermediateDirectories:NO attributes:nil error:nil];
            }
            // create and load LaunchAgent for current user
            [plistDict writeToFile:launchAgentPath atomically:YES];
            [[NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:[NSArray arrayWithObjects:@"load", launchAgentPath, nil]] waitUntilExit];
        }
    });
}

-(void)removeExpirationLaunchAgentFile
{
    // Clean up by simply removing the LaunchAgent plist to prevent future RunAtLoad executions.
    // Once it has been run it would not be executed again, so we do not need to unload ourselves (which would need a separate process waiting for us to terminate).
    NSString *launchAgentPath = [NSString stringWithFormat:@"%@/Library/LaunchAgents/corp.sap.privileges.expire.plist", NSHomeDirectory()];
    if ([[NSFileManager defaultManager] fileExistsAtPath:launchAgentPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:launchAgentPath error:nil];
    }
}

@end
