/*
    MTParentProcess.h
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
#import "MTProcess.h"

@interface MTParentProcess : NSObject

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithChildPID: instead.
*/
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithChildPID:
 @abstract      Initialize a MTParentProcess object with the given process id.
 @param         pid The id of the child process whose parent processes should be examined.
 @discussion    Returns an initialized MTParentProcess object.
*/
- (instancetype)initWithChildPID:(pid_t)pid NS_DESIGNATED_INITIALIZER;

/*!
 @method        parent
 @abstract      Get the child's parent process.
 @discussion    Returns an initialized MTProcess object, or nil if an error occurred.
*/
- (MTProcess*)parent;

/*!
 @method        root
 @abstract      Get the child's root process.
 @discussion    Returns an initialized MTProcess object, or nil if an error occurred.
*/
- (MTProcess*)root;

@end

