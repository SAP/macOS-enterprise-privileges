/*
    MTTabViewController.m
    Copyright 2023-2024 SAP SE
     
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

@implementation MTTabViewController

- (void)viewWillAppear
{
    [super viewWillAppear];
    [self updateWindowTitle];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    [super tabView:tabView didSelectTabViewItem:tabViewItem];
    [self updateWindowTitle];
}

- (void)updateWindowTitle
{
    // set the window title to the label of the selected tab
    NSTabViewItem *selectedItem = [[self tabView] selectedTabViewItem];
    [[[self tabView] window] setTitle:[selectedItem label]];
}

@end
