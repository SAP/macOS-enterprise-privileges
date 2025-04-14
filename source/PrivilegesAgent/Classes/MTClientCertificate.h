/*
    MTClientCertificate.h
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
 @class         MTClientCertificate
 @abstract      A class that provides methods to find a matching identity for a given distinguished name.
*/

@interface MTClientCertificate : NSObject

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithinitWithDistinguishedName: instead.
 */
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithinitWithDistinguishedName:
 @abstract      Initialize a MTClientCertificate object with a given NSData object containing a DER
                encoded distinguished name.
 @param         encodedData The DER-encoded distinguished name.
 @discussion    Returns an initialized MTClientCertificate object or nil if an error occurred.
*/
- (instancetype)initWithDistinguishedName:(NSData*)encodedData NS_DESIGNATED_INITIALIZER;

/*!
 @method        dictionaryRepresentation
 @abstract      Get a dictionary representation of the DN containing all its OIDs and their respective values.
 @discussion    Returns a NSDictionary with OIDs and its values or nil if an error occurred.
*/
- (NSDictionary*)dictionaryRepresentation;

/*!
 @method        matchingIdentityWithSecItems:
 @abstract      Initialize a MTClientCertificate object with a given NSData object containing a DER
                encoded distinguished name.
 @param         secItems An array of SecIdentityRef.
 @discussion    Returns the first SecIdentityRef that matches the DN the MTClientCertificate object
                has been initialized with or nil if an error occurred.
*/
- (SecIdentityRef)matchingIdentityWithSecItems:(NSArray*)secItems;

@end
