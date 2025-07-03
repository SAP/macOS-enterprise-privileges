/*
    MTRemoteLoggingManager.h
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

/*!
 @class         MTRemoteLoggingManager
 @abstract      A class that sends the Privileges remote logging events and handles retries in cases where events could not be sent.
*/

@interface MTRemoteLoggingManager : NSObject

/*!
 @property      queueUnsentEvents
 @abstract      A property to store whether or not events should be queued if they cannot be sent.
 @discussion    The value of this property is boolean.
*/
@property (assign) BOOL queueUnsentEvents;

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithRetryIntervals: instead.
 */
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithRetryIntervals:
 @abstract      Initialize a MTRemoteLoggingManager object with a given array of retry intervals.
 @param         intervals An array of NSNumber specifying the retry intervals.
 @discussion    Returns an initialized MTRemoteLoggingManager object or nil if an error occurred.
*/
- (instancetype)initWithRetryIntervals:(NSArray<NSNumber*>*)intervals NS_DESIGNATED_INITIALIZER;

/*!
 @method        start
 @abstract      Starts the Remote Logging Manager and ensures queued events are loaded. This method
                must be executed before using sendEvent:completionHandler:.
 @discussion    Returns YES on success, otherwise returns NO.
*/
- (BOOL)start;

/*!
 @method        sendEvent:completionHandler:
 @abstract      Initialize a MTRemoteLoggingManager object with a given array of retry intervals.
 @param         event A dictionary containing the content for the event.
 @param         completionHandler The completion handler to call when the request is complete.
 @discussion    Returns YES if the event was successfully sent, otherwise returns NO. In case of an error
                the error object might contain information about the error that caused the operation
                to fail.
*/
- (void)sendEvent:(NSDictionary*)event completionHandler:(void (^) (BOOL success, NSError *error))completionHandler;

/*!
 @method        cancelRetries
 @abstract      Cancels all pending retries.
*/
- (void)cancelRetries;

@end

