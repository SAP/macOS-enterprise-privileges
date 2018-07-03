/*
 AppDelegate.m
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
@end


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
    // check if we were launched because the user clicked one of our notifications.
    // if so, we just quit.
    NSUserNotification *userNotification = [[aNotification userInfo] objectForKey:NSApplicationLaunchUserNotificationKey];
    if (userNotification) {
        [NSApp terminate:self];
        
    } else {

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
        
        // fill the timeout menu
        self.toggleTimeouts = [[NSArray alloc] initWithObjects:
                               [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"value", NSLocalizedString(@"timeoutNever", nil), @"name", nil],
                               [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:5], @"value", [NSString stringWithFormat:@"5 %@", NSLocalizedString(@"timeoutMins", nil)], @"name", nil],
                               [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:10], @"value", [NSString stringWithFormat:@"10 %@", NSLocalizedString(@"timeoutMins", nil)], @"name", nil],
                               [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:20], @"value", [NSString stringWithFormat:@"20 %@", NSLocalizedString(@"timeoutMins", nil)], @"name", nil],
                               [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:60], @"value", [NSString stringWithFormat:@"1 %@", NSLocalizedString(@"timeoutHour", nil)], @"name", nil],
                               nil];
        
        NSInteger timeoutValue = 20;
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"DockToggleTimeout"]) {
            
            // get the currently selected timeout
            timeoutValue = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DockToggleTimeout"] integerValue];
            
        } else {
            
            // set a standard timeout
            [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInteger:timeoutValue] forKey:@"DockToggleTimeout"];
        }
        
        // select the timeout value in the popup menu
        NSUInteger timeoutIndex = [self.toggleTimeouts indexOfObjectPassingTest:^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop)
        {
            return [[dict objectForKey:@"value"] isEqual:[NSNumber numberWithInteger:timeoutValue]];
        }];
        if (timeoutIndex != NSNotFound) { [_toggleTimeoutMenu selectItemAtIndex:timeoutIndex]; }
        
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
                    
                    // display a dialog
                    NSString *dialogTitle = nil;
                    NSString *dialogMessage = nil;
                    NSString *buttonTitle = nil;
                    
                    if (isAdmin) {
                        
                        dialogTitle = NSLocalizedString(@"unsetDialog1", nil);
                        dialogMessage = NSLocalizedString(@"unsetDialog2", nil);
                        buttonTitle = NSLocalizedString(@"removeButton", nil);
                        
                    } else {
                        
                        dialogTitle = NSLocalizedString(@"setDialog1", nil);
                        dialogMessage = NSLocalizedString(@"setDialog2", nil);
                        buttonTitle = NSLocalizedString(@"requestButton", nil);
                    }
                    
                    [self displayDialog:dialogTitle
                            messageText:dialogMessage
                      withDefaultButton:NSLocalizedString(@"cancelButton", nil)
                     andAlternateButton:buttonTitle
                     ];
                }
            }

        } else {
            
            // display an error dialog and exit
            [self displayDialog:NSLocalizedString(@"rootError", nil)
                    messageText:nil
              withDefaultButton:NSLocalizedString(@"okButton", nil)
             andAlternateButton:nil
             ];
        }
    }
}

- (void)changeAdminGroup:(NSString*)userName group:(uint)groupID remove:(BOOL)remove
{
    [MTAuthCommon connectToHelperToolUsingConnection:&_helperToolConnection
                              andExecuteCommandBlock:^(void) {
        
            [[self->_helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
            
            NSLog(@"SAPCorp: ERROR! %@", proxyError);
            [self displayErrorNotificationAndExit];
            
        }] changeGroupMembershipForUser:userName group:groupID remove:remove authorization:self->_authorization withReply:^(NSError *error) {
            
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
                                                                             userInfo:[NSDictionary dictionaryWithObjectsAndKeys:(remove) ? @"standard" : @"admin", @"accountState", nil]
                                                                              options:NSNotificationDeliverImmediately
                 ];
                [self displaySuccessNotificationAndExit];
                
            }
            
        }];
        
    }];
}

- (void)checkForHelper:(NSString*)requiredVersion
{
    [MTAuthCommon connectToHelperToolUsingConnection:&_helperToolConnection
                              andExecuteCommandBlock:^(void) {
        
        [[self->_helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError *proxyError) {
            [self performSelectorOnMainThread:@selector(helperCheckFailed:) withObject:proxyError waitUntilDone:NO];
            
        }] getVersionWithReply:^(NSString *helperVersion) {
            if (helperVersion && [helperVersion isEqualToString:requiredVersion]) {
                [self performSelectorOnMainThread:@selector(helperCheckSuccessful:) withObject:helperVersion waitUntilDone:NO];
                
            } else {
                NSString *errorMsg = [NSString stringWithFormat:@"Helper version mismatch (is %@, should be %@)", helperVersion, requiredVersion];
                [self performSelectorOnMainThread:@selector(helperCheckFailed:) withObject:errorMsg waitUntilDone:NO];
            }
        }];
        
    }];
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

- (void)helperCheckSuccessful:(NSString*)helperVersion
{
#ifdef DEBUG
    NSLog(@"SAPCorp: The helper tool (%@) is up and running", helperVersion);
#endif
    
    NSString *userName = NSUserName();
    uint groupID = [MTIdentity gidFromGroupName:ADMIN_GROUP_NAME];
    BOOL isAdmin = [MTIdentity getGroupMembershipForUser:userName groupID:groupID error:nil];
    
    // run the privileged task
    [self changeAdminGroup:userName group:groupID remove:isAdmin];
}

- (void)displayDialog:(NSString* _Nonnull)messageTitle messageText:(NSString*)messageText withDefaultButton:(NSString* _Nonnull)defaultButtonText andAlternateButton:(NSString*)alternateButtonText
{
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
    [_mainWindow setLevel:NSScreenSaverWindowLevel];
    [_mainWindow setAnimationBehavior:NSWindowAnimationBehaviorAlertPanel];
    [_mainWindow setIsVisible:YES];
    [_mainWindow center];
    [_mainWindow makeKeyAndOrderFront:self];
}

- (IBAction)runPrivilegedTask:(id)sender
{
#pragma unused(sender)
    [_mainWindow orderOut:self];
    
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
        
        // check for the helper (and the correct version)
        [self performSelectorOnMainThread:@selector(checkForHelper:) withObject:REQUIRED_HELPER_VERSION waitUntilDone:NO];
    }
}

- (IBAction)popupButtonPressed:(id)sender
{
    // update the preference file for the selected timeout
    NSInteger selectedIndex = [sender indexOfSelectedItem];
    NSDictionary *timeoutDict = [self.toggleTimeouts objectAtIndex:selectedIndex];
    NSNumber *timeoutValue = [timeoutDict valueForKey:@"value"];
    [[NSUserDefaults standardUserDefaults] setValue:timeoutValue forKey:@"DockToggleTimeout"];
}

- (IBAction)dismissWindowAndQuit:(id)sender
{
#pragma unused(sender)
    [_mainWindow orderOut:self];
    
    // send notification that nothing changed and exit
    [MTNotification sendNotificationWithTitle:NSLocalizedString(@"notificationHead", nil)
                                   andMessage:NSLocalizedString(@"notificationText_Nothing", nil)
                              replaceExisting:YES
                                     delegate:self];
    
    [NSApp terminate:self];
}

- (void)displayErrorNotificationAndExit
// Display a notification if the operation failed and exit.
{
    [MTNotification sendNotificationWithTitle:NSLocalizedString(@"notificationHead", nil)
                                   andMessage:NSLocalizedString(@"notificationText_Error", nil)
                              replaceExisting:YES
                                     delegate:self];
    
    [NSApp terminate:self];
}

- (void)displaySuccessNotificationAndExit
// Display a notification if the operation was successful and exit.
{
    [MTNotification sendNotificationWithTitle:NSLocalizedString(@"notificationHead", nil)
                                   andMessage:NSLocalizedString(@"notificationText_Success", nil)
                              replaceExisting:YES
                                     delegate:self];
    
    [NSApp terminate:self];
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

-(void)applicationWillTerminate:(NSNotification *)aNotification
{
#pragma unused(aNotification)
    [MTAuthCommon connectToHelperToolUsingConnection:&_helperToolConnection
                              andExecuteCommandBlock:^(void) { [[self->_helperToolConnection remoteObjectProxy] quitHelperTool]; }
     ];
}

@end
