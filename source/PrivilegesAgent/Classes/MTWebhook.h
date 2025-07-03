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

#define kMTWebhookContentKeyUserName            @"user"
#define kMTWebhookContentKeyAdminRights         @"admin"
#define kMTWebhookContentKeyExpiration          @"expires"
#define kMTWebhookContentKeyReason              @"reason"
#define kMTWebhookContentKeyEventType           @"event"
#define kMTWebhookContentKeyMachineIdentifier   @"machine"
#define kMTWebhookContentKeyTimestamp           @"timestamp"
#define kMTWebhookContentKeyDelayed             @"delayed"
#define kMTWebhookContentKeyCustomData          @"custom_data"

@interface MTWebhook : NSObject <NSURLSessionDelegate>

/*!
 @property      facility
 @abstract      Returns the syslog message's facility.
 @discussion    The value of this property is MTSyslogMessageFacility and the
                default value is MTSyslogMessageFacilityUser.
*/
@property (nonatomic, strong, readwrite) NSString *reason;
@property (nonatomic, strong, readwrite) NSDate *expirationDate;
@property (nonatomic, strong, readwrite) NSDictionary *customData;
@property (nonatomic, strong, readwrite) MTPrivilegesUser *privilegesUser;
@property (nonatomic, strong, readonly) NSDate *timeStamp;
@property (assign) BOOL delayed;

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
 @method        dictionaryRepresentation
 @abstract      Returns a dictionary representation of the webhook data.
*/
- (NSDictionary*)dictionaryRepresentation;

/*!
 @method        composedData
 @abstract      Returns the composed webhook data.
*/
- (NSData*)composedData;

/*!
 @method        postToWebhookForUser:reason:expirationDate:completionHandler:
 @abstract      Post data about a privilege change to the webhook.
 @param         data An NSData object containing the data to post.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns an NSError object that contains a detailed error message if an error occurred. May be nil.
*/
- (void)postData:(NSData*)data completionHandler:(void (^) (NSError *error))completionHandler;

/*!
 @method        composedDataWithDictionary:
 @abstract      Returns the composed webhook data from a given dictionary.
 @param         dict A dictionary containing the information for composing the webhook data.
 @discussion    Returns an NSData object or nil if an error occurred.
*/
+ (NSData*)composedDataWithDictionary:(NSDictionary*)dict;

@end

