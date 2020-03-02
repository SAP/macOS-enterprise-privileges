/*
 PrivilegesHelper.h
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

// kHelperToolMachServiceName is the Mach service name of the helper tool.  Note that the value
// here has to match the value in the MachServices dictionary in "PrivilegesHelper-Launchd.plist".

#define kHelperToolMachServiceName @"corp.sap.privileges.helper"

// HelperToolProtocol is the NSXPCConnection-based protocol implemented by the helper tool
// and called by the app.

@protocol HelperToolProtocol

@required

- (void)connectWithEndpointReply:(void (^)(NSXPCListenerEndpoint *))reply;

/*!
@method        quitHelperTool
@abstract      Tells the helper tool to quit.
*/
- (void)quitHelperTool;

/*!
@method        helperVersionWithReply:
@abstract      Returns the version number string of the helper tool.
@param         reply The completion handler to call when the request is complete.
@discussion    Returns an NSString object containing the version number of the helper tool.
*/
- (void)helperVersionWithReply:(void(^)(NSString *version))reply;

/*!
@method        changeAdminRightsForUser:remove:reason:authorization:withReply:
@abstract      Adds or removes the given user to/from the admin group.
@param         userName The short name of the user.
@param         remove A boolean indicating if the user should be added to or removed from the group.
@param         reason An optional NSString which may contain a reason for requesting admin rights. The reason will be logged.
@param         authData An NSData object with an AuthorizationExternalForm embedded inside.
@param         reply The completion handler to call when the request is complete.
@discussion    Returns an NSError object that contains a detailed error message if an error occurred. May be nil.
*/
- (void)changeAdminRightsForUser:(NSString*)userName
                          remove:(BOOL)remove
                          reason:(NSString*)reason
                   authorization:(NSData*)authData
                       withReply:(void(^)(NSError *error))reply;

@end

// The following is the interface to the class that implements the helper tool.
// It's called by the helper tool's main() function, but not by the app directly.

@interface PrivilegesHelper : NSObject

- (id)init;
- (void)run;

@end
