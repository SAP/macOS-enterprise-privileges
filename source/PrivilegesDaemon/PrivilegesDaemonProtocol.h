/*
    PrivilegesDaemonProtocol.h
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
#import <OSLog/OSLog.h>

/*!
 @protocol      PrivilegesDaemonProtocol
 @abstract      Defines the protocol implemented by the daemon and called by the xpc service and Privileges.
*/

@protocol PrivilegesDaemonProtocol

/*!
 @method        grantAdminRightsToUser:reason:completionHandler:
 @abstract      Grant administrator privileges to the given user.
 @param         userName A string containing the user name.
 @param         reason A string containing the reason the user requests administrator privileges. May be nil.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if adminstrator privileges were successfully granted, otherwise returns NO.
*/
- (void)grantAdminRightsToUser:(NSString*)userName
                        reason:(NSString*)reason
             completionHandler:(void(^)(BOOL success))completionHandler;

/*!
 @method        removeAdminRightsFromUser:reason:completionHandler:
 @abstract      Remove administrator privileges from the current user.
 @param         userName A string containing the user name.
 @param         reason A string containing the reason the user requests administrator privileges. May be nil.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if adminstrator privileges were successfully removed, otherwise returns NO.
*/
- (void)removeAdminRightsFromUser:(NSString*)userName
                           reason:(NSString*)reason
                completionHandler:(void(^)(BOOL success))completionHandler;

- (void)queuedEventsWithReply:(void(^)(NSArray *queuedEvents, NSError *error))completionHandler;

- (void)queueEventsInArray:(NSArray*)events completionHandler:(void(^)(BOOL success, NSError *error))completionHandler;

@end
