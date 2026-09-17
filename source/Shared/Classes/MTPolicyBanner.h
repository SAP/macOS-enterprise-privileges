/*
    MTPolicyBanner.h
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

#import <Cocoa/Cocoa.h>

@interface MTPolicyBanner : NSObject

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithBasePath: or initWithData: instead.
 */
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithBasePath:
 @abstract      Initialize a MTPolicyBanner object with a given path.
 @param         path A string specifying the file path.
 @discussion    Returns an initialized MTPolicyBanner object.
*/
- (instancetype)initWithBasePath:(NSString*)path;

/*!
 @method        initWithData:
 @abstract      Initialize a MTPolicyBanner object with the given data.
 @param         data A base64 encoded string containing plain text or rtf.
 @discussion    Returns an initialized MTPolicyBanner object.
*/
- (instancetype)initWithData:(NSData*)data;

/*!
 @method        attributedString
 @abstract      Get the policy as an attributed string.
 @discussion    Returns an NSAttributedString object or nil if an error occurred.
*/
- (NSAttributedString*)attributedString;

@end
