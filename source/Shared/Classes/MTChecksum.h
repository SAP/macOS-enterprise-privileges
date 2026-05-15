/*
    MTChecksum.h
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
#import <CommonCrypto/CommonDigest.h>

/*!
 @class         MTChecksum
 @abstract      This class provides a method to generate a sha256 checksum from a given file. 
                The file is read in chunks to save memory.
*/

@interface MTChecksum : NSObject

/*!
 @method        sha256ChecksumWithPath:
 @abstract      Generates the sha256 checksum for the file at the given path.
 @param         path The path to the file the checksum should be generated for.
 @discussion    Returns an initialized NSString object containing the checksum or an 
                empty string if the file does not exist or is not readable.
*/
+ (NSString*)sha256ChecksumWithPath:(NSString*)path;

@end
