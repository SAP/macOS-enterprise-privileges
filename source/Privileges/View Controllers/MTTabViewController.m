/*
    MTTabViewController.m
    Copyright 2023-2025 SAP SE
     
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

#import "MTTabViewController.h"
#import "Constants.h"

@interface MTTabViewController ()
@property (assign) BOOL allowSelection;
@end

@implementation MTTabViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // select the last tab the user selected
    NSInteger selectedTabIndex = [[NSUserDefaults standardUserDefaults] integerForKey:kMTDefaultsSettingsSelectedTabKey];
    _allowSelection = YES;
    
    if (selectedTabIndex >= 0 && selectedTabIndex < [[self tabViewItems] count]) {
        [self setSelectedTabViewItemIndex:selectedTabIndex];
    } else {
        [self setSelectedTabViewItemIndex:0];
    }
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    [self updateWindowTitle];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    [super tabView:tabView didSelectTabViewItem:tabViewItem];
    [self updateWindowTitle];

    // we ignore the initial tab selection (the one we had to define in Xcode)
    if (_allowSelection) {
        
        [[NSUserDefaults standardUserDefaults] setInteger:[tabView indexOfTabViewItem:[tabView selectedTabViewItem]]
                                                   forKey:kMTDefaultsSettingsSelectedTabKey
        ];
    }
}

- (void)updateWindowTitle
{
    // set the window title to the label of the selected tab
    NSTabViewItem *selectedItem = [[self tabView] selectedTabViewItem];
    [[[self tabView] window] setTitle:[selectedItem label]];
}

@end
