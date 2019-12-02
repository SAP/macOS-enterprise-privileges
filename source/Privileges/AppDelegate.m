/*
 AppDelegate.m
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

#import "AppDelegate.h"
#import "MTIdentity.h"
#import "MTAuthCommon.h"
#import "MTNotification.h"
#import "PrivilegesHelper.h"

@interface AppDelegate ()
@property (assign) AuthorizationRef authRef;
@property (atomic, copy, readwrite) NSData *authorization;
@property (atomic, strong, readwrite) NSXPCConnection *helperToolConnection;
@property (nonatomic, strong, readwrite) NSArray *toggleTimeouts;
@property (atomic, strong, readwrite) NSUserDefaults *userDefaults;
@property (atomic, strong, readwrite) NSTimer *fixTimeoutObserverTimer;
@property (atomic, strong, readwrite) NSTimer *fixEnforceObserverTimer;
@property (assign) BOOL autoApplyPrivileges;

@property (weak) IBOutlet NSWindow *aboutWindow;
@property (weak) IBOutlet NSWindow *mainWindow;
@property (weak) IBOutlet NSWindow *prefsWindow;
@property (weak) IBOutlet NSButton *defaultButton;
@property (weak) IBOutlet NSButton *alternateButton;
@property (weak) IBOutlet NSTextField *notificationHead;
@property (weak) IBOutlet NSTextField *notificationBody;
@property (unsafe_unretained) IBOutlet NSTextView *aboutText;
@property (weak) IBOutlet NSTextField *appNameAndVersion;
@property (weak) IBOutlet NSPopUpButton *toggleTimeoutMenu;
@property (nonatomic, assign) NSInteger timeoutValue;
@property (nonatomic, assign) BOOL alwaysTimeout;
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
        
        // initialize our userDefaults and remove an existing "EnforcePrivileges" key
        // form our plist. This key should just be used in a configuration profile.
        _userDefaults = [NSUserDefaults standardUserDefaults];
        [_userDefaults removeObjectForKey:@"EnforcePrivileges"];

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
        
        // Start observing our preferences to make sure we'll get notified as soon as someting changes (e.g. a configuration
        // profile has been installed). Unfortunately we cannot use the NSUserDefaultsDidChangeNotification here, because
        // it wouldn't be called if changes to our prefs would be made from outside this application.
        [_userDefaults addObserver:self
                        forKeyPath:@"DockToggleTimeout"
                           options:NSKeyValueObservingOptionNew
                           context:nil];
        
        [_userDefaults addObserver:self
                        forKeyPath:@"EnforcePrivileges"
                           options:NSKeyValueObservingOptionNew
                           context:nil];
        
        // make sure that we are frontmost
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        
        // observe if we are sent to background because in this case we'll not have to unhide other apps
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidDeactivateApplicationNotification
                                                                        object:nil
                                                                         queue:nil
                                                                    usingBlock:^(NSNotification * _Nonnull note) {
            [self->_userDefaults setBool:YES forKey:@"dontUnhideApps"];
        }];
           
        // hide all other windows
        CoreDockSendNotification(CFSTR("com.apple.showdesktop.awake"), NULL);
        
        // change privileges immediately if needed and if
        // privileges are enforced or just update our dialog
        if ([_userDefaults objectIsForcedForKey:@"EnforcePrivileges"]) {
            _autoApplyPrivileges = YES;
            [self performSelectorOnMainThread:@selector(checkForHelper:) withObject:REQUIRED_HELPER_VERSION waitUntilDone:NO];
        } else {
            _autoApplyPrivileges = NO;
        }
        
        _alwaysTimeout = NO;
        
        [self createDialog];
    }
}



- (void)changeAdminGroup:(NSString*)userName group:(uint)groupID remove:(BOOL)remove
{
    uint timeoutValue = 0;
    if (self->_alwaysTimeout) {
        timeoutValue = (uint)self->_timeoutValue;
    }
    
    [MTAuthCommon connectToHelperToolUsingConnection:&_helperToolConnection
                              andExecuteCommandBlock:^(void) {
        
            [[self->_helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
            
            NSLog(@"SAPCorp: ERROR! %@", proxyError);
            [self displayErrorNotificationAndExit];
            
            }] changeGroupMembershipForUser:userName group:groupID remove:remove authorization:self->_authorization timeout:timeoutValue withReply:^(NSError *error) {
            
            if (error != nil) {
                NSLog(@"SAPCorp: ERROR! Unable to change privileges: %@", error);
                [self displayErrorNotificationAndExit];
                
            } else {
                
                if (remove) {
                    NSLog(@"SAPCorp: User %@ has now standard user rights", userName);
                } else {
                    NSLog(@"SAPCorp: User %@ has now admin rights", userName);
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
        
    }];
}

- (void)checkForHelper:(NSString*)requiredVersion
{
    // create authorization reference
    _authorization = [MTAuthCommon createAuthorizationUsingAuthorizationRef:&_authRef];
    
    if (!_authorization) {
        
        // display an error dialog and exit
        [self displayDialog:NSLocalizedString(@"notificationText_Error", nil)
                messageText:nil
          withDefaultButton:NSLocalizedString(@"okButton", nil)
         andAlternateButton:nil
         ];
        
    } else {
        
        [MTAuthCommon connectToHelperToolUsingConnection:&_helperToolConnection
                                  andExecuteCommandBlock:^(void) {
            
            [[self->_helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
                [self performSelectorOnMainThread:@selector(helperCheckFailed:) withObject:proxyError waitUntilDone:NO];
                
            }] getVersionWithReply:^(NSString *helperVersion) {
                if ([helperVersion isEqualToString:requiredVersion]) {
                    
                    // everything seems to be good, so set the privileges
                    [self performSelectorOnMainThread:@selector(setPrivileges) withObject:nil waitUntilDone:NO];
                    
                } else {
                    NSString *errorMsg = [NSString stringWithFormat:@"Helper version mismatch (is %@, should be %@)", helperVersion, requiredVersion];
                    [self performSelectorOnMainThread:@selector(helperCheckFailed:) withObject:errorMsg waitUntilDone:NO];
                }
            }];
        }];
    }
}

- (void)helperCheckFailed:(NSString*)errorMessage
{
    NSLog(@"SAPCorp: ERROR! %@", errorMessage);
    
    NSError *installError = nil;;
    [MTAuthCommon installHelperToolUsingAuthorizationRef:_authRef error:&installError];

    if (installError) {
        NSLog(@"SAPCorp: ERROR! Installation of the helper tool failed: %@", installError);
        
        [self displayDialog:NSLocalizedString(@"notificationText_Error", nil)
                messageText:nil
          withDefaultButton:NSLocalizedString(@"okButton", nil)
         andAlternateButton:nil
         ];
        
    } else {
        
        NSLog(@"SAPCorp: The helper tool has been successfully installed");
        
        // check for the helper again
        NSString *requiredHelperVersion = REQUIRED_HELPER_VERSION;
        SEL theSelector = @selector(checkForHelper:);
        NSMethodSignature *theSignature = [self methodSignatureForSelector:theSelector];
        NSInvocation *theInvocation = [NSInvocation invocationWithMethodSignature:theSignature];
        [theInvocation setSelector:theSelector];
        [theInvocation setTarget:self];
        [theInvocation setArgument:&requiredHelperVersion atIndex:2];
        [NSTimer scheduledTimerWithTimeInterval:0.2 invocation:theInvocation repeats:NO];
    }
}

- (void)createTimeoutMenu
{
    // define the default timeout
    _timeoutValue = DEFAULT_DOCK_TIMEOUT;
    
    // get the configured timeout
    if ([_userDefaults objectForKey:@"DockToggleTimeout"]) {

        // get the currently configured timeout
        _timeoutValue = [_userDefaults integerForKey:@"DockToggleTimeout"];
        
        // disable the menu if the setting is managed
        [_toggleTimeoutMenu setEnabled:![_userDefaults objectIsForcedForKey:@"DockToggleTimeout"]];
        
    } else {
        
        // write the default timeout to file
        [_userDefaults setValue:[NSNumber numberWithInteger:self->_timeoutValue] forKey:@"DockToggleTimeout"];
    }

    // populate the timeout menu
    self.toggleTimeouts = [[NSMutableArray alloc] initWithObjects:
                           [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"value", NSLocalizedString(@"timeoutNever", nil), @"name", nil],
                           [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:5], @"value", [NSString stringWithFormat:@"5 %@", NSLocalizedString(@"timeoutMins", nil)], @"name", nil],
                           [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:10], @"value", [NSString stringWithFormat:@"10 %@", NSLocalizedString(@"timeoutMins", nil)], @"name", nil],
                           [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:20], @"value", [NSString stringWithFormat:@"20 %@", NSLocalizedString(@"timeoutMins", nil)], @"name", nil],
                           [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:60], @"value", [NSString stringWithFormat:@"1 %@", NSLocalizedString(@"timeoutHour", nil)], @"name", nil],
                           nil];
    
    // check if the configured timeout has already an entry in our menu. if not,
    // add the new value and sort the array
    NSPredicate *predicateString = [NSPredicate predicateWithFormat:@"value == %d", _timeoutValue];
    if ([[self.toggleTimeouts filteredArrayUsingPredicate:predicateString] count] == 0) {
        
        self.toggleTimeouts = [self.toggleTimeouts arrayByAddingObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:self->_timeoutValue], @"value", [NSString stringWithFormat:@"%ld %@", (long)_timeoutValue, NSLocalizedString(@"timeoutMins", nil)], @"name", nil]];
        
        // sort the array
        NSSortDescriptor *valueSort = [NSSortDescriptor sortDescriptorWithKey:@"value" ascending:YES];
        self.toggleTimeouts = [self.toggleTimeouts sortedArrayUsingDescriptors:[NSArray arrayWithObject:valueSort]];
    }
    
    // select the timeout value in the popup menu. if the value of timeoutValue is not in
    // our pre-defined list, we add the value to our array, sort it and select the value
    NSUInteger timeoutIndex = [self.toggleTimeouts indexOfObjectPassingTest:^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop)
    {
        return [[dict objectForKey:@"value"] isEqual:[NSNumber numberWithInteger:_timeoutValue]];
    }];
    if (timeoutIndex != NSNotFound) { [_toggleTimeoutMenu selectItemAtIndex:timeoutIndex]; }
}

- (void)createDialog
// create the admin dialog
{
    // check if we are restricted
    NSString *enforcedPrivileges;
    BOOL isAllowed = true;

    if ([_userDefaults objectIsForcedForKey:@"EnforcePrivileges"]) {
        enforcedPrivileges = [_userDefaults objectForKey:@"EnforcePrivileges"];
    }
    
    //
    if ([_userDefaults boolForKey:@"AlwaysUseTimeout"]) {
        _alwaysTimeout = [_userDefaults boolForKey:@"AlwaysUseTimeout"];
    }
    
    
    // check if the running user is allowed by managed preference
    if ([_userDefaults objectIsForcedForKey:@"AllowForUser"]) {
        NSString *allowedForUser = [_userDefaults objectForKey:@"AllowForUser"];
        if (![allowedForUser isEqualToString:NSUserName()]) {
            isAllowed = false;
        }
    }
    
    // skip group check if we aren't allowed
    if (isAllowed && [_userDefaults objectIsForcedForKey:@"AllowForGroup"]) {
        NSString *allowedForGroup = [_userDefaults objectForKey:@"AllowForGroup"];
        int groupID = [MTIdentity gidFromGroupName:allowedForGroup];
        
        if (groupID != -1) {
            NSError *userError = nil;
            BOOL isGroupMember = [MTIdentity getGroupMembershipForUser:NSUserName() groupID:groupID error:&userError];
            if (!isGroupMember) {
                isAllowed = false;
            }
        }
    }

    //  if EnforcePrivileges has been set to "none" we just display a dialog and quit
    if (!isAllowed || [enforcedPrivileges isEqualToString:@"none"]) {
        
        // display a dialog and exit if we did not get the gid
        [self displayDialog:NSLocalizedString(@"restrictedDialog1", nil)
                messageText:NSLocalizedString(@"restrictedDialog2None", nil)
          withDefaultButton:NSLocalizedString(@"okButton", nil)
         andAlternateButton:nil
         ];
        
    } else {

        // don't run this as root
        if (getuid() != 0) {
            
            NSError *userError = nil;
            int groupID = [MTIdentity gidFromGroupName:ADMIN_GROUP_NAME];
            
            if (groupID == -1) {
                
                // display an error dialog and exit if we did not get the gid
                [self displayDialog:NSLocalizedString(@"notificationText_Error", nil)
                        messageText:nil
                  withDefaultButton:NSLocalizedString(@"okButton", nil)
                 andAlternateButton:nil
                 ];
                
            } else {
                
                BOOL isAdmin = [MTIdentity getGroupMembershipForUser:NSUserName() groupID:groupID error:&userError];
                
                if (userError != nil) {
                    
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
    NSString *userName = NSUserName();
    uint groupID = [MTIdentity gidFromGroupName:ADMIN_GROUP_NAME];
    BOOL isAdmin = [MTIdentity getGroupMembershipForUser:userName groupID:groupID error:nil];
    BOOL changeNeeded = YES;
    
    if (_autoApplyPrivileges) {
        NSString *enforcedPrivileges = [_userDefaults objectForKey:@"EnforcePrivileges"];
        
        if (([enforcedPrivileges isEqualToString:@"admin"] && isAdmin) || ([enforcedPrivileges isEqualToString:@"user"] && !isAdmin)) {
            changeNeeded = NO;
        }
    }
    
    // change group membership
    if (changeNeeded) {
        [self changeAdminGroup:userName group:groupID remove:isAdmin];
        
    } else {

        // send notification that nothing has changed and exit
        [self displayNoChangeNotificationAndExit];
    }
}

- (void)displayDialog:(NSString* _Nonnull)messageTitle messageText:(NSString*)messageText withDefaultButton:(NSString* _Nonnull)defaultButtonText andAlternateButton:(NSString*)alternateButtonText
{
    // hide our dialog if currently visible
    if ([_mainWindow isVisible]) { [_mainWindow orderOut:self]; }
    
    [_notificationHead setStringValue:messageTitle];
    
    if (messageText) {
        [_notificationBody setStringValue:messageText];
        [_notificationBody setHidden:NO];
    } else {
        [_notificationBody setHidden:YES];
    }

    [_defaultButton setTitle:defaultButtonText];
    
    if (alternateButtonText) {
        [_alternateButton setTitle:alternateButtonText];
        [_alternateButton setHidden:NO];
    } else {
        [_alternateButton setHidden:YES];
    }
    
    // make sure that we are frontmost
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    
    // display our dialog
    [_mainWindow setLevel:NSScreenSaverWindowLevel];
    [_mainWindow setAnimationBehavior:NSWindowAnimationBehaviorAlertPanel];
    [_mainWindow setIsVisible:YES];
    [_mainWindow center];
    [_mainWindow makeKeyAndOrderFront:self];    
}

- (IBAction)popupButtonPressed:(id)sender
{
    // update the preference file for the selected timeout
    NSInteger selectedIndex = [sender indexOfSelectedItem];
    NSDictionary *timeoutDict = [self.toggleTimeouts objectAtIndex:selectedIndex];
    NSNumber *timeoutValue = [timeoutDict valueForKey:@"value"];
    [_userDefaults setValue:timeoutValue forKey:@"DockToggleTimeout"];
}

- (IBAction)actionButtonPressed:(id)sender
{
    // hide our dialog
    [_mainWindow orderOut:self];
    
    if (_autoApplyPrivileges) {
        [NSApp terminate:self];
        
    } else {
    
        NSString *buttonIdentifier = [sender identifier];
        
        if ([buttonIdentifier isEqualToString:@"corp.sap.button.default"] && !_autoApplyPrivileges) {
        
            // send notification that nothing has changed and exit
            [self displayNoChangeNotificationAndExit];
            
        } else {
                
            // check for the helper (and the correct version)
            [self performSelectorOnMainThread:@selector(checkForHelper:) withObject:REQUIRED_HELPER_VERSION waitUntilDone:NO];
        }
    }
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
    [_prefsWindow makeKeyAndOrderFront:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _userDefaults && [keyPath isEqualToString:@"DockToggleTimeout"]) {

        // workaround for bug that is causing observeValueForKeyPath to be called multiple times.
        // so every notification resets the timer and if we got no new notifications for 2 seconds,
        // we evaluate the changes.
        if (_fixTimeoutObserverTimer) { [_fixTimeoutObserverTimer invalidate]; };
        _fixTimeoutObserverTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                                   repeats:NO
                                                                     block:^(NSTimer * _Nonnull timer) {
            // update the timeout menu
            [self createTimeoutMenu];
         }];
        
    } else if (object == _userDefaults && [keyPath isEqualToString:@"EnforcePrivileges"]) {
        
        // workaround for bug that is causing observeValueForKeyPath to be called multiple times.
        // so every notification resets the timer and if we got no new notifications for 2 seconds,
        // we evaluate the changes.
        if (_fixEnforceObserverTimer) { [_fixEnforceObserverTimer invalidate]; };
        _fixEnforceObserverTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                                   repeats:NO
                                                                     block:^(NSTimer * _Nonnull timer) {
            // change privileges immediately if needed and if
            // privileges are enforced or just update our dialog
            if ([self->_userDefaults objectIsForcedForKey:@"EnforcePrivileges"]) {
                self->_autoApplyPrivileges = YES;
                [self performSelectorOnMainThread:@selector(checkForHelper:) withObject:REQUIRED_HELPER_VERSION waitUntilDone:NO];
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
    if (_timeoutValue <= 0)
    {
        // quit the helper tool
        [MTAuthCommon connectToHelperToolUsingConnection:&_helperToolConnection
                                  andExecuteCommandBlock:^(void) { [[self->_helperToolConnection remoteObjectProxy] quitHelperTool]; }
         ];
    }
    
    // remove our observers
    [_userDefaults removeObserver:self forKeyPath:@"DockToggleTimeout"];
    [_userDefaults removeObserver:self forKeyPath:@"EnforcePrivileges"];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    
    // unhide the other applications if needed
    if ([_userDefaults boolForKey:@"dontUnhideApps"]) {
        [_userDefaults removeObjectForKey:@"dontUnhideApps"];
    } else {
        CoreDockSendNotification(CFSTR("com.apple.expose.front.awake"), NULL);
    }
}

@end
