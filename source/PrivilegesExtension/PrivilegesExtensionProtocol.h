/*
    PrivilegesExtensionProtocol.h
    Copyright 2016-2026 SAP SE
     
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
 @protocol      PrivilegesExtensionProtocol
 @abstract      Defines the protocol implemented by the system extension and called by the PrivilegesHelper.
*/

@protocol PrivilegesExtensionProtocol

/*!
 @method        suspendExtensionUsingAuthorizedPID:completionHandler:
 @abstract      Suspend the extension by providing the pid of a process that is authorized to suspend the extension.
 @param         pid The id of a process that is authorized to suspend the extension.
 @discussion    Returns YES if the extension was successfully suspended, otherwise returns NO. If an error occurred, the completion
                handler's NSError object contains error details.
*/
- (void)suspendExtensionUsingAuthorizedPID:(pid_t)pid completionHandler:(void(^)(BOOL success, NSError *error))completionHandler;

/*!
 @method        resumeExtensionWithCompletionHandler:
 @abstract      Resume a suspended extension.
 @discussion    Returns YES if the extension was successfully resumed, otherwise returns NO.
*/
- (void)resumeExtensionWithCompletionHandler:(void(^)(BOOL success))completionHandler;

/*!
 @method        statusWithReply:
 @abstract      Return the current status of the extension.
 @discussion    Returns the current status of the extension.
*/
- (void)statusWithReply:(void(^)(NSString *status))reply;

@end
