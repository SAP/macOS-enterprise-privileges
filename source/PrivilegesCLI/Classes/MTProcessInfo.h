/*
    MTProcessInfo.h
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

#import <Cocoa/Cocoa.h>
#import "MTExtensionRequestType.h"

/*!
 @class         MTProcessInfo
 @abstract      A class that provides methods to access the relevant command line arguments.
*/

@interface MTProcessInfo : NSProcessInfo

/*!
 @method        showStatus
 @abstract      Get whether the status should be displayed.
 @discussion    Returns YES if the status should be displayed, otherwise returns NO.
 */
- (BOOL)showStatus;

/*!
 @method        showVersion
 @abstract      Get whether the version should be displayed.
 @discussion    Returns YES if the version should be displayed, otherwise returns NO.
 */
- (BOOL)showVersion;

/*!
 @method        requestPrivileges
 @abstract      Get whether administrator privileges were requested.
 @discussion    Returns YES if administrator privileges were requested, otherwise returns NO.
 */
- (BOOL)requestPrivileges;

/*!
 @method        revertPrivileges
 @abstract      Get whether administrator privileges should be reverted.
 @discussion    Returns YES if administrator privileges should be reverted, otherwise returns NO.
 */
- (BOOL)revertPrivileges;

/*!
 @method        launchURL
 @abstract      Get the launch url of the current process.
 @discussion    Returns an NSURL object or nil, if an error occurred.
 */
- (NSURL*)launchURL;

/*!
 @method        requestReason
 @abstract      Get the reason the user provided to get administator privileges.
 @discussion    Returns a NSString object containing the provided reason. Returns nil if no reason has been provided.
 */
- (NSString*)requestReason;


- (BOOL)systemExtension;
- (MTExtensionRequestType)extensionRequestType;

@end
