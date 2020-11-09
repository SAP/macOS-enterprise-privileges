/*
 PrivilegesTile.m
 Copyright 2016-2020 SAP SE
 
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

#import "PrivilegesTile.h"
#import "MTAuthCommon.h"
#import "MTIdentity.h"
#import "MTVoiceOver.h"
#import <AudioToolbox/AudioToolbox.h>


@interface PrivilegesTile ()
@property (retain) id privilegesObserver;
@property (retain) id timeoutObserver;
@property (atomic, strong, readwrite) NSString *cliPath;
@property (atomic, strong, readwrite) NSString *currentUser;
@property (atomic, strong, readwrite) NSBundle *mainBundle;
@property (atomic, strong, readwrite) NSBundle *pluginBundle;
@property (atomic, strong, readwrite) NSMenu *dockTileMenu;
@property (atomic, strong, readwrite) NSTimer *toggleTimer;
@property (atomic, strong, readwrite) NSTimer *fixTimeoutObserverTimer;
@property (atomic, strong, readwrite) NSDate *timerExpires;
@property (atomic, strong, readwrite) NSUserDefaults *userDefaults;
@property (atomic, strong, readwrite) NSArray *keysToObserve;
@end

extern void SACLockScreenImmediate (void);

@implementation PrivilegesTile

- (void)setDockTile:(NSDockTile*)dockTile
{
    if (dockTile) {
        
        // initialize our userDefaults to get the managed preferences
        _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"corp.sap.privileges"];
 
        // get the name of the current user
        _currentUser = NSUserName();
        
        // get the path to our command line tool
        _pluginBundle = [NSBundle bundleForClass:[self class]];
        NSString *pluginPath = [_pluginBundle bundlePath];
        NSString *mainbundlePath = [[[pluginPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
        _mainBundle = [NSBundle bundleWithPath:mainbundlePath];
        _cliPath = [_mainBundle pathForResource:@"PrivilegesCLI" ofType:nil];
        
        // register an observer to watch for privilege changes
        _privilegesObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"corp.sap.PrivilegesChanged"
                                                                                           object:_currentUser
                                                                                            queue:nil
                                                                                       usingBlock:^(NSNotification *notification) {
            
            BOOL isAdmin = [self checkAdminPrivilegesForUser:self->_currentUser error:nil];
            
            // invalidate the timer if the user is not admin anymore
            if (!isAdmin) { [self invalidateToggleTimer]; }
            
            // update the Dock tile icon ...
            [self updateDockTileIcon:dockTile isAdmin:isAdmin];
            
            // ... and also the Dock tile's badge
            [self updateDockTileBadge:dockTile];
                                                                                       }];
        
        // register an observer for the toggle timeout
        _timeoutObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"corp.sap.PrivilegesTimeout"
                                                                                        object:_currentUser
                                                                                         queue:nil
                                                                                    usingBlock:^(NSNotification *notification) {
            // get the remaining time
            NSInteger minutesLeft = ceil([self->_timerExpires timeIntervalSinceNow]/60);

            if (minutesLeft > 0) {
                
                // just update the Dock tile's badge
                [self updateDockTileBadge:dockTile];
                
            } else {
                    
                // toggle privileges
                [self togglePrivileges];
            }
        }];
        
        // define the keys in our prefs we need to observe
        _keysToObserve = [[NSArray alloc] initWithObjects:
                          @"DockToggleTimeout",
                          @"DockToggleMaxTimeout",
                          @"EnforcePrivileges",
                          @"LimitToUser",
                          @"LimitToGroup",
                          @"ReasonRequired",
                          nil
                          ];
        
        // Start observing our preferences to make sure we'll get notified as soon as someting changes (e.g. a configuration
        // profile has been installed). Unfortunately we cannot use the NSUserDefaultsDidChangeNotification here, because
        // it wouldn't be called if changes to our prefs would be made from outside this application.
        for (NSString *aKey in _keysToObserve) {
            [_userDefaults addObserver:self forKeyPath:aKey options:NSKeyValueObservingOptionNew context:nil];
        }
        
        // make sure the Dock tile has the correct icon on load and enforce
        // privileges, if a configuration profile has been already installed
        // and the enforced privileges does not match the current ones.
        [self enforcePrivileges];
    
    } else {
        
        // If dockTile is nil, the item has been removed from Dock, so we remove our observers.
        // Actually this is not really needed here but is best practice.
        if (_privilegesObserver || _timeoutObserver) {
            for (NSString *aKey in _keysToObserve) { [_userDefaults removeObserver:self forKeyPath:aKey]; }
            [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
            _privilegesObserver = nil;
            _timeoutObserver = nil;
        }
    }
}

- (NSMenu*)dockMenu
 {
     // initialize our menu
     _dockTileMenu = [[NSMenu alloc] init];
     [_dockTileMenu setAutoenablesItems:NO];

     // add the "toggle privileges" item
     if (_cliPath && [[NSFileManager defaultManager] isExecutableFileAtPath:_cliPath]) {
         NSMenuItem *privilegesItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"toggleMenuItem", @"Localizable", _pluginBundle, nil)
                                                                 action:@selector(togglePrivileges)
                                                          keyEquivalent:@""];
         [privilegesItem setTarget:self];
         
         NSString *limitToUser = ([_userDefaults objectIsForcedForKey:@"LimitToUser"]) ? [_userDefaults objectForKey:@"LimitToUser"] : nil;
         NSString *limitToGroup = ([_userDefaults objectIsForcedForKey:@"LimitToGroup"]) ? [_userDefaults objectForKey:@"LimitToGroup"] : nil;
         BOOL reasonRequired = ([_userDefaults objectIsForcedForKey:@"ReasonRequired"]) ? [_userDefaults boolForKey:@"ReasonRequired"] : NO;
         
         if (([_userDefaults objectIsForcedForKey:@"EnforcePrivileges"] && ([[_userDefaults stringForKey:@"EnforcePrivileges"] isEqualToString:@"admin"] || [[_userDefaults stringForKey:@"EnforcePrivileges"] isEqualToString:@"user"] || [[_userDefaults stringForKey:@"EnforcePrivileges"] isEqualToString:@"none"])) ||
             (limitToUser && ![[limitToUser lowercaseString] isEqualToString:_currentUser]) ||
             (!limitToUser && limitToGroup && ![MTIdentity getGroupMembershipForUser:_currentUser groupName:limitToGroup error:nil]) ||
             ([_userDefaults objectIsForcedForKey:@"RequireAuthentication"] && [_userDefaults boolForKey:@"RequireAuthentication"]) || reasonRequired) {
             [privilegesItem setEnabled:NO];
         }
         
         [_dockTileMenu addItem:privilegesItem];
     }
         
     // insert a separator
     [_dockTileMenu addItem:[NSMenuItem separatorItem]];
     
     // add the "lock screen" item
     NSMenuItem *lockScreenItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"lockScreenMenuItem", @"Localizable", _pluginBundle, nil)
                                                             action:@selector(lockScreen)
                                                      keyEquivalent:@""];
     [lockScreenItem setTarget:self];
     [_dockTileMenu addItem:lockScreenItem];
     
     // add the "show login window" item
     NSMenuItem *loginWindowItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"loginWindowMenuItem", @"Localizable", _pluginBundle, nil)
                                                             action:@selector(showLoginWindow)
                                                      keyEquivalent:@""];
     [loginWindowItem setTarget:self];
     [_dockTileMenu addItem:loginWindowItem];
     
     return _dockTileMenu;
 }
 
 - (void)togglePrivileges
 {
     // invalidate the timer
     [self invalidateToggleTimer];
          
     NSError *userError = nil;
     BOOL isAdmin = [self checkAdminPrivilegesForUser:_currentUser error:&userError];

     if (!userError) {
         
         [NSTask launchedTaskWithLaunchPath:_cliPath
                                  arguments:(isAdmin) ? [NSArray arrayWithObject:@"--remove"] : [NSArray arrayWithObject:@"--add"]
          ];
         
         if (!isAdmin && !([_userDefaults objectIsForcedForKey:@"EnforcePrivileges"] && ([[_userDefaults stringForKey:@"EnforcePrivileges"] isEqualToString:@"admin"] || [[_userDefaults stringForKey:@"EnforcePrivileges"] isEqualToString:@"user"] || [[_userDefaults stringForKey:@"EnforcePrivileges"] isEqualToString:@"none"]))) { [self startToggleTimer]; }
    }
}

- (void)startToggleTimer
{
    // define the default timeout
    NSInteger timeoutValue = DEFAULT_DOCK_TIMEOUT;

    // check if a timeout has been configured via profile
    if ([_userDefaults objectForKey:@"DockToggleTimeout"]) {
        
        // get the configured timeout
        timeoutValue = [_userDefaults integerForKey:@"DockToggleTimeout"];
        
    // or in the Privileges preferences
    } else {
        
        NSString *privilegesPrefsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Containers/corp.sap.privileges/Data/Library/Preferences/corp.sap.privileges"];
        NSDictionary *privilegesDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:privilegesPrefsPath];
            
        if ([privilegesDefaults objectForKey:@"DockToggleTimeout"]) {
            
            // get the configured timeout
            timeoutValue = [[privilegesDefaults valueForKey:@"DockToggleTimeout"] integerValue];
        }
    }

    if (timeoutValue > 0) {
        
        // check if a maximum timeout value has been configured and
        // correct the timeout value if needed
        if ([_userDefaults objectForKey:@"DockToggleMaxTimeout"] && ![_userDefaults objectIsForcedForKey:@"DockToggleTimeout"]) {
            
            // get the configured timeout
            NSInteger maxTimeoutValue = [_userDefaults integerForKey:@"DockToggleMaxTimeout"];
            if (maxTimeoutValue > 0 && timeoutValue > maxTimeoutValue) {
                
                // set the timeout value to the next fixed value <= maxTimeoutValue
                NSInteger fixedTimeoutValues[] = FIXED_TIMEOUT_VALUES;
                
                for (int i = sizeof(fixedTimeoutValues)/sizeof(fixedTimeoutValues[0]) - 1; i >= 0 ; i--) {
                    if (fixedTimeoutValues[i] < maxTimeoutValue) {
                        timeoutValue = fixedTimeoutValues[i];
                        break;
                    }
                }
            }
        }
        
        // set the toggle timeout (in seconds)
        _timerExpires = [NSDate dateWithTimeIntervalSinceNow:(timeoutValue * 60)];
            
        // add observers to detect wake from sleep
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@selector(sendBadgeUpdateNotification)
                                                                   name:NSWorkspaceDidWakeNotification
                                                                 object:nil
         ];
        
        // start our timer and update the badge every 60 seconds
        _toggleTimer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                                        target:self
                                                      selector:@selector(sendBadgeUpdateNotification)
                                                      userInfo:nil
                                                       repeats:YES
                        ];
    }
}

- (void)sendBadgeUpdateNotification
{
    // send a notification to update the badge
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"corp.sap.PrivilegesTimeout"
                                                                   object:_currentUser
                                                                 userInfo:nil
                                                                  options:NSNotificationDeliverImmediately
     ];
}

- (void)updateDockTileIcon:(NSDockTile*)dockTile isAdmin:(BOOL)isAdmin
{
    NSImage *dockIcon = nil;
    NSString *soundPath = nil;
    NSString *iconName = @"appicon_";
    
    NSString *limitToUser = ([_userDefaults objectIsForcedForKey:@"LimitToUser"]) ? [_userDefaults objectForKey:@"LimitToUser"] : nil;
    NSString *limitToGroup = ([_userDefaults objectIsForcedForKey:@"LimitToGroup"]) ? [_userDefaults objectForKey:@"LimitToGroup"] : nil;
        
    if (([_userDefaults objectIsForcedForKey:@"EnforcePrivileges"] &&
         ([[_userDefaults stringForKey:@"EnforcePrivileges"] isEqualToString:@"admin"] ||
          [[_userDefaults stringForKey:@"EnforcePrivileges"] isEqualToString:@"user"] ||
          [[_userDefaults stringForKey:@"EnforcePrivileges"] isEqualToString:@"none"])) ||
        (limitToUser && ![[limitToUser lowercaseString] isEqualToString:_currentUser]) ||
        (!limitToUser && limitToGroup && ![MTIdentity getGroupMembershipForUser:_currentUser groupName:limitToGroup error:nil])) {
    
        iconName = [iconName stringByAppendingString:@"managed_"];
    }
        
    if (isAdmin) {
        iconName = [iconName stringByAppendingString:@"unlocked"];
        soundPath = @"/System/Library/Frameworks/SecurityInterface.framework/Versions/A/Resources/lockOpening.aif";
    } else {
        iconName = [iconName stringByAppendingString:@"locked"];
        soundPath = @"/System/Library/Frameworks/SecurityInterface.framework/Versions/A/Resources/lockClosing.aif";
    }
    
    if (@available(macOS 10.16, *)) { iconName = [iconName stringByAppendingString:@"_new"]; }
    dockIcon = [_pluginBundle imageForResource:iconName];
    
    if ([MTVoiceOver isEnabled]) {
        NSURL *soundURL = [NSURL fileURLWithPath:soundPath];
        
        if (soundURL && [[NSFileManager defaultManager] fileExistsAtPath:soundPath]) {
            SystemSoundID soundID;
            OSStatus error = AudioServicesCreateSystemSoundID((__bridge CFURLRef)soundURL, &soundID);
            if (error == kAudioServicesNoError) { AudioServicesPlayAlertSoundWithCompletion(soundID, nil); }
        }
    }
    
    if (dockIcon) {
        NSImageView *imageView = [[NSImageView alloc] init];
        [imageView setImage:dockIcon];
        [dockTile setContentView:imageView];
        [dockTile display];
    }
}

- (void)updateDockTileBadge:(NSDockTile*)dockTile
{
    // get the remaining time
    NSInteger minutesLeft = ceil([self->_timerExpires timeIntervalSinceNow]/60);

    if (minutesLeft > 0 && self->_toggleTimer) {
        
        // to make VoiceOver say "x minutes" instead of "x new elements", we have to append
        // the word "min" to the numeric value. This makes VoiceOver speak the remaining
        // time correctly in every language.
        if ([MTVoiceOver isEnabled]) {
            [dockTile setBadgeLabel:[NSString stringWithFormat:@"%ld min", (long)minutesLeft]];
            [[NSUserDefaults standardUserDefaults] setInteger:minutesLeft forKey:@"PrivilegesTimeLeft"];
            
        } else {
            [dockTile setBadgeLabel:[NSString stringWithFormat:@"%ld", (long)minutesLeft]];
        }
        
    } else {
        [dockTile setBadgeLabel:nil];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"PrivilegesTimeLeft"];
    }
}

- (void)invalidateToggleTimer
{
    if (_toggleTimer) {

        [_toggleTimer invalidate];
        _toggleTimer = nil;
        
        // remove the observer
        [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    }
}

- (BOOL)checkAdminPrivilegesForUser:(NSString*)userName error:(NSError**)error
{
    BOOL isAdmin = [MTIdentity getGroupMembershipForUser:userName groupID:ADMIN_GROUP_ID error:error];
    
    return isAdmin;
}

- (void)lockScreen
{
    SACLockScreenImmediate();
}

- (void)showLoginWindow
{
    NSString *launchPath = @"/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession";
    
    if (launchPath && [[NSFileManager defaultManager] isExecutableFileAtPath:launchPath]) {
        [NSTask launchedTaskWithLaunchPath:launchPath arguments:[NSArray arrayWithObject:@"-suspend"]];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _userDefaults && ([keyPath isEqualToString:@"DockToggleTimeout"] ||
                                    [keyPath isEqualToString:@"DockToggleMaxTimeout"]) &&
                                    _toggleTimer) {

        // workaround for bug that is causing observeValueForKeyPath to be called multiple times.
        // so every notification resets the timer and if we got no new notifications for 2 seconds,
        // we evaluate the changes.
        if (_fixTimeoutObserverTimer) { [_fixTimeoutObserverTimer invalidate]; };
        _fixTimeoutObserverTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                                   repeats:NO
                                                                     block:^(NSTimer* _Nonnull timer) {
            // get the remaining time
            NSInteger minutesLeft = ceil([self->_timerExpires timeIntervalSinceNow]/60);
            
            // get the configured values
            NSInteger timeoutValue = [self->_userDefaults integerForKey:@"DockToggleTimeout"];
            NSInteger maxTimeoutValue = [self->_userDefaults integerForKey:@"DockToggleMaxTimeout"];
            
            // restart the timer if the configured timeout or the configured maximum timeout
            // is below the timer's current value
            if ((timeoutValue > 0 && timeoutValue < minutesLeft) ||
                (![self->_userDefaults objectIsForcedForKey:@"DockToggleTimeout"] && maxTimeoutValue > 0 && maxTimeoutValue < minutesLeft)) {
                [self invalidateToggleTimer];
                [self startToggleTimer];
                [self enforcePrivileges];
            }
         }];
        
    } else if (object == _userDefaults && ([keyPath isEqualToString:@"EnforcePrivileges"] ||
                                           [keyPath isEqualToString:@"LimitToUser"] ||
                                           [keyPath isEqualToString:@"LimitToGroup"] ||
                                           [keyPath isEqualToString:@"ReasonRequired"])) {
        
        // workaround for bug that is causing observeValueForKeyPath to be called multiple times.
        // so every notification resets the timer and if we got no new notifications for 2 seconds,
        // we evaluate the changes.
        if (_fixTimeoutObserverTimer) { [_fixTimeoutObserverTimer invalidate]; }
        _fixTimeoutObserverTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                            repeats:NO
                                                              block:^(NSTimer* _Nonnull timer) {
             
            // make sure the changes are applied and the Dock tile
            // displays correctly reflects the (changed) situation
            [self enforcePrivileges];
         }];
    }
}

- (void)enforcePrivileges
{
    // check current privileges if we are managed ...
    if ([_userDefaults objectIsForcedForKey:@"EnforcePrivileges"]) {
        
        BOOL isAdmin = [self checkAdminPrivilegesForUser:_currentUser error:nil];
        NSString *enforcedPrivileges = [_userDefaults objectForKey:@"EnforcePrivileges"];

        if (([enforcedPrivileges isEqualToString:@"admin"] && !isAdmin) || ([enforcedPrivileges isEqualToString:@"user"] && isAdmin)) {

            // ... and toggle privileges if needed
            [self togglePrivileges];
            
        } else {
            
            // invalidate the timer because the privileges have been enforced
            // now. So there's no need for a timeout anymore because the current
            // privileges cannot be changed anymore.
            [self invalidateToggleTimer];
        
            // update the Dock tile
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"corp.sap.PrivilegesChanged"
                                                                           object:_currentUser
                                                                         userInfo:nil
                                                                          options:NSNotificationDeliverImmediately
             ];
        }
        
    } else {
    
        // ... or just update the Dock tile
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"corp.sap.PrivilegesChanged"
                                                                       object:_currentUser
                                                                     userInfo:nil
                                                                      options:NSNotificationDeliverImmediately
         ];
    }
}

@end
