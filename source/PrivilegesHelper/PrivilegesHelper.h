/*
 PrivilegesHelper.h
 Copyright 2016-2019 SAP SE
 
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

// tells the helper tool to quit
- (void)quitHelperTool;

// returns the version string of the helper tool
- (void)getVersionWithReply:(void(^)(NSString *version))reply;

// changes the group membership for a given user
- (void)changeGroupMembershipForUser:(NSString*)userName group:(uint)groupID remove:(BOOL)remove authorization:(NSData *)authData timeout:(uint)timeout withReply:(void(^)(NSError *error))reply;

@end

// The following is the interface to the class that implements the helper tool.
// It's called by the helper tool's main() function, but not by the app directly.

@interface PrivilegesHelper : NSObject

- (id)init;
- (void)run;

@end
