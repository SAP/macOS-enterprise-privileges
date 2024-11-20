/*
    PrivilegesXPCProtocol.h
    Copyright 2024 SAP SE
     
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
 @protocol      PrivilegesXPCProtocol
 @abstract      Defines the protocol implemented by the xpc service and
                called by Privileges.
*/

@protocol PrivilegesXPCProtocol

/*!
 @method        connectWithAgentEndpointReply:
 @abstract      Returns an endpoint that's connected to the agent.
 @param         reply The reply block to call when the request is complete.
*/
- (void)connectWithAgentEndpointReply:(void(^)(NSXPCListenerEndpoint *endpoint))reply;

@end
