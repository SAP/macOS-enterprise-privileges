/*
    MTAgentConnection.h
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
#import "PrivilegesXPCProtocol.h"
#import "PrivilegesAgentProtocol.h"
#import <OSLog/OSLog.h>
#import <os/log.h>

/*!
 @protocol      MTAgentConnectionDelegate
 @abstract      Defines an interface for delegates of MTAgentConnection to be notified if
                the connection to the agent failed.
*/
@protocol MTAgentConnectionDelegate <NSObject>

/*!
 @method        connection:didFailWithError:
 @abstract      Called if the connection to the agent failed.
 @param         connection A reference to the NSXPCConnection instance that failed.
 @param         error A reference to a NSError object that indicates why the xpc connection failed.
 @discussion    Delegates receive this message if the connection to the agent failed.
*/
- (void)connection:(NSXPCConnection*)connection didFailWithError:(NSError*)error;

@end

/*!
 @class         MTAgentConnection
 @abstract      A class that provides an easy way to connect to the Privileges agent.
*/

@interface MTAgentConnection : NSObject

/*!
 @property      delegate
 @abstract      The receiver's connection delegate.
 @discussion    The value of this property is an object conforming to the MTAgentConnectionDelegate protocol.
*/
@property (weak) id <MTAgentConnectionDelegate> delegate;

/*!
 @property      connection
 @abstract      A property to store the connection object.
 @discussion    The value of this property is NSXPCConnection.
*/
@property (atomic, strong, readonly) NSXPCConnection *connection;

/*!
 @property      remoteObjectProxy
 @abstract      A property to store the connection's remote object proxy.
 @discussion    The value of this property is id.
*/
@property (atomic, strong, readonly) id remoteObjectProxy;

/*!
 @method        connectToXPCServiceWithRemoteObjectProxyReply:
 @abstract      Returns a proxy for the xpc service.
 @param         reply The reply block to call when the request is complete.
 @discussion    Returns a proxy for the xpc service or nil if an error occurred. In case of an error
                the error object might contain information about the error that caused the operation
                to fail.
*/
- (void)connectToXPCServiceWithRemoteObjectProxyReply:(void (^)(id remoteObjectProxy, NSError *error))reply;

/*!
 @method        connectToAgentWithExportedObject:andExecuteCommandBlock:
 @abstract      Connects to the agent and executes the given command block.
 @param         exportedObject The object you want to export to the agent. May be nil.
 @param         commandBlock The command block that should be executed after the connection has been established.
*/
- (void)connectToAgentWithExportedObject:(id)exportedObject
                  andExecuteCommandBlock:(void(^)(void))commandBlock;

/*!
 @method        invalidate
 @abstract      Invalidates the connection to the agent (and xpc service).
*/
- (void)invalidate;

@end
