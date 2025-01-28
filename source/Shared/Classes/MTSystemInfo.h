/*
    MTSystemInfo.h
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

/*!
 @class         MTSystemInfo
 @abstract      This class provides methods to get some system information.
*/

@interface MTSystemInfo : NSObject

/*!
 @method        machineUUID
 @abstract      Returns the uuid of the current machine.
 @discussion    Returns a NSString containing the uuid or nil if an error occurred.
 */
+ (NSString*)machineUUID;

/*!
 @method        sessionStartDate
 @abstract      Returns the start date of the current login session.
 @discussion    Returns the start date of the current login session or a date in the distant future if an error occurred.
 */
+ (NSDate*)sessionStartDate;

/*!
 @method        isExecutableFileAtURL:
 @abstract      Returns whether the file at the given url is executable.
 @param         url The file url to check.
 @discussion    Returns YES, if the file url is valid, the file exists and if it's executable. Otherwise returns NO.
 */
+ (BOOL)isExecutableFileAtURL:(NSURL*)url;

@end

