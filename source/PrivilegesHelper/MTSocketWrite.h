/*
MTSocketWrite.h
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
@class MTSocketWrite
@abstract This class provides simple methods for writing to sockets.
*/

NS_ASSUME_NONNULL_BEGIN

@interface MTSocketWrite : NSObject <NSStreamDelegate>

/*!
  @enum Syslog Transport Layer Protocol
  @discussion Specifies values for diffent syslog transport layer protocols.
*/
typedef NSUInteger MTSocketTransportLayerProtocol;
NS_ENUM(MTSocketTransportLayerProtocol) {
    MTSocketTransportLayerProtocolUDP = 0,
    MTSocketTransportLayerProtocolTCP = 1
};

- (id)init NS_UNAVAILABLE;

/*!
@method        initWithServerAddress:serverPort:andProtocol:
@abstract      Initializes a MTSocketWrite object with  a provided server address, port and protocol.
@param         serverAddress An NSString containing the host name or ip address of the server.
@param         serverPort An integer specifying the server port.
@param         serverProtocol An MTSocketTransportLayerProtocol specifying the transport layer protocol to be used (UDP or TCP).
@returns       A MTSocketWrite object initialized with the data provided.
*/
- (id)initWithServerAddress:(NSString*)serverAddress serverPort:(NSUInteger)serverPort andProtocol:(MTSocketTransportLayerProtocol)serverProtocol NS_DESIGNATED_INITIALIZER;

/*!
@method        writeMessage:completionHandler:
@abstract      Writes a message to a socket.
@param         message An NSString containing the message to send.
@param         completionHandler The completion handler to call when the request is complete.
@discussion    Returns an NSError object that contains a detailed error message if an error occurred. May be nil.
*/
- (void)writeMessage:(NSString *)message completionHandler:(void (^)(NSError* _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
