/*
    PrivilegesAgentProtocol.h
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
 @protocol      PrivilegesAgentProtocol
 @abstract      Defines the protocol implemented by the agent..
*/

@protocol PrivilegesAgentProtocol

/*!
 @method        connectWithEndpointReply:
 @abstract      Returns an endpoint that's connected to the daemon.
 @param         reply The reply block to call when the request is complete.
 @discussion    This method is only called by the xpc service.
*/
- (void)connectWithEndpointReply:(void (^)(NSXPCListenerEndpoint* endpoint))reply;

/*!
 @method        requestAdminRightsWithReason:completionHandler:
 @abstract      Request administrator privileges for the current user.
 @param         reason A string containing the reason the user requests administrator privileges. May be nil.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if the operation was successful, otherwise returns NO.
*/
- (void)requestAdminRightsWithReason:(NSString*)reason completionHandler:(void(^)(BOOL success))completionHandler;

/*!
 @method        revokeAdminPrivilegesWithCompletionHandler:
 @abstract      Revoke administrator privileges for the current user.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if the operation was successful, otherwise returns NO.
*/
- (void)revokeAdminRightsWithCompletionHandler:(void(^)(BOOL success))completionHandler;

/*!
 @method        renewAdminRightsWithCompletionHandler:
 @abstract      Renew expiring administrator privileges for the current user.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if the operation was successful, otherwise returns NO.
*/
- (void)renewAdminRightsWithCompletionHandler:(void(^)(BOOL success))completionHandler;

/*!
 @method        authenticateUserWithCompletionHandler:
 @param         completionHandler The reply block to call when the request is complete.
*/
- (void)authenticateUserWithCompletionHandler:(void(^)(BOOL success, NSError *error))completionHandler;

/*!
 @method        expirationWithReply:
 @abstract      Get the date when the current user's administrator privileges expire.
 @param         reply The reply block to call when the request is complete.
 @discussion    Returns the expiration date and the number of minutes remaining. Expiration date will be nil
                if the administrator privileges are already expired.
*/
- (void)expirationWithReply:(void(^)(NSDate *expires, NSUInteger remaining))reply;

/*!
 @method        isExecutableFileAtURL:reply:
 @abstract      Get whether the current user can execute the file at the given url.
 @param         reply The reply block to call when the request is complete.
 @discussion    Returns YES if the file can be executed by the current user, otherwise returns NO.
*/
- (void)isExecutableFileAtURL:(NSURL*)url reply:(void(^)(BOOL isExecutable))reply;

@end
