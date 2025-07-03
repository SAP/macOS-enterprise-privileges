/*
    MTSyslog.h
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
#import "MTSyslogMessage.h"

/*!
@class MTSyslog
@abstract This class provides methods for sending syslog messages to a remote syslog server.
*/

@interface MTSyslog : NSObject <NSURLSessionTaskDelegate>

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithServerAddress:serverPort:andProtocol: instead.
 */
- (instancetype)init NS_UNAVAILABLE;

/*!
@method        initWithServerAddress:serverPort:andProtocol:
@abstract      Initializes a MTSyslog object with  a provided server address, port and protocol.
@param         serverAddress An NSString containing the host name or ip address of the server.
@param         serverPort An integer specifying the server port.
@param         useTLS A boolean that specifies whether tls should be used.
@returns       A MTSyslog object initialized with the data provided.
*/
- (instancetype)initWithServerAddress:(NSString*)serverAddress
                           serverPort:(NSUInteger)serverPort
                               useTLS:(BOOL)useTLS
 NS_DESIGNATED_INITIALIZER;

/*!
@method        writeData:completionHandler:
@abstract      Send syslog data to the syslog server.
@param         data An NSData object containing the message to send.
@param         completionHandler The completion handler to call when the request is complete.
@discussion    Returns an NSError object that contains a detailed error message if an error occurred. May be nil.
*/
- (void)writeData:(NSData*)data completionHandler:(void (^) (NSError *error))completionHandler;

@end
