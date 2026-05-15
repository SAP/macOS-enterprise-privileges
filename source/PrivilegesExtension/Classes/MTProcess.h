/*
    MTProcess.h
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
#import "MTProcessDetails.h"

@interface MTProcess : NSObject

@property (assign, readonly) pid_t pid;

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithPID: instead.
*/
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithPID:
 @abstract      Initialize a MTProcess object with the given process id.
 @param         pid The id of the process.
 @discussion    Returns an initialized MTProcess object.
*/
- (instancetype)initWithPID:(pid_t)pid NS_DESIGNATED_INITIALIZER;

/*!
 @method        name
 @abstract      Returns the name of the process.
*/
- (NSString*)name;

/*!
 @method        isPlatformBinary
 @abstract      Get whether the process is a platform binary (signed using Apple certificates).
 @discussion    Returns an YES if the process is a platform binary, otherwise returns NO.
*/
- (BOOL)isPlatformBinary;

/*!
 @method        openFiles
 @abstract      Returns the file paths opened by the process.
 @discussion    Returns an NSArray containing the paths to the opened files, or nil if an error occurred.
*/
- (NSArray*)openFiles;

/*!
 @method        arguments
 @abstract      Returns the arguments passed to the process.
 @discussion    Returns an NSArray containing the arguments, or nil if an error occurred.
*/
- (NSArray*)arguments;

@end
