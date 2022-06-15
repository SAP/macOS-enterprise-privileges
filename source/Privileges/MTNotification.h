/*
 MTNotification.h
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

#import <Foundation/Foundation.h>

/*!
@class MTNotification
@abstract This class provides methods for creating user notifications.
*/

@interface MTNotification : NSObject

/*!
@method        sendNotificationWithTitle:andMessage:replaceExisting:delegate
@abstract      Sends a user notification.
@param         notificationTitle A string, containing the title for the notification.
@param         notificationMsg A string, containing the message text for the notification.
@param         replaceExisting A boolean, indicating if an existing notification should be replaced by the new one or not.
@param         notificationDelegate Specifies the notification delegate.
*/
+ (void)sendNotificationWithTitle:(NSString*)notificationTitle andMessage:(NSString*)notificationMsg replaceExisting:(BOOL)replaceExisting delegate:(id)notificationDelegate;

/*!
@method        removeNotification
@abstract      Removes all previously sent notifications of an app to make sure that only the most recent notification resides in notification center.
*/
+ (void)removeNotifications;

@end
