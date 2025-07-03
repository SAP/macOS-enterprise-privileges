/*
    MTPrivilegesLoggingConfiguration.h
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
#import "MTSyslogOptions.h"

@interface MTPrivilegesLoggingConfiguration : NSObject

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithDictionary: instead.
 */
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithDictionary:
 @abstract      Initialize a MTPrivilegesLoggingConfiguration object with a given dictionary.
 @param         dict An NSDictionary containing the remote logging configuration.
 @discussion    Returns an initialized MTPrivilegesLoggingConfiguration object.
*/
- (instancetype)initWithDictionary:(NSDictionary*)dict NS_DESIGNATED_INITIALIZER;

/*!
 @method        serverType
 @abstract      Get the type of the configured server.
 */
- (NSString*)serverType;

/*!
 @method        serverAddress
 @abstract      Get the address of the configured server.
 */
- (NSString*)serverAddress;

/*!
 @method        webhookCustomData
 @abstract      Get the custom data configured for webhooks.
 */
- (NSDictionary*)webhookCustomData;

/*!
 @method        syslogOptions
 @abstract      Get the options configured for syslog.
 @discussion    Returns an MTSyslogOptions object initialized with the configured options.
 */
- (MTSyslogOptions*)syslogOptions;

/*!
 @method        queueUnsentEvents
 @abstract      Get whether unsent remote logging events should be queued for resending.
 @discussion    Returns YES if the events should be queued, otherwise returns NO.
 */
- (BOOL)queueUnsentEvents;

/*!
 @method        queuedEventsMax
 @abstract      Get the maximum number of queued events.
 @discussion    Returns an integer representing the maximum number of queued events. A value of 0
                means that an unlimited number of events is queued.
 */
- (NSInteger)queuedEventsMax;

@end
