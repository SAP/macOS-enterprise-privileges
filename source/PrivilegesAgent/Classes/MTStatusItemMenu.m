/*
    MTStatusItemMenu.m
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

#import "MTStatusItemMenu.h"
#import "MTPrivileges.h"
#import "Constants.h"

@implementation MTStatusItemMenu

- (instancetype)init
{
    self = [super init];
    
    if (self) { [self setUpView]; }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    
    if (self) { [self setUpView]; }
    
    return self;
}

- (void)setUpView
{
    [self setDelegate:self];
    [self setAutoenablesItems:NO];
}

- (void)updateMenu
{
    MTPrivileges *privilegesApp = [[MTPrivileges alloc] init];
    BOOL hasAdminPrivileges = [[privilegesApp currentUser] hasAdminPrivileges];

    if (hasAdminPrivileges) {

        [[self itemWithTag:1000] setTitle:NSLocalizedStringFromTable(@"revertMenuItem", @"LocalizableMenu", nil)];
        
    } else {

        [[self itemWithTag:1000] setTitle:NSLocalizedStringFromTable(@"requestMenuItem", @"LocalizableMenu", nil)];
    }
        
    [[self itemWithTag:1000] setEnabled:!([[privilegesApp currentUser] useIsRestricted] || (!hasAdminPrivileges && [privilegesApp reasonRequired]))];
    [[self itemWithTag:2000] setAlternate:(hasAdminPrivileges && [privilegesApp privilegeRenewalAllowed])];
    [[self itemWithTag:2000] setHidden:![[self itemWithTag:2000] isAlternate]];
}

- (void)menuWillOpen:(NSMenu *)menu
{
    [self updateMenu];
}

@end
