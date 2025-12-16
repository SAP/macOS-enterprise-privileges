/*
    PrivilegesHelperProtocol.h
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

/*!
 @protocol      PrivilegesHelperProtocol
 @abstract      Defines the protocol implemented by the helper and used by the MTSystemExtension class.
*/

@protocol PrivilegesHelperProtocol

/*!
 @method        enableExtensionWithCompletionHandler:
 @abstract      Enable the Privileges system extension.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if the extension was successfully enabled, otherwise returns NO. In case of an error
                the error object might contain information about the error that caused the operation to fail.
*/
- (void)enableExtensionWithCompletionHandler:(void(^)(BOOL success, NSError *error))completionHandler;

/*!
 @method        disableExtensionWithCompletionHandler:
 @abstract      Disable the Privileges system extension.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if the extension was successfully disabled, otherwise returns NO. In case of an error
                the error object might contain information about the error that caused the operation to fail.
*/
- (void)disableExtensionWithCompletionHandler:(void(^)(BOOL success, NSError *error))completionHandler;

/*!
 @method        suspendExtensionWithCompletionHandler:
 @abstract      Suspend the Privileges system extension.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if the extension was successfully suspended, otherwise returns NO. In case of an error
                the error object might contain information about the error that caused the operation to fail.
*/
- (void)suspendExtensionWithCompletionHandler:(void(^)(BOOL success, NSError *error))completionHandler;

/*!
 @method        extensionStatusWithReply:
 @abstract      Get the status of the Privileges system extension.
 @param         reply The handler to call when the request is complete.
 @discussion    Returns the status of the extension as an NSString object.
*/
- (void)extensionStatusWithReply:(void(^)(NSString *status))reply;

@end
