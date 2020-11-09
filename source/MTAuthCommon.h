/*
 MTAuthCommon.h
 Copyright 2016-2020 SAP SE
 
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
 @class MTAuthCommon
 @abstract This class provides common methods for using a privileged helper.
 */

@interface MTAuthCommon : NSObject

/*!
 @method        authorizationRightForCommand:
 @abstract      For a given command selector, return the associated authorization right name.
 @param         command The command selector.
 @discussion    Returns a dictionary that represents everything we need to know about the
 authorized commands supported by the app.  Each dictionary key is the string form of
 the command selector.  The corresponding object is a dictionary that contains three items:

 @b kCommandKeyAuthRightName is the name of the authorization right itself.  This is used by
 both the app (when creating rights and when pre-authorizing rights) and by the tool
 (when doing the final authorization check).

 @b kCommandKeyAuthRightDefault is the default right specification, used by the app to when
 it needs to create the default right specification.  This is commonly a string contacting
 a rule a name, but it can potentially be more complex.  See the discussion of the
 rightDefinition parameter of AuthorizationRightSet.

 @b kCommandKeyAuthRightDesc is a user-visible description of the right.  This is used by the
 app when it needs to create the default right specification.  Actually, string is used
 to look up a localized version of the string in "Common.strings".
 */
+ (NSString*)authorizationRightForCommand:(SEL)command;

/*!
 @method        setupAuthorizationRights:
 @abstract      Set up the default authorization rights in the authorization database.
 @param         authRef A pointer to an authorization reference.
 */
+ (void)setupAuthorizationRights:(AuthorizationRef)authRef;

/*!
@method        getSigningAuthorityWithError:
@abstract      Returns the signing authority of the caller.
@param         error A reference to an NSError object that contains a detailed error message if an error occurred. May be nil.
@discussion    Returns the signing authority of the caller or nil if an error occurred.
*/
+ (NSString*)getSigningAuthorityWithError:(NSError**)error;

#define ADMIN_GROUP_ID 80
#define DEFAULT_DOCK_TIMEOUT 20
#define FIXED_TIMEOUT_VALUES {0, 5, 10, 20, 60}

@end
