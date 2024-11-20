/*
    MTCodeSigning.h
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

/*!
 @class         MTCodeSigning
 @abstract      A class that provides some methods related to code signing and sandboxing.
*/

@interface MTCodeSigning : NSObject

/*!
 @method        getSigningAuthorityWithError:
 @abstract      Returns the current app's signing authority.
 @param         error A reference to a NSError object that indicates why the xpc connection failed.
 @discussion    Returns the current app's signing authority or nil if an error occurred. In case of an error
                the error object might contain information about the error that caused the operation
                to fail.
*/
+ (NSString*)getSigningAuthorityWithError:(NSError**)error;

/*!
 @method        codeSigningRequirementsWithCommonName:bundleIdentifier:versionString:
 @abstract      Returns the code signing requirements constructed from the given parameters.
 @param         commonName The common name (signing authority) that should be used for the code signing requirements.
 @param         bundleIdentifier The app's bundle identifier that should be used for the code signing requirements.
 @param         versionString The app's version string (e.g. 2.0.0) that should be used for the code signing requirements.
 @discussion    Returns a string containing the code signing requirements or nil if an error occurred.
*/
+ (NSString*)codeSigningRequirementsWithCommonName:(NSString*)commonName
                                  bundleIdentifier:(NSString*)bundleIdentifier
                                     versionString:(NSString*)versionString;

/*!
 @method        sandboxStatusWithCompletionHandler:
 @abstract      Returns whether the current application is sandboxed or not.
 @param         completionHandler The completion handler to call when the request is complete.
 @discussion    Returns YES if the current application is sandboxed, otherwise returns NO. In case of an error
                the error object might contain information about the error that caused the operation
                to fail.
*/
+ (void)sandboxStatusWithCompletionHandler:(void (^)(BOOL isSandboxed, NSError *error))completionHandler;

@end

