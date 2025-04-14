/*
    MTSyslogMessageStructuredData.h
    Copyright 2020-2025 SAP SE

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
@class MTSyslogMessageStructuredData
@abstract This class provides methods for creating  the structured data part of a syslog message (as defined in RFC 5424).
*/

@interface MTSyslogMessageStructuredData : NSObject

/*!
 @method        addStructuredData:withID:
 @abstract      Add an element to the structured data object.
 @param         data A dictionary containing the keys and values of the element.
 @param         sdID The id/name of the element.
*/
- (void)addStructuredData:(NSDictionary*)data withID:(NSString*)sdID;

/*!
 @method        structuredDataWithDictionary:
 @abstract      Create the structured data object from a given dictionary.
 @param         data A dictionary containing one or more structured data element(s).
 @discussion    The following example shows a dictionary with two structured data elements:
 @code
 {
    exampleSDID@32473 =   {
        iut = 3;
        eventSource = Application;
        eventID = 1011;
    };
    examplePriority@32473 = {
        class = high;
    }
}
*/
- (void)structuredDataWithDictionary:(NSDictionary*)data;

/*!
 @method        composedString
 @abstract      Get the stuctured data as RFC 5424-compliant structured data string.
 @discussion    Returns a string containing the structured data or nil if no data has been added or an error occurred.
*/
- (NSString*)composedString;

/*!
 @method        cleanString:maximumLength:
 @abstract      Converts the given string into US-ASCII and removes non-printable characters, ensuring the given maximum length.
 @param         originalString The string that should be converted.
 @param         maxLength The maximum length that the converted string should not exceed. If set to 0, the length is unlimited.
 @discussion    Returns the cleaned string or nil if an error occurred.
*/
+ (NSString*)cleanString:(NSString*)originalString maximumLength:(NSInteger)maxLength;

@end
