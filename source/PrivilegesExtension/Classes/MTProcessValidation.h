/*
    MTProcessValidation.h
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
#import "MTParentProcess.h"

@interface MTProcessValidation : NSObject

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithPID: instead.
 */
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithPID:
 @abstract      Initialize a MTProcessValidation object with the given process id.
 @param         pid The id of the process that should be validated.
 @discussion    Returns an initialized MTProcessValidation object.
*/
- (instancetype)initWithPID:(pid_t)pid NS_DESIGNATED_INITIALIZER;

/*!
 @method        isValid
 @abstract      Get whether the process is authorized to disable the system extension.
 @discussion    Returns YES if the process is authorized to disable the system extension, otherwise returns NO.
*/
- (BOOL)isValid;

@end

