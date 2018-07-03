/*
 MTIdentity.h
 Copyright 2016-2018 SAP SE
 
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
 @class MTIdentity
 @abstract This class provides methods regarding user identities.
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
 @method        getGroupMembershipForUser:groupID:error
 @abstract      Check if a given user is member of a given group.
 @param         userName The short name of the user.
 @param         groupID The id of the group.
 @param         error A reference to an NSError object that contains a detailed error message if an error occurred. May be nil.
 @discussion    Returns YES if the user is member of the group, otherwise returns NO.
 */
+ (BOOL)getGroupMembershipForUser:(NSString*)userName groupID:(gid_t)groupID error:(NSError**)error;

@end
