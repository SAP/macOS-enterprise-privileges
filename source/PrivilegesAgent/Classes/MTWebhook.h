/*
    MTWebhook.h
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

#import <Foundation/Foundation.h>
#import "MTPrivilegesUser.h"

/*!
 @class         MTWebhook
 @abstract      A class that provides a method to post information about a privilege change to a webhook.
*/

@interface MTWebhook : NSObject

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithURL: instead.
 */
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithURL:
 @abstract      Initialize a MTWebhook object with a given url.
 @param         url The url of the webhook.
 @discussion    Returns an initialized MTWebhook object or nil if an error occurred.
*/
- (instancetype)initWithURL:(NSURL*)url NS_DESIGNATED_INITIALIZER;

/*!
 @method        postToWebhookForUser:reason:expirationDate:completionHandler:
 @abstract      Post data about a privilege change to the webhook.
 @param         user The MTPrivilegesUser the privilege change belongs to.
 @param         reason The reason for the privilege change. Might be nil.
 @param         expiration The date the administrator privileges expire. Might be nil.
 @param         customData An optional dictionary that is added to the webhook data.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    The returned error object might contain error information if an error occurred or will be nil if no error occurred.
*/
- (void)postToWebhookForUser:(MTPrivilegesUser*)user
                      reason:(NSString*)reason
              expirationDate:(NSDate*)expiration
                  customData:(NSDictionary*)customData
           completionHandler:(void (^) (NSError *error))completionHandler;

@end

