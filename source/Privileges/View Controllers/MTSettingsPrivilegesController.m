/*
    MTSettingsPrivilegesController.m
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

#import "MTSettingsPrivilegesController.h"
#import "MTPrivileges.h"
#import "Constants.h"
#import "MTSystemInfo.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface MTSettingsPrivilegesController ()
@property (retain) id configurationObserver;
@property (nonatomic, strong, readwrite) MTPrivileges *privilegesApp;
@property (nonatomic, strong, readwrite) NSString *configuredByProfileLabel;

@property (weak) IBOutlet NSPopUpButton *autoRemoveMenu;
@property (weak) IBOutlet NSPopUpButton *postExecutableMenu;
@property (weak) IBOutlet NSButton *privilegeRenewalButton;
@property (weak) IBOutlet NSButton *removeAtLoginButton;
@property (weak) IBOutlet NSButton *actionAfterGrantOnlyButton;
@end

@implementation MTSettingsPrivilegesController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[[self view] window] setAccessibilityLabel:[[[self view] window] title]];
    [[[self view] window] setAccessibilityEnabled:YES];

    _privilegesApp = [[MTPrivileges alloc] init];
    
    // set the initial state of the "Revoke administrator privileges at login" checkbox
    [self setLoginItemCheckbox];
    
    // set the initial state of the "Allow expiring administrator privileges to be renewed once" checkbox
    [self setPrivilegeRenewalCheckbox];
    
    // create the expiration time menu
    [self createAutoRemoveMenu];
    
    // create the "Run after privilege change:" menu
    [self createPostExecMenuWithPath:[_privilegesApp postChangeExecutablePath]];
    
    // set the initial state of the "Run only if administrator privileges have been granted" checkbox
    [self setActionAfterGrantOnlyCheckbox];
    
    self.configuredByProfileLabel = NSLocalizedString(@"configuredByProfileLabel", nil);
    
    _configurationObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:kMTNotificationNameConfigDidChange
                                                                                          object:nil
                                                                                           queue:nil
                                                                                      usingBlock:^(NSNotification *notification) {
        NSDictionary *userInfo = [notification userInfo];
        
        if (userInfo) {
            
            NSString *changedKey = [userInfo objectForKey:kMTNotificationKeyPreferencesChanged];
            
            NSArray *keysToObserve = [[NSArray alloc] initWithObjects:
                                      kMTDefaultsExpirationIntervalKey,
                                      kMTDefaultsAutoExpirationIntervalMaxKey,
                                      kMTDefaultsRevokeAtLoginKey,
                                      kMTDefaultsRevokeAtLoginExcludedUsersKey,
                                      kMTDefaultsPostChangeExecutablePathKey,
                                      kMTDefaultsPostChangeActionOnGrantOnlyKey,
                                      kMTDefaultsAllowPrivilegeRenewalKey,
                                      nil
            ];
            
            if (changedKey && [keysToObserve containsObject:changedKey]) {
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

                    if ([changedKey isEqualToString:kMTDefaultsExpirationIntervalKey] ||
                        [changedKey isEqualToString:kMTDefaultsAutoExpirationIntervalMaxKey]) {
                        
                        // update our menu
                        [self createAutoRemoveMenu];
                        
                        // and our removal checkbox
                        [self setPrivilegeRenewalCheckbox];
                        
                    } else if ([changedKey isEqualToString:kMTDefaultsRevokeAtLoginKey] ||
                               [changedKey isEqualToString:kMTDefaultsRevokeAtLoginExcludedUsersKey]) {
                        
                        [self setLoginItemCheckbox];
                        
                    } else if ([changedKey isEqualToString:kMTDefaultsPostChangeExecutablePathKey]) {
                        
                        [self createPostExecMenuWithPath:[self->_privilegesApp postChangeExecutablePath]];
                        [self setActionAfterGrantOnlyCheckbox];
                        
                    } else if ([changedKey isEqualToString:kMTDefaultsPostChangeActionOnGrantOnlyKey]) {
                        
                        [self setActionAfterGrantOnlyCheckbox];
                        
                    } else if ([changedKey isEqualToString:kMTDefaultsAllowPrivilegeRenewalKey]) {
                        
                        [self setPrivilegeRenewalCheckbox];
                    }
                });
            }
        }
    }];
}

- (void)createAutoRemoveMenu
{
    // remove all menu entries
    [[_autoRemoveMenu menu] removeAllItems];
    
    // check if the configured value for auto remove has already an
    // entry in our menu. if not, add a new value.
    NSInteger removalIntervalValue = [_privilegesApp expirationInterval];
    NSMutableArray *expirationIntervals = [NSMutableArray arrayWithArray:kMTFixedExpirationIntervals];
    
    if (removalIntervalValue >= 0 && ![expirationIntervals containsObject:[NSNumber numberWithInteger:removalIntervalValue]]) {
        [expirationIntervals addObject:[NSNumber numberWithInteger:removalIntervalValue]];
    }
    
    // get the maximum timeout value (if configured)…
    NSInteger maxIntervalValue = [_privilegesApp expirationIntervalMax];
    if (maxIntervalValue >= 0 && ![_privilegesApp expirationIntervalIsForced]) {
        
        // …and also add it to our menu (if needed)
        if (![expirationIntervals containsObject:[NSNumber numberWithInteger:maxIntervalValue]]) {
            [expirationIntervals addObject:[NSNumber numberWithInteger:maxIntervalValue]];
        }
    }
    
    // sort the array…
    NSSortDescriptor *sortAscending = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES];
    [expirationIntervals sortUsingDescriptors:[NSArray arrayWithObject:sortAscending]];
    
    // …and make sure the "never" entry is at the end of the array
    id object = [expirationIntervals firstObject];
    if ([object isEqualToNumber:[NSNumber numberWithInteger:0]]) {
        [expirationIntervals removeObjectAtIndex:0];
        [expirationIntervals addObject:object];
    }
    
    for (NSNumber *intervalValue in expirationIntervals) {
        
        NSInteger intervalInt = [intervalValue integerValue];
        
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:(intervalInt == 0) ? NSLocalizedString(@"timeoutNever", nil) : [NSString localizedStringWithFormat:NSLocalizedString(@"expireAfter", nil), [MTPrivileges stringForDuration:intervalInt localized:YES naturalScale:YES]]
                                                          action:nil
                                                   keyEquivalent:@""];
        [menuItem setTag:intervalInt];
        [[_autoRemoveMenu menu] addItem:menuItem];
        
        if (maxIntervalValue > 0 && ((intervalInt > maxIntervalValue) || intervalInt == 0)) {
            [menuItem setEnabled:NO];
        } else {
            [menuItem setEnabled:YES];
        }
    }

    [self willChangeValueForKey:@"removalIntervalIsForced"];
    [_autoRemoveMenu selectItemWithTag:removalIntervalValue];
    [_autoRemoveMenu setEnabled:![_privilegesApp expirationIntervalIsForced]];
    [_autoRemoveMenu setAccessibilityLabel:[_autoRemoveMenu titleOfSelectedItem]];
    [self didChangeValueForKey:@"removalIntervalIsForced"];
}

- (void)setLoginItemCheckbox
{
    [self willChangeValueForKey:@"revokeAtLoginIsForced"];
    [_removeAtLoginButton setState:([_privilegesApp privilegesShouldBeRevokedAtLogin]) ? NSControlStateValueOn : NSControlStateValueOff];
    [_removeAtLoginButton setEnabled:![_privilegesApp privilegesShouldBeRevokedAtLoginIsForced]];
    [self didChangeValueForKey:@"revokeAtLoginIsForced"];
}

- (void)setPrivilegeRenewalCheckbox
{
    [self willChangeValueForKey:@"renewalIsForced"];
    [_privilegeRenewalButton setState:([_privilegesApp privilegeRenewalAllowed]) ? NSControlStateValueOn : NSControlStateValueOff];
    [_privilegeRenewalButton setEnabled:![_privilegesApp privilegeRenewalAllowedIsForced] && [_privilegesApp expirationInterval] > 0];
    [self didChangeValueForKey:@"renewalIsForced"];
}

- (void)createPostExecMenuWithPath:(NSString*)path
{
    if (path) {
        
        // get the title for the menu item…
        NSString *itemTitle = [path lastPathComponent];
        if ([[[itemTitle pathExtension] lowercaseString] isEqualToString:@"app"]) {
            itemTitle = [itemTitle stringByDeletingPathExtension];
        }
        
        // get the image for the menu item…
        NSImage *itemImage = [[NSWorkspace sharedWorkspace] iconForFile:path];
        
        if ([itemImage isValid]) {
            
            // reszize the image to 16x16 pixels
            NSImageRep *imageRep = [itemImage bestRepresentationForRect:NSMakeRect(0, 0, 16, 16) context:nil hints:nil];
            itemImage = [[NSImage alloc] initWithSize:[imageRep size]];
            [itemImage addRepresentation:imageRep];
        }
        
        // add the item…
        NSMenuItem *executableItem = [[NSMenuItem alloc] initWithTitle:itemTitle
                                                                action:nil keyEquivalent:@""
        ];
        [executableItem setImage:itemImage];
        [executableItem setTag:755];
        [[self->_postExecutableMenu menu] insertItem:executableItem atIndex:2];
        
        // …and select it
        [self->_postExecutableMenu selectItemAtIndex:2];
        
    } else {
        
        // remove the item
        NSMenuItem *executableItem = [[_postExecutableMenu menu] itemWithTag:755];
        
        if (executableItem) {
            [[_postExecutableMenu menu] removeItem:executableItem];
        }
    }
    
    [self willChangeValueForKey:@"executablePathIsForced"];
    [_postExecutableMenu setEnabled:![_privilegesApp postChangeExecutablePathIsForced]];
    [_postExecutableMenu setAccessibilityLabel:[_postExecutableMenu titleOfSelectedItem]];
    [self didChangeValueForKey:@"executablePathIsForced"];
}

- (void)setActionAfterGrantOnlyCheckbox
{
    [self willChangeValueForKey:@"execAfterGrantOnlyIsForced"];
    [_actionAfterGrantOnlyButton setState:([_privilegesApp runActionAfterGrantOnly]) ? NSControlStateValueOn : NSControlStateValueOff];
    [_actionAfterGrantOnlyButton setEnabled:(![_privilegesApp runActionAfterGrantOnlyIsForced] && [_privilegesApp postChangeExecutablePath])];
    [self didChangeValueForKey:@"execAfterGrantOnlyIsForced"];
}

- (void)dealloc
{
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:_configurationObserver];
    _configurationObserver = nil;
}

#pragma mark Bindings

- (BOOL)removalIntervalIsForced
{
    return [_privilegesApp expirationIntervalIsForced];
}

- (BOOL)renewalIsForced
{
    return [_privilegesApp privilegeRenewalAllowedIsForced];
}

- (BOOL)revokeAtLoginIsForced
{
    return [_privilegesApp privilegesShouldBeRevokedAtLoginIsForced];
}

- (BOOL)executablePathIsForced
{
    return [_privilegesApp postChangeExecutablePathIsForced];
}

- (BOOL)execAfterGrantOnlyIsForced
{
    return [_privilegesApp runActionAfterGrantOnlyIsForced];
}

#pragma mark IBActions

- (IBAction)setRemovalInterval:(id)sender
{
    [_privilegesApp setExpirationInterval:[sender selectedTag]];
    [_autoRemoveMenu setAccessibilityLabel:[_autoRemoveMenu titleOfSelectedItem]];
    [self setPrivilegeRenewalCheckbox];
}

- (IBAction)setPrivilegeRenewalAllowed:(id)sender
{
    [_privilegesApp setPrivilegeRenewalAllowed:([(NSButton*)sender state] == NSControlStateValueOn)];
}

- (IBAction)setLoginItem:(id)sender
{
    [_privilegesApp setPrivilegesShouldBeRevokedAtLogin:([(NSButton*)sender state] == NSControlStateValueOn)];
}

- (IBAction)setHideOtherWindows:(id)sender
{
    [_privilegesApp setHideOtherWindows:([(NSButton*)sender state] == NSControlStateValueOn)];
}

- (IBAction)selectExecutable:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setPrompt:NSLocalizedString(@"selectButton", nil)];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanCreateDirectories:NO];
    [panel setAllowedContentTypes:[NSArray arrayWithObjects:UTTypeApplicationBundle, UTTypeUnixExecutable, UTTypeShellScript, nil]];
    [panel beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse result) {
        
        if (result == NSModalResponseOK) {
                
            [[self->_privilegesApp currentUser] canExecuteFileAtURL:[panel URL]
                                                              reply:^(BOOL canExecute) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    if (canExecute) {

                        NSString *executablePath = [[panel URL] path];
                        
                        // remove an existing menu item
                        [self createPostExecMenuWithPath:nil];
                        
                        // add the selected executable to the menu
                        [self createPostExecMenuWithPath:executablePath];
                        
                        // update our preferences
                        [self->_privilegesApp setPostChangeExecutablePath:executablePath];
                    
                    } else {
                        
                        if ([[self->_postExecutableMenu menu] itemWithTag:755]) {
                            [self->_postExecutableMenu selectItemWithTag:755];
                        } else {
                            [self->_postExecutableMenu selectItemAtIndex:0];
                        }
                        
                        [self->_postExecutableMenu setAccessibilityLabel:[self->_postExecutableMenu titleOfSelectedItem]];
                        
                        NSAlert *alert = [[NSAlert alloc] init];
                        [alert setMessageText:NSLocalizedString(@"fileNotExecutableDialogTitle", nil)];
                        [alert addButtonWithTitle:NSLocalizedString(@"okButton", nil)];
                        [alert setAlertStyle:NSAlertStyleCritical];
                        [alert beginSheetModalForWindow:[[self view] window] completionHandler:nil];
                    }
                    
                    [self setActionAfterGrantOnlyCheckbox];
                });
                
            }];
        }
    }];
}

- (IBAction)removeExecutable:(id)sender
{
    [self createPostExecMenuWithPath:nil];
    
    // update our preferences
    [self->_privilegesApp setPostChangeExecutablePath:nil];
    
    [self setActionAfterGrantOnlyCheckbox];
}

- (IBAction)setActionAfterGrantOnly:(id)sender
{
    [_privilegesApp setRunActionAfterGrantOnly:([(NSButton*)sender state] == NSControlStateValueOn)];
}

@end
