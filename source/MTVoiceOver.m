/*
MTVoiceOver.m
Copyright 2020 SAP SE

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

#import "MTVoiceOver.h"

@implementation MTVoiceOver

+ (void)postAnnouncementWithString:(NSString*)accessibilityAnnouncement forUIElement:(id)uiElement
{
    NSDictionary *announcementInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      accessibilityAnnouncement, NSAccessibilityAnnouncementKey,
                                      @(NSAccessibilityPriorityHigh), NSAccessibilityPriorityKey,
                                      nil
                                      ];
    
    NSAccessibilityPostNotificationWithUserInfo(uiElement, NSAccessibilityAnnouncementRequestedNotification, announcementInfo);
}

+ (BOOL)isEnabled
{
    BOOL isEnabled = NO;

    if (@available(macOS 10.13, *)) {
        isEnabled = [[NSWorkspace sharedWorkspace] isVoiceOverEnabled];
    } else {
        NSArray *runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.VoiceOver"];
        if ([runningApps count] > 0) { isEnabled = YES; }
    }
    
    return isEnabled;
}

@end
