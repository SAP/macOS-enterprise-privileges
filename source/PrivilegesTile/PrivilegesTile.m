/*
 PrivilegesTile.m
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

#import "PrivilegesTile.h"
#import "MTAuthCommon.h"
#import "MTIdentity.h"

@interface PrivilegesTile ()
@property (retain) id privilegesObserver;
@property (retain) id timeoutObserver;
@property (atomic, copy, readwrite) NSMenu *theDockMenu;
@property (atomic, copy, readwrite) NSString *cliPath;
@property (atomic, copy, readwrite) NSBundle *mainBundle;
@property (atomic, strong, readwrite) NSTimer *toggleTimer;
@property (atomic, strong, readwrite) NSDate *timerExpires;
@end

extern void SACLockScreenImmediate (void);

@implementation PrivilegesTile

- (void)setDockTile:(NSDockTile*)dockTile
{
    if (dockTile) {
        
        NSString *userName = NSUserName();
        
        // register an observer to watch privilege changes
        _privilegesObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"corp.sap.PrivilegesChanged"
                                                                                           object:userName
                                                                                            queue:nil
                                                                                       usingBlock:^(NSNotification *notification) {
                                                                                           
                                                                                           NSDictionary *userInfo = [notification userInfo];
                                                                                           NSString *accountState = [userInfo valueForKey:@"accountState"];
                                                                                           BOOL isAdmin = (accountState && [accountState isEqualToString:@"admin"]) ? YES : NO;
                                                                                           [self updateDockTile:dockTile isAdmin:isAdmin];
                                                                                       }];
        // register an observer for the toggle timeout
        _timeoutObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"corp.sap.PrivilegesTimeout"
                                                                                        object:userName
                                                                                         queue:nil
                                                                                    usingBlock:^(NSNotification *notification) {
                                                                                        
                                                                                        NSDictionary *userInfo = [notification userInfo];
                                                                                        NSInteger timeLeft = [[userInfo valueForKey:@"timeLeft"] integerValue];
                                                                                        
                                                                                        if (timeLeft > 0) {
                                                                                            [dockTile setBadgeLabel:[NSString stringWithFormat:@"%ld", (long)timeLeft]];
                                                                                        } else {
                                                                                            [dockTile setBadgeLabel:nil];
                                                                                        }
                                                                                    }];
        
        // initially check the group membership to display the correct icon at login etc.
        NSError *userError = nil;
        BOOL isAdmin = [self checkAdminPrivilegesForUser:userName error:&userError];
        if (userError == nil) { [self updateDockTile:dockTile isAdmin:isAdmin]; }
        
        // get the path to our command line tool
        NSString *pluginPath = [[NSBundle bundleForClass:[self class]] bundlePath];
        NSString *bundlePath = [[[pluginPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
        _mainBundle = [NSBundle bundleWithPath:bundlePath];
        _cliPath = [_mainBundle pathForResource:@"PrivilegesCLI" ofType:nil];
        
    } else {
        
        [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (void)updateDockTile:(NSDockTile*)dockTile isAdmin:(BOOL)isAdmin
{
    NSString *imagePath;
    NSBundle *pluginBundle = [NSBundle bundleForClass:[self class]];
    
    if (isAdmin) {
        imagePath = [pluginBundle pathForImageResource:@"appicon_unlocked.icns"];
        
    } else {
        
        // if there is currently a timer running, reset it because the user already
        // switched back to standard privileges
        [self resetToggleTimer];
        
        imagePath = [pluginBundle pathForImageResource:@"appicon_locked.icns"];
        [dockTile setBadgeLabel:nil];
    }
    
    NSImageView *imageView = [[NSImageView alloc] init];
    [imageView setImage:[[NSImage alloc] initWithContentsOfFile:imagePath]];
    [dockTile setContentView:imageView];
    [dockTile display];
}

- (NSMenu*)dockMenu
 {
     if (_theDockMenu) {
         return _theDockMenu;
         
     } else {
         _theDockMenu = nil;
         
         if (_cliPath && [[NSFileManager defaultManager] isExecutableFileAtPath:_cliPath]) {
         
             // add the "privileges" item
             _theDockMenu = [[NSMenu alloc] init];
             NSMenuItem *privilegesItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"toggleMenuItem", @"Localizable", _mainBundle, nil)
                                                                     action:@selector(togglePrivileges)
                                                              keyEquivalent:@""];
             [privilegesItem setTarget:self];
             [_theDockMenu insertItem:privilegesItem atIndex:0];
             
             // insert a separator
             [_theDockMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
             
             // add the "lock screen" item
             NSMenuItem *lockScreenItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"lockScreenMenuItem", @"Localizable", _mainBundle, nil)
                                                                     action:@selector(lockScreen)
                                                              keyEquivalent:@""];
             [lockScreenItem setTarget:self];
             [_theDockMenu insertItem:lockScreenItem atIndex:2];
             
             // add the "show login window" item
             NSMenuItem *loginWindowItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringFromTableInBundle(@"loginWindowMenuItem", @"Localizable", _mainBundle, nil)
                                                                     action:@selector(showLoginWindow)
                                                              keyEquivalent:@""];
             [loginWindowItem setTarget:self];
             [_theDockMenu insertItem:loginWindowItem atIndex:3];
         }
     }
     
     return _theDockMenu;
 }
 
 - (void)togglePrivileges
 {
     // we remove the admin rights after a couple of minutes
     NSInteger timeoutValue = 20;
     NSDictionary *prefsDict = [[NSUserDefaults standardUserDefaults] persistentDomainForName:[_mainBundle bundleIdentifier]];
     if ([prefsDict objectForKey:@"DockToggleTimeout"]) {
         
         // get the currently selected timeout
         timeoutValue = [[prefsDict valueForKey:@"DockToggleTimeout"] integerValue];
     }
     BOOL switchTemporary = (timeoutValue > 0) ? YES : NO;
     
     // if there is currently a timer running, reset it
     [self resetToggleTimer];

     NSError *userError = nil;
     BOOL isAdmin = [self checkAdminPrivilegesForUser:NSUserName() error:&userError];

     if (userError == nil) {
         NSTask *theTask = [[NSTask alloc] init];
         [theTask setLaunchPath:_cliPath];
         
         if (isAdmin) {
             [theTask setArguments:[NSArray arrayWithObject:@"--remove"]];
             
         } else {
             
             [theTask setArguments:[NSArray arrayWithObject:@"--add"]];
             
             if (switchTemporary) {
                 
                 // set the toggle timeout (in seconds)
                 _timerExpires = [NSDate dateWithTimeIntervalSinceNow:(timeoutValue * 60)];
                 
                 // add observers to detect wake from sleep
                 [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                                        selector:@selector(updateToggleBadge)
                                                                            name:NSWorkspaceDidWakeNotification
                                                                          object:nil];
                 // send an initial notification
                 [self updateToggleBadge];
             }
         }
         
         [theTask launch];
    }
}

- (void)updateToggleBadge
{
    // update the dock tile badge
    NSInteger minutesLeft = ceil([_timerExpires timeIntervalSinceNow]/60);
    [self sendTimeoutUpdate:minutesLeft];
#ifdef DEBUG
    NSLog(@"SAPCorp: %ld minutes left", (long)minutesLeft);
#endif
    
    if (minutesLeft > 0) {
#ifdef DEBUG
        NSLog(@"SAPCorp: Setting timer");
#endif
        // initialize the toggle timer ...
        _toggleTimer = [NSTimer scheduledTimerWithTimeInterval:60
                                                        target:self
                                                      selector:@selector(updateToggleBadge)
                                                      userInfo:nil
                                                       repeats:NO];
    } else {
#ifdef DEBUG
        NSLog(@"SAPCorp: Switching privileges");
#endif
        [self togglePrivileges];
    }
}

- (void)resetToggleTimer
{
    if (_toggleTimer) {
#ifdef DEBUG
        NSLog(@"SAPCorp: Invalidating timer and removing observers");
#endif
        // invalidate the timer
        [_toggleTimer invalidate];
        _toggleTimer = nil;
        
        // remove the observer
        [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    }
}

- (void)sendTimeoutUpdate:(NSInteger)timeLeft
{
    // send a notification to update the Dock tile
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"corp.sap.PrivilegesTimeout"
                                                                   object:NSUserName()
                                                                 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:timeLeft], @"timeLeft", nil]
                                                                  options:NSNotificationDeliverImmediately
     ];
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

@end
