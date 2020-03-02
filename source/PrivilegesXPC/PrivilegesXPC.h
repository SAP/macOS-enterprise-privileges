/*
PrivilegesXPC.h
Copyright 2020 SAP SE

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

#define kXPCServiceName @"corp.sap.privileges.xpc"

@protocol PrivilegesXPCProtocol

@required

- (void)installHelperToolWithReply:(void(^)(NSError *error))reply;
    // Called by the app to install the helper tool.

- (void)setupAuthorizationRights;
    // Called by the app at startup time to set up our authorization rights in the
    // authorization database.

- (void)connectWithEndpointAndAuthorizationReply:(void(^)(NSXPCListenerEndpoint *endpoint, NSData *authorization))reply;
    // Called by the app to get an endpoint that's connected to the helper tool.
    // This a also returns the XPC service's authorization reference so that
    // the app can pass that to the requests it sends to the helper tool.
    // Without this authorization will fail because the app is sandboxed.

@end

// The following is the interface to the class that implements the XPC service.
// It's called by the XPC service's main() function, but not by the app directly.

@interface PrivilegesXPC : NSObject

- (id)init;
- (void)run;

@end
