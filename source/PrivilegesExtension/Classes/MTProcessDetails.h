/*
    MTProcessDetails.h
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
 @class         MTProcessDetails
 @abstract      This class provides methods to get some detailed information about processes.
*/

@interface MTProcessDetails : NSObject

/*!
 @method        processList
 @abstract      Returns a list of all running processes.
 @discussion    Returns an array containing the complete paths to all running processes
                or nil, if an error occurred.
*/
+ (NSArray*)processList;

/*!
 @method        openFilesWithPID:
 @abstract      Returns the file paths opened by the given process.
 @discussion    Returns an NSArray containing the paths to the opened files, or nil if an error occurred.
*/
+ (NSArray*)openFilesWithPID:(pid_t)pid;

/*!
 @method        isPlatformBinaryWithPID:
 @abstract      Get whether the process of the given pid is a platform binary (signed using Apple certificates).
 @discussion    Returns an YES if the process is a platform binary, otherwise returns NO.
*/
+ (BOOL)isPlatformBinaryWithPID:(pid_t)pid;

/*!
 @method        argumentsForPID:
 @abstract      Returns the arguments passed to the given process.
 @discussion    Returns an NSArray containing the arguments, or nil if an error occurred.
*/
+ (NSArray*)argumentsForPID:(pid_t)pid;

@end
