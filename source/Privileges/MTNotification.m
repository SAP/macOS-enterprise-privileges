/*
 MTNotification.m
 Copyright 2016-2022 SAP SE
 
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

#import "MTNotification.h"

@implementation MTNotification

+ (void)sendNotificationWithTitle:(NSString *)notificationTitle andMessage:(NSString *)notificationMsg replaceExisting:(BOOL)replaceExisting delegate:(id)notificationDelegate
{
    NSString *notificationID = [[NSBundle mainBundle] bundleIdentifier];
    NSMutableDictionary *notificationOptions = [NSMutableDictionary dictionaryWithObjectsAndKeys:notificationID, @"notificationID", nil];
    
    NSUserNotification *theNotification = [[NSUserNotification alloc] init];
    [theNotification setTitle:notificationTitle];
    [theNotification setInformativeText:notificationMsg];
    [theNotification setSoundName:nil];
    [theNotification setHasActionButton:NO];
    [theNotification setUserInfo:notificationOptions];
    
    if (replaceExisting == YES) { [self removeNotifications]; }
    
    NSUserNotificationCenter *theNotificationCenter = [NSUserNotificationCenter defaultUserNotificationCenter];
    [theNotificationCenter setDelegate:notificationDelegate];
    [theNotificationCenter deliverNotification:theNotification];
}

+ (void)removeNotifications
{
    NSString *notificationID = [[NSBundle mainBundle] bundleIdentifier];
    NSUserNotificationCenter *theNotificationCenter = [NSUserNotificationCenter defaultUserNotificationCenter];
    for (NSUserNotification *deliveredNotification in [theNotificationCenter deliveredNotifications]) {
        if ([[[deliveredNotification userInfo] objectForKey:@"notificationID"] isEqualToString:notificationID]) {
            [theNotificationCenter removeDeliveredNotification:deliveredNotification];
        }
    }
}

@end
