/*
    MTLocalNotification.m
    Copyright 2022-2024 SAP SE
     
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

#import "MTLocalNotification.h"
#import "Constants.h"

@implementation MTLocalNotification

- (void)requestAuthorizationWithCompletionHandler:(void (^)(BOOL granted, NSError *error))completionHandler
{
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(
                                             UNAuthorizationOptionAlert |
                                             UNAuthorizationOptionSound |
                                             UNAuthorizationOptionBadge
                                             )
                          completionHandler:^(BOOL granted, NSError *error) {
        if (completionHandler) { completionHandler(granted, error); }
    }];
}

- (void)sendNotificationWithTitle:(NSString*)title
                          message:(NSString*)message
                         userInfo:(NSDictionary*)userInfo
                  replaceExisting:(BOOL)replaceExisting
                completionHandler:(void (^)(NSError *error))completionHandler;
{
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    [content setTitle:title];
    [content setBody:message];
    [content setSound:[UNNotificationSound defaultSound]];
    [content setUserInfo:userInfo];

    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                                          content:content
                                                                          trigger:nil
    ];
    
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center setDelegate:self];
            
    // remove existing notifications
    if (replaceExisting) {
        [center removeAllDeliveredNotifications];
        [NSThread sleepForTimeInterval:.5];
    }
    
    [center addNotificationRequest:request
             withCompletionHandler:^(NSError *error) {
        
        if (completionHandler) { completionHandler(error); }
    }];
}

#pragma mark UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter*)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    completionHandler(UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler
{
    completionHandler();
}

@end
