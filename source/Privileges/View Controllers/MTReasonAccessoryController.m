/*
    MTReasonAccessoryController.m
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
            
            NSMutableArray *allReasons = [[NSMutableArray alloc] init];
            NSString *languageCode = [[NSLocale currentLocale] languageCode];
            
            for (NSDictionary *aReason in predefinedReasons) {

                if ([aReason isKindOfClass:[NSDictionary class]]) {
                    NSString *localizedReasonString = [aReason objectForKey:languageCode];
                    if (!localizedReasonString) { localizedReasonString = [aReason objectForKey:@"default"]; }
                    if (!localizedReasonString) { localizedReasonString = [aReason objectForKey:@"en"]; }
                    if (localizedReasonString) { [allReasons addObject:localizedReasonString]; }
                }
            }
            
            if ([allReasons count] > 0) { 
                
                [allReasons insertObject:NSLocalizedString(@"otherMenuEntry", nil) atIndex:0];
       
                for (NSString *aReason in allReasons) {
                    
                    [[_predefinedReasonsButton menu] addItemWithTitle:aReason
                                                               action:nil
                                                        keyEquivalent:@""
                    ];
                }
                
                [_predefinedReasonsButton setHidden:NO];
            }
        }
    }
}

- (IBAction)selectPredefinedReason:(id)sender
{
    if ([_predefinedReasonsButton indexOfSelectedItem] == 0) {

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
