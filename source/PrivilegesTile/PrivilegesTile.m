/*
 PrivilegesTile.m
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

#import "PrivilegesTile.h"
#import "MTAuthCommon.h"
#import "MTIdentity.h"

@interface PrivilegesTile ()
@property (retain) id privilegesObserver;
@property (retain) id timeoutObserver;
@property (nonatomic, strong, readwrite) NSString *cliPath;
@property (nonatomic, strong, readwrite) NSBundle *mainBundle;
@property (nonatomic, strong, readwrite) NSMenu *dockTileMenu;
@property (nonatomic, strong, readwrite) NSTimer *toggleTimer;
@property (nonatomic, strong, readwrite) NSTimer *fixTimeoutObserverTimer;
@property (nonatomic, strong, readwrite) NSDate *timerExpires;
@property (nonatomic, strong, readwrite) NSUserDefaults *userDefaults;
@end

extern void SACLockScreenImmediate (void);

@implementation PrivilegesTile

- (void)setDockTile:(NSDockTile*)dockTile
{
    if (dockTile) {
        
        // initialize our userDefaults and remove an existing "EnforcePrivileges" key
        // form our plist. This key should just be used in a configuration profile.
        _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"corp.sap.privileges"];
        [_userDefaults removeObjectForKey:@"EnforcePrivileges"];
 
        // get the name of the current user
        NSString *userName = NSUserName();
        
        // get the path to our command line tool
        NSString *pluginPath = [[NSBundle bundleForClass:[self class]] bundlePath];
        NSString *mainbundlePath = [[[pluginPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
        _mainBundle = [NSBundle bundleWithPath:mainbundlePath];
        _cliPath = [_mainBundle pathForResource:@"PrivilegesCLI" ofType:nil];
        
        // register an observer to watch for privilege changes
        _privilegesObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"corp.sap.PrivilegesChanged"
                                                                                           object:userName
                                                                                            queue:nil
                                                                                       usingBlock:^(NSNotification *notification) {
            BOOL isAdmin = [self checkAdminPrivilegesForUser:userName error:nil];
            
            // invalidate the timer if the user is not admin anymore
            if (!isAdmin) { [self invalidateToggleTimer]; }
            
            // update the Dock tile icon ...
            [self updateDockTileIcon:dockTile isAdmin:isAdmin];
            
            // ... and also the Dock tile's badge
            [self updateDockTileBadge:dockTile];
                                                                                       }];
        
        // register an observer for the toggle timeout
        _timeoutObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"corp.sap.PrivilegesTimeout"
                                                                                        object:userName
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
        
        // Start observing our preferences to make sure we'll get notified as soon as someting changes (e.g. a configuration
        // profile has been installed). Unfortunately we cannot use the NSUserDefaultsDidChangeNotification here, because
        // it wouldn't be called if changes to our prefs would be made from outside this application.
        [_userDefaults addObserver:self
                        forKeyPath:@"EnforcePrivileges"
                           options:NSKeyValueObservingOptionNew
                           context:nil];
        
        // make sure the Dock tile has the correct icon on load and enforce
        // privileges, if a configuration profile has been already installed
        // and the enforced privileges does not match the current ones.
        [self enforcePrivileges];
    
    } else {
        
        // If dockTile is nil, the item has been removed from Dock, so we remove our observers.
        // Actually this is not really needed here but is best practice.
        if (_privilegesObserver || _timeoutObserver) {
            [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
            [_userDefaults removeObserver:self forKeyPath:@"EnforcePrivileges"];
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
         NSMenuItem *privilegesItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"toggleMenuItem", @"Localizable", _mainBundle, nil)
                                                                 action:@selector(togglePrivileges)
                                                          keyEquivalent:@""];
         [privilegesItem setTarget:self];
         if ([_userDefaults objectIsForcedForKey:@"EnforcePrivileges"]) { [privilegesItem setEnabled:NO]; }
         [_dockTileMenu addItem:privilegesItem];
     }
         
     // insert a separator
     [_dockTileMenu addItem:[NSMenuItem separatorItem]];
     
     // add the "lock screen" item
     NSMenuItem *lockScreenItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"lockScreenMenuItem", @"Localizable", _mainBundle, nil)
                                                             action:@selector(lockScreen)
                                                      keyEquivalent:@""];
     [lockScreenItem setTarget:self];
     [_dockTileMenu addItem:lockScreenItem];
     
     // add the "show login window" item
     NSMenuItem *loginWindowItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"loginWindowMenuItem", @"Localizable", _mainBundle, nil)
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
     BOOL isAdmin = [self checkAdminPrivilegesForUser:NSUserName() error:&userError];

     if (!userError) {
         
         [NSTask launchedTaskWithLaunchPath:_cliPath
                                  arguments:(isAdmin) ? [NSArray arrayWithObject:@"--remove"] : [NSArray arrayWithObject:@"--add"]
          ];
         
         if (!isAdmin && ![_userDefaults objectIsForcedForKey:@"EnforcePrivileges"]) {
             
             // define the default timeout
             NSInteger timeoutValue = DEFAULT_DOCK_TIMEOUT;
             
             if ([_userDefaults objectForKey:@"DockToggleTimeout"]) {
                 
                 // get the configured timeout
                 timeoutValue = [_userDefaults integerForKey:@"DockToggleTimeout"];
             }
             
             if (timeoutValue > 0) {
                 
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
    }
}

- (void)sendBadgeUpdateNotification
{
    // send a notification to update the badge
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"corp.sap.PrivilegesTimeout"
                                                                   object:NSUserName()
                                                                 userInfo:nil
                                                                  options:NSNotificationDeliverImmediately
     ];
}

- (void)updateDockTileIcon:(NSDockTile*)dockTile isAdmin:(BOOL)isAdmin
{
    NSImage *dockIcon = nil;
    NSBundle *pluginBundle = [NSBundle bundleForClass:[self class]];
    NSString *iconName = ([_userDefaults objectIsForcedForKey:@"EnforcePrivileges"]) ? @"appicon_managed_" : @"appicon_";
        
    if (isAdmin) {
        dockIcon = [pluginBundle imageForResource:[iconName stringByAppendingString:@"unlocked"]];
    } else {
        dockIcon = [pluginBundle imageForResource:[iconName stringByAppendingString:@"locked"]];
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
        [dockTile setBadgeLabel:[NSString stringWithFormat:@"%ld", (long)minutesLeft]];
    } else {
        [dockTile setBadgeLabel:nil];
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
    BOOL isAdmin = NO;
    int groupID = [MTIdentity gidFromGroupName:ADMIN_GROUP_NAME];
    
    if (groupID != -1) {
        isAdmin = [MTIdentity getGroupMembershipForUser:userName groupID:groupID error:error];
    }
    
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
    if (object == _userDefaults && [keyPath isEqualToString:@"EnforcePrivileges"]) {
        
        // workaround for bug that is causing observeValueForKeyPath to be called multiple times.
        // so every notification resets the timer and if we got no new notifications for 2 seconds,
        // we evaluate the changes.
        if (_fixTimeoutObserverTimer) { [_fixTimeoutObserverTimer invalidate]; }
        _fixTimeoutObserverTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                            repeats:NO
                                                              block:^(NSTimer * _Nonnull timer) {
             
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
        
        BOOL isAdmin = [self checkAdminPrivilegesForUser:NSUserName() error:nil];
        NSString *enforcedPrivileges = [_userDefaults objectForKey:@"EnforcePrivileges"];

        if (([enforcedPrivileges isEqualToString:@"admin"] && !isAdmin) || ([enforcedPrivileges isEqualToString:@"user"] && isAdmin)) {

            // ... and toggle privileges if needed
            [self togglePrivileges];
            
        } else {
            
            // invalidate the timer because the privileges have been enforced
            // now. So there's no need for a timeout anymore because the current
            // privileges cannot be changed anymore.
            [self invalidateToggleTimer];
        
            // or just update the Dock tile
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"corp.sap.PrivilegesChanged"
                                                                           object:NSUserName()
                                                                         userInfo:nil
                                                                          options:NSNotificationDeliverImmediately
             ];
        }
        
    } else {
    
        // ... or just update the Dock tile
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"corp.sap.PrivilegesChanged"
                                                                       object:NSUserName()
                                                                     userInfo:nil
                                                                      options:NSNotificationDeliverImmediately
         ];
    }
}

@end
