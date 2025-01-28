/*
    MTLocalNotification.h
    Copyright 2022-2025 SAP SE
     
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

#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>

@interface MTLocalNotification : NSObject

/*!
 @enum          MTLocalNotificationType
 @abstract      Specifies the type of a notification.
 @constant      MTLocalNotificationTypeNoChange Specifies a notification that informs the user that privileges have not been changed.
 @constant      MTLocalNotificationTypeGrantSuccess Specifies a notification that informs the user that administrator privileges have been granted.
 @constant      MTLocalNotificationTypeRevokeSuccess Specifies a notification that informs the user that administrator privileges have been revoked.
 @constant      MTLocalNotificationTypeError Specifies a notification that informs the user that privileges could not be changed due to an error.
 @constant      MTLocalNotificationTypeRenew Specifies a notification that informs the user that administrator privileges are about to expire and asks to renew privileges.
 @constant      MTLocalNotificationTypeRenewSuccess Specifies a notification that informs the user that administrator privileges have been renewed.
*/
typedef enum {
    MTLocalNotificationTypeNoChange         = 0,
    MTLocalNotificationTypeGrantSuccess     = 1,
    MTLocalNotificationTypeRevokeSuccess    = 2,
    MTLocalNotificationTypeError            = 3,
    MTLocalNotificationTypeRenew            = 4,
    MTLocalNotificationTypeRenewSuccess     = 5,
} MTLocalNotificationType;

@property (nonatomic, strong, readwrite) NSArray<UNNotificationAction*> *actions;
@property (nonatomic, strong, readwrite) NSString *categoryIdentifier;
@property (weak) id <UNUserNotificationCenterDelegate> delegate;

/*!
 @method        requestAuthorizationWithCompletionHandler:
 @abstract      Requests a user's authorization to allow local and remote notifications for the app.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if the user granted authorization, otherwise returns NO. In case of an error the error object might contain
                information about the error that caused the operation to fail.
 */
- (void)requestAuthorizationWithCompletionHandler:(void (^)(BOOL granted, NSError *error))completionHandler;

/*!
 @method        sendNotificationWithTitle:message:userInfo:replaceExisting:
 @abstract      Sends a notification to the user notificatiion center.
 @param         title The title of the notification.
 @param         message The notification body (the message).
 @param         userInfo An optional dictionary containing custom data to associate with the notification.
 @param         replaceExisting A boolean specifying if existing notification should be removed or not.
 @param         action A boolean specifying if the notification should have an action attached.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    The returned error object might contain error information if an error occurred or will be nil if no error occurred.
 */
- (void)sendNotificationWithTitle:(NSString*)title
                          message:(NSString*)message
                         userInfo:(NSDictionary*)userInfo
                  replaceExisting:(BOOL)replaceExisting
                           action:(BOOL)action
                completionHandler:(void (^)(NSError *error))completionHandler;

@end
