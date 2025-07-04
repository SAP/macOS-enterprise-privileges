/*
    MTIdentity.h
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
#import <Collaboration/Collaboration.h>
#import <OpenDirectory/OpenDirectory.h>
#import <LocalAuthentication/LocalAuthentication.h>

/*!
 @class         MTIdentity
 @abstract      This class provides methods for handling user identities.
 */

@interface MTIdentity : NSObject

/*!
 @method        gidFromGroupName:
 @abstract      Get the group id from a group name.
 @param         groupName The short name of the group.
 @discussion    Returns the id of the given group or -1 if an error occurred.
 */
+ (int)gidFromGroupName:(NSString*)groupName;

/*!
 @method        groupMembershipForUser:groupID:error
 @abstract      Check if a given user is member of a given group.
 @param         userName The short name of the user.
 @param         groupID The id of the group.
 @param         error A reference to an NSError object that contains a detailed error message if an error occurred. May be nil.
 @discussion    Returns YES if the user is member of the group, otherwise returns NO.
 */
+ (BOOL)groupMembershipForUser:(NSString*)userName groupID:(gid_t)groupID error:(NSError**)error;

/*!
@method        groupMembershipForUser:groupName:error:
@abstract      Check if a given user is member of a given group.
@param         userName The short name of the user.
@param         groupName The name of the group.
@param         error A reference to an NSError object that contains a detailed error message if an error occurred. May be nil.
@discussion    Returns YES if the user is member of the group, otherwise returns NO.
*/
+ (BOOL)groupMembershipForUser:(NSString*)userName groupName:(NSString*)groupName error:(NSError**)error;

/*!
@method        authenticateUserWithReason:requireBiometrics:completionHandler:
@abstract      Authenticate the user either by using Touch ID (if available) or password.
@param         authReason The reason for requesting authentication, which displays in the authentication dialog presented to the user.
@param         biometrics A boolean which forces biometric authentication (if available).
@param         completionHandler The handler to call when the request is complete.
@discussion    Returns YES if authentication succeeded, otherwise returns NO. If an error occurred, the completion handler's NSError object
               contains error details.
*/
+ (void)authenticateUserWithReason:(NSString*)authReason requireBiometrics:(BOOL)biometrics completionHandler:(void (^) (BOOL success, NSError *error))completionHandler;

/*!
@method        authenticatePIVUserWithReason:completionHandler:
@abstract      Authenticate the user either by using a smart card/PIV token or password.
@param         authReason The reason for requesting authentication, which displays in the authentication dialog presented to the user.
@param         completionHandler The handler to call when the request is complete.
@discussion    Returns YES if authentication succeeded, otherwise returns NO. If an error occurred, the completion handler's NSError object
               contains error details.
*/
+ (void)authenticatePIVUserWithReason:(NSString*)authReason completionHandler:(void (^) (BOOL success, NSError *error))completionHandler;

/*!
@method        verifyPassword:forUser:
@abstract      Verifies if a given password can be used to authenticate a given user.
@param         userPassword The user's password.
@param         userName The short name of the user.
@discussion    Returns YES if verification succeeded, otherwise returns NO.
*/
+ (BOOL)verifyPassword:(NSString*)userPassword forUser:(NSString*)userName;

@end
