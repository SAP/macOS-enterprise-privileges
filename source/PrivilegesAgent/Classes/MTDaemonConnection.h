/*
    MTDaemonConnection.h
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
#import "PrivilegesDaemonProtocol.h"
#import <OSLog/OSLog.h>
#import <os/log.h>

/*!
 @class         MTDaemonConnection
 @abstract      A class that provides an easy way to connect to the Privileges daemon.
*/

@interface MTDaemonConnection : NSObject

/*!
 @property      connection
 @abstract      A property to store the connection object.
 @discussion    The value of this property is NSXPCConnection.
*/
@property (atomic, strong, readonly) NSXPCConnection *connection;

/*!
 @method        connectToDaemonWithExportedObject:andExecuteCommandBlock:
 @abstract      Connects to the daemon and executes the given command block.
 @param         commandBlock The command block that should be executed after the connection has been established.
*/
- (void)connectToDaemonAndExecuteCommandBlock:(void(^)(void))commandBlock;

/*!
 @method        invalidate
 @abstract      Invalidates the connection to the daemon (and xpc service).
*/
- (void)invalidate;

@end
