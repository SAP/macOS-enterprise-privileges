/*
    MTUpdateChecker.m
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

#import "MTUpdateChecker.h"

@interface MTUpdateChecker ()
@property (nonatomic, strong, readwrite) NSString *bundleID;
@end

@implementation MTUpdateChecker

- (instancetype)initWithBundleIdentifier:(NSString*)identifier
{
    self = [super init];
    
    if (self) {
        
        if ([identifier length] > 0) {
            
            _bundleID = identifier;
            
        } else {
            
            self = nil;
        }
    }
    
    return self;
}

- (BOOL)isAvailable
{
    NSURL *appURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:_bundleID];
    return (appURL != nil);
}

- (BOOL)launch
{
    BOOL launched = NO;
    
    NSURL *appURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:_bundleID];
    
    if (appURL) {
        
        NSWorkspaceOpenConfiguration* configuration = [[NSWorkspaceOpenConfiguration alloc] init];
        [configuration setActivates:YES];
        
        [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                              configuration:configuration
                                          completionHandler:nil
        ];
        
        launched = YES;
    }
    
    return launched;
}

@end
