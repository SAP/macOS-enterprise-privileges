/*
    MTReasonAccessoryController.m
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

#import "MTReasonAccessoryController.h"
#import "MTPrivileges.h"
#import "Constants.h"

@interface MTReasonAccessoryController ()
@property (nonatomic, strong, readwrite) NSString *reasonPlaceHolder;
@end

@implementation MTReasonAccessoryController

- (void)viewDidLoad
{
    [super viewDidLoad];

    MTPrivileges *privilegesApp = [[MTPrivileges alloc] init];
    
    [_predefinedReasonsButton setHidden:YES];
    [[_predefinedReasonsButton menu] removeAllItems];
    
    NSInteger minLength = [privilegesApp reasonMinLength];
    _reasonPlaceHolder = [NSString localizedStringWithFormat:NSLocalizedString(@"minLengthPlaceholder", nil), minLength];
    
    [_reasonTextField setPlaceholderString:_reasonPlaceHolder];
        
    // create the menu with pre-defined reasons (if configured)
    if ([privilegesApp reasonRequired]) {
        
        NSArray *predefinedReasons = [privilegesApp predefinedReasons];
    
        if (predefinedReasons && [predefinedReasons count] > 0) {
            
            NSString *languageCode = [[NSLocale currentLocale] languageCode];
            
            for (NSDictionary *aReason in predefinedReasons) {

                if ([aReason isKindOfClass:[NSDictionary class]]) {
                    
                    NSString *localizedReasonString = [aReason objectForKey:languageCode];
                    if (!localizedReasonString) { localizedReasonString = [aReason objectForKey:@"default"]; }
                    if (!localizedReasonString) { localizedReasonString = [aReason objectForKey:@"en"]; }
                    
                    if (localizedReasonString) {
                        
                        [[_predefinedReasonsButton menu] addItemWithTitle:localizedReasonString
                                                                   action:nil
                                                            keyEquivalent:@""
                        ];
                    }
                }
            }
            
            if ([[[_predefinedReasonsButton menu] itemArray] count] > 0) {
                
                if ([privilegesApp useStrictPredefinedReasons]) {
                    
                    [_reasonTextField setHidden:YES];
                    
                } else {
                    
                    NSMenuItem *otherMenuItem = [[NSMenuItem alloc] init];
                    [otherMenuItem setTitle:NSLocalizedString(@"otherMenuEntry", nil)];
                    [otherMenuItem setAction:nil];
                    [otherMenuItem setTarget:self];
                    [otherMenuItem setKeyEquivalent:@""];
                    [otherMenuItem setTag:1000];
                    
                    [[_predefinedReasonsButton menu] addItem:otherMenuItem];
                    
                    // select the "Other…" menu entry to make sure people cannot
                    // just click "Request Privileges" without actually selecting
                    // a reason for getting admin rights.
                    [_predefinedReasonsButton selectItemWithTag:1000];
                }

                [_predefinedReasonsButton setHidden:NO];
            }
        }
    }
    
    // make sure everything is in place, even if the text field is hidden
    [_stackView layoutSubtreeIfNeeded];
    
    NSSize fittingSize = [_stackView fittingSize];
    NSRect frame = [[self view] frame];
    frame.size = fittingSize;
    [[self view] setFrame:frame];
    [[self view] layoutSubtreeIfNeeded];
}

- (IBAction)selectPredefinedReason:(id)sender
{
    if ([_predefinedReasonsButton selectedTag] == 1000) {

        [_reasonTextField setEnabled:YES];
        [_reasonTextField setTextColor:[NSColor textColor]];
        [_reasonTextField setPlaceholderString:_reasonPlaceHolder];
        [_reasonTextField selectText:nil];
        
    } else {
        
        [_reasonTextField setEnabled:NO];
        [_reasonTextField setTextColor:[NSColor clearColor]];
        [_reasonTextField setPlaceholderString:nil];
    }
}

@end
