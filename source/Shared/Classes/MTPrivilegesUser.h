/*
    MTPrivilegesUser.h
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
#import "MTIdentity.h"

/*!
 @class         MTPrivilegesUser
 @abstract      This class provides methods for the current Privileges user to request and revoke administrator privileges.
 */

@interface MTPrivilegesUser : NSObject

/*!
 @property      userName
 @abstract      Returns the user name of the MTPrivilegesUser.
 @discussion    The value of this property is string.
*/
@property (nonatomic, strong, readonly) NSString *userName;

/*!
 @method        hasAdminPrivileges
 @abstract      Get whether the MTPrivilegesUser has administrator privileges.
 @discussion    Returns YES if the user has administrator privileges, otherwise returns NO.
*/
- (BOOL)hasAdminPrivileges;

/*!
 @method        hasUnexpectedPrivilegeState
 @abstract      Get whether the privileges of the MTPrivilegesUser have an unexpected state.
 @discussion    Returns YES if the privileges for the user have been changed by another process and therefore
                different from the privileges we have set for this user, otherwise returns NO.
*/
- (BOOL)hasUnexpectedPrivilegeState;

/*!
 @method        setUnexpectedPrivilegeState:
 @abstract      Set whether the privileges for the MTPrivilegesUser are unexpected.
 @param         unexpectedState A boolean indicating if the privileges are unexpected (YES) or not (NO).
*/
- (void)setUnexpectedPrivilegeState:(BOOL)unexpectedState;

/*!
 @method        requestAdminPrivilegesWithReason:completionHandler:
 @abstract      Request administrator privileges for the current MTPrivilegesUser.
 @param         reason A string containing the reason the user requests administrator privileges. May be nil.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if the operation was successful, otherwise returns NO.
*/
- (void)requestAdminPrivilegesWithReason:(NSString*)reason completionHandler:(void(^)(BOOL success))completionHandler;

/*!
 @method        revokeAdminPrivilegesWithCompletionHandler:
 @abstract      Revoke administrator privileges for the current MTPrivilegesUser.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if the operation was successful, otherwise returns NO.
*/
- (void)revokeAdminPrivilegesWithCompletionHandler:(void(^)(BOOL success))completionHandler;

/*!
 @method        renewAdminPrivilegesWithCompletionHandler:
 @abstract      Renew expiring administrator privileges for the current MTPrivilegesUser.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if the operation was successful, otherwise returns NO.
*/
- (void)renewAdminPrivilegesWithCompletionHandler:(void(^)(BOOL success))completionHandler;

/*!
 @method        authenticateWithCompletionHandler:
 @abstract      Authenticate the current MTPrivilegesUser.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if the operation was successful, otherwise returns NO.
*/
- (void)authenticateWithCompletionHandler:(void(^)(BOOL success, NSError *error))completionHandler;

/*!
 @method        privilegesExpirationWithReply:
 @abstract      Get the date when the current user's administrator privileges expire.
 @param         reply The reply block to call when the request is complete.
 @discussion    Returns the expiration date and the number of minutes remaining. Expiration date will be nil
                if the administrator privileges are already expired.
*/
- (void)privilegesExpirationWithReply:(void(^)(NSDate *expire, NSUInteger remaining))reply;

/*!
 @method        canExecuteFileAtURL:reply:
 @abstract      Get whether the current user can execute the file at the given url.
 @param         reply The reply block to call when the request is complete.
 @discussion    Returns YES if the file can be executed by the current user, otherwise returns NO.
*/
- (void)canExecuteFileAtURL:(NSURL*)url reply:(void (^)(BOOL canExecute))reply;

/*!
 @method        useIsRestricted
 @abstract      Get whether the app usage is restricted for the user.
 @discussion    Returns YES if the app usage is restricted for the user, otherwise returns NO.
 */
- (BOOL)useIsRestricted;

/*!
 @method        isExcludedFromRevokeAtLogin
 @abstract      Get whether the current user is excluded from the automatic privilege removal at login.
 @discussion    Returns YES if the user is excluded, otherwise returns NO.
 */
- (BOOL)isExcludedFromRevokeAtLogin;

@end

