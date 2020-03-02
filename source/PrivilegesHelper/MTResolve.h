/*
MTResolve.h
Copyright 2020 SAP SE

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
@class MTResolve
@abstract This class provides a method for resolving host names to ip addresses.
*/

NS_ASSUME_NONNULL_BEGIN

@interface MTResolve : NSObject

/*!
@method        resolveHostname:completionHandler:
@abstract      Resolves the given host name to an ip address.
@param         hostName An NSString containing the host name to resolve.
@param         completionHandler The completion handler to call when the request is complete.
@discussion    Returns an NSString containing the ip address of the host or nil, if an error occurred. If an error occurred
 an NSError object is returned that contains a detailed error message. If no error occurred, the NSError object is nil.
*/
- (void)resolveHostname:(NSString*)hostName completionHandler:(void (^)(NSArray* _Nullable ipAddresses, NSError* _Nullable error))completionHandler;
@end

NS_ASSUME_NONNULL_END
