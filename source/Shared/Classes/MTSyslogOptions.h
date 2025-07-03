/*
    MTSyslogOptions.h
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
#import "MTSyslogMessage.h"

@interface MTSyslogOptions : NSObject

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithDictionary: instead.
 */
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithDictionary:
 @abstract      Initialize a MTSyslogOptions object with a given dictionary.
 @param         dict An NSDictionary containing the syslog options.
 @discussion    Returns an initialized MTSyslogOptions object.
*/
- (instancetype)initWithDictionary:(NSDictionary*)dict NS_DESIGNATED_INITIALIZER;

/*!
 @method        logFacility
 @abstract      Get the log facility used for syslog messages.
 @discussion    Returns the configured syslog facility or MTSyslogMessageFacilityAuth if no syslog facility has been configured.
 */
- (MTSyslogMessageFacility)logFacility;

/*!
 @method        logSeverity
 @abstract      Get the log severity used for syslog messages.
 @discussion    Returns the configured syslog severity or MTSyslogMessageSeverityInformational if no syslog severity has been configured.
 */
- (MTSyslogMessageSeverity)logSeverity;

/*!
 @method        maxSize
 @abstract      Get the maximum size used for syslog messages.
 @discussion    Returns the configured size or 0 if no maximum size has been configured.
 */
- (MTSyslogMessageMaxSize)maxSize;

/*!
 @method        messageFormat
 @abstract      Get the message format used for syslog messages.
 @discussion    Returns the configured message format or MTSyslogMessageFormatNonTransparentFraming if no format has been configured.
 */
- (MTSyslogMessageFormat)messageFormat;

/*!
 @method        structuredData
 @abstract      Get the structured data part used for syslog messages.
 @discussion    Returns an NSDictionary containing the structured data or nil if structured data has not been configured.
 */
- (NSDictionary*)structuredData;

/*!
 @method        serverPort
 @abstract      Get the server port used for sending syslog messages.
 @discussion    Returns the configured port or the default port 514 if no port has been configured. If useTLS is set to YES, the default port is 6514.
 */
- (NSInteger)serverPort;

/*!
 @method        useTLS
 @abstract      Get whether TLS should be used for the connection to the syslog server.
 @discussion    Returns YES if TLS should be used, otherwise returns NO.
 */
- (BOOL)useTLS;

@end
