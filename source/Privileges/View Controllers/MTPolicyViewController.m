/*
    MTPolicyViewController.m
    Copyright 2016-2026 SAP SE
     
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

#import "MTPolicyViewController.h"
#import "MTPrivileges.h"
#import "Constants.h"

@interface MTPolicyViewController ()
@property (nonatomic, strong, readwrite) MTPrivileges *privilegesApp;
@property (unsafe_unretained) IBOutlet NSTextView *policyTextView;
@end

@implementation MTPolicyViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _privilegesApp = [[MTPrivileges alloc] init];
    NSAttributedString *policyString = [_privilegesApp policyBanner];
    
    if ([policyString length] > 0) {
        
        [_policyTextView setTextContainerInset:NSMakeSize(10.0, 10.0)];
        [[_policyTextView textStorage] setAttributedString:policyString];
        [_policyTextView setTextColor:[NSColor textColor]];
    }
}

- (IBAction)declinePolicy:(id)sender
{
    [NSApp stopModal];
}

- (IBAction)acceptPolicy:(id)sender
{
    [NSApp stopModalWithCode:NSModalResponseContinue];
    [_privilegesApp setPolicyAccepted:YES];
}

@end
