/*
    MTSettingsGeneralController.m
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

#import "MTSettingsGeneralController.h"
#import "MTPrivileges.h"
#import "Constants.h"

@interface MTSettingsGeneralController ()
@property (retain) id configurationObserver;
@property (nonatomic, strong, readwrite) MTPrivileges *privilegesApp;
@property (nonatomic, strong, readwrite) NSString *configuredByProfileLabel;

@property (weak) IBOutlet NSButton *hideWindowsButton;
@property (weak) IBOutlet NSButton *menuBarButton;
@property (weak) IBOutlet NSButton *menuBarTimerButton;
@end

@implementation MTSettingsGeneralController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[[self view] window] setAccessibilityLabel:[[[self view] window] title]];
    [[[self view] window] setAccessibilityEnabled:YES];

    _privilegesApp = [[MTPrivileges alloc] init];
    
    // set the initial state of the "Hide other windows" checkbox
    [self setHideWindowsCheckbox];
    
    // set the initial state of the "Show in Menu Bar" checkbox
    [self setMenuBarCheckbox];
    
    // set the initial state of the "Show Timer" checkbox
    [self setMenuBarTimerCheckbox];
    
    self.configuredByProfileLabel = NSLocalizedString(@"configuredByProfileLabel", nil);
    
    _configurationObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:kMTNotificationNameConfigDidChange
                                                                                          object:nil
                                                                                           queue:nil
                                                                                      usingBlock:^(NSNotification *notification) {
        NSDictionary *userInfo = [notification userInfo];
        
        if (userInfo) {
            
            NSString *changedKey = [userInfo objectForKey:kMTNotificationKeyPreferencesChanged];
            
            NSArray *keysToObserve = [[NSArray alloc] initWithObjects:
                                      kMTDefaultsHideOtherWindowsKey,
                                      kMTDefaultsShowInMenuBarKey,
                                      kMTDefaultsShowRemainingTimeInMenuBarKey,
                                      nil
            ];
            
            if (changedKey && [keysToObserve containsObject:changedKey]) {
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

                    if ([changedKey isEqualToString:kMTDefaultsHideOtherWindowsKey]) {
                        
                        [self setHideWindowsCheckbox];
                        
                    } else if ([changedKey isEqualToString:kMTDefaultsShowInMenuBarKey]) {
                        
                        [self setMenuBarCheckbox];
                        [self setMenuBarTimerCheckbox];
                    
                    } else if ([changedKey isEqualToString:kMTDefaultsShowRemainingTimeInMenuBarKey]) {
                        
                        [self setMenuBarTimerCheckbox];
                    }
                });
            }
        }
    }];
}

- (void)setHideWindowsCheckbox
{
    [self willChangeValueForKey:@"hideWindowsIsForced"];
    [_hideWindowsButton setState:([_privilegesApp hideOtherWindows]) ? NSControlStateValueOn : NSControlStateValueOff];
    [_hideWindowsButton setEnabled:![_privilegesApp hideOtherWindowsIsForced]];
    [self didChangeValueForKey:@"hideWindowsIsForced"];
}

- (void)setMenuBarCheckbox
{
    [self willChangeValueForKey:@"menuBarIsForced"];
    [_menuBarButton setState:([_privilegesApp showInMenuBar]) ? NSControlStateValueOn : NSControlStateValueOff];
    [_menuBarButton setEnabled:![_privilegesApp showInMenuBarIsForced]];
    [self didChangeValueForKey:@"menuBarIsForced"];
}

- (void)setMenuBarTimerCheckbox
{
    [self willChangeValueForKey:@"menuBarTimerIsForced"];
    [_menuBarTimerButton setState:([_privilegesApp showRemainingTimeInMenuBar]) ? NSControlStateValueOn : NSControlStateValueOff];
    [_menuBarTimerButton setEnabled:(![_privilegesApp showRemainingTimeInMenuBarIsForced] && [_menuBarButton state] == NSControlStateValueOn)];
    [self didChangeValueForKey:@"menuBarTimerIsForced"];
}

- (void)dealloc
{
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:_configurationObserver];
    _configurationObserver = nil;
}

#pragma mark - Bindings

- (BOOL)hideWindowsIsForced
{
    return [_privilegesApp hideOtherWindowsIsForced];
}

- (BOOL)menuBarIsForced
{
    return [_privilegesApp showInMenuBarIsForced];
}

- (BOOL)menuBarTimerIsForced
{
    return [_privilegesApp showRemainingTimeInMenuBarIsForced];
}


#pragma mark - IBActions

- (IBAction)setHideOtherWindows:(id)sender
{
    [_privilegesApp setHideOtherWindows:([(NSButton*)sender state] == NSControlStateValueOn)];
}

- (IBAction)setShowInMenuBar:(id)sender
{
    [_privilegesApp setShowInMenuBar:([(NSButton*)sender state] == NSControlStateValueOn)];
    [self setMenuBarTimerCheckbox];
}

- (IBAction)setShowTimerInMenuBar:(id)sender
{
    [_privilegesApp setShowRemainingTimeInMenuBar:([(NSButton*)sender state] == NSControlStateValueOn)];
}

@end
