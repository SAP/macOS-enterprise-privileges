/*
MTSocketWrite.m
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

#import "MTSocketWrite.h"
#import "MTResolve.h"
#import <CoreFoundation/CoreFoundation.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <os/log.h>

@interface MTSocketWrite ()
@property (atomic, strong, readwrite) NSString *serverAddress;
@property (atomic, strong, readwrite) NSString *serverAddressResolved;
@property (atomic, assign) NSUInteger serverPort;
@property (atomic, assign) MTSocketTransportLayerProtocol serverProtocol;
@property (atomic, strong, readwrite) NSOutputStream *outputStream;
@property (atomic, strong, readwrite) NSTimer *streamTimeoutTimer;
@property (atomic, strong, readwrite) NSMutableData *streamData;
@property (nonatomic, copy) void (^streamCompletionHandler)(NSError* error);
@end

@implementation MTSocketWrite

- (id)initWithServerAddress:(NSString*)serverAddress serverPort:(NSUInteger)serverPort andProtocol:(MTSocketTransportLayerProtocol)serverProtocol
{
    self = [super init];
    
    if (self) {
        _serverAddress = serverAddress;
        _serverPort = serverPort;
        _serverProtocol = serverProtocol;
    }
    
    return self;
}

- (void)writeMessage:(NSString *)message completionHandler:(void (^)(NSError* _Nullable error))completionHandler
{
    if (_serverProtocol == MTSocketTransportLayerProtocolUDP) {
        [self writeUDPMessage:message completionHandler:completionHandler];
    } else {
        [self writeTCPMessage:message completionHandler:completionHandler];
    }
}

- (void)writeUDPMessage:(NSString*)message completionHandler:(void (^)(NSError* _Nullable error))completionHandler
{
    // if we got a server name, we have to get the server's ip address first
    NSString *ipRegexp = @"^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", ipRegexp];

    if ([predicate evaluateWithObject:_serverAddress]) {
        
        _serverAddressResolved = _serverAddress;
        [self udpWriteToOutput:message completionHandler:completionHandler];
        
    } else {
        
        MTResolve *hostResolver = [[MTResolve alloc] init];
        [hostResolver resolveHostname:_serverAddress
                    completionHandler:^(NSArray * _Nullable ipAddresses, NSError * _Nullable error) {

            if (error) {
                if (completionHandler) { completionHandler(error); }
            } else {
                
                self->_serverAddressResolved = [ipAddresses firstObject];
                [self udpWriteToOutput:message completionHandler:completionHandler];
            }
        }];
    }
}

- (void)udpWriteToOutput:(NSString*)message completionHandler:(void (^)(NSError* _Nullable error))completionHandler
{
    NSString *errorMsg = nil;
    NSError *error = nil;

    // create the socket
    CFSocketRef socket = CFSocketCreate(kCFAllocatorDefault,
                                        PF_INET,
                                        SOCK_DGRAM,
                                        IPPROTO_UDP,
                                        0,
                                        NULL,
                                        NULL);
    
    if (!socket) {
        errorMsg = @"Failed to create socket";
        
    } else {
        
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_len = sizeof(addr);
        addr.sin_family = AF_INET;
        addr.sin_port = htons(_serverPort);
        addr.sin_addr.s_addr = inet_addr([_serverAddressResolved UTF8String]);

        CFDataRef addr_data = CFDataCreate(NULL, (const UInt8*)&addr, sizeof(addr));
        CFDataRef msg_data = (__bridge CFDataRef)[message dataUsingEncoding:NSUTF8StringEncoding];

        if (addr_data) {
            
            if (msg_data) {
                
                CFSocketError socketErr = CFSocketSendData(socket, addr_data, msg_data, 0);
                
                if (socketErr != kCFSocketSuccess) {
                    errorMsg = @"Failed to send data";
                }
                
            } else {
                errorMsg = @"No message data";
            }
            
            CFRelease(addr_data);
            
        } else {
            errorMsg = @"IP addess is missing";
        }
        
        CFRelease(socket);
    }

    if (errorMsg) {
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:errorMsg, NSLocalizedDescriptionKey, nil];
        error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:100 userInfo:errorDetail];
    }
    
    if (completionHandler) { completionHandler(error); }
}

- (void)writeTCPMessage:(NSString*)message completionHandler:(void (^) (NSError* _Nullable error))completionHandler
{
    CFWriteStreamRef writeStream = nil;

    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                       (__bridge CFStringRef _Nonnull)(_serverAddress),
                                       (int)_serverPort,
                                       NULL,
                                       &writeStream
                                       );
    
    // fill our buffer
    self->_streamCompletionHandler = completionHandler;
    if (!self->_streamData) { self->_streamData = [[NSMutableData alloc] init]; }
    [self->_streamData appendData:[message dataUsingEncoding:NSUTF8StringEncoding]];
    
    // open the output steam. we use a timer to make the process time out
    // if the steam did not become available for a certain amount of time.
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_streamTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                                    repeats:NO
                                                                      block:^(NSTimer * _Nonnull timer) {
            [self closeStream:self->_outputStream];
            
            if (completionHandler) {
                NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:@"Failed to open output stream", NSLocalizedDescriptionKey, nil];
                NSError *error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:100 userInfo:errorDetail];
                
                completionHandler(error);
            }
        }];
        
        [self createOutputStreamWithCFWriteStreamRef:writeStream];
    });
}

- (void)stream:(NSStream*)stream handleEvent:(NSStreamEvent)event
{
    switch(event) {
        case NSStreamEventNone:
        {
            break;
        }
            
        case NSStreamEventOpenCompleted:
        {
            // start to write our buffer to the output stream as
            // soon as the stream became open
            if (stream == _outputStream) {
                [_streamTimeoutTimer invalidate];
                [self tcpWriteToOutput];
            }
            break;
        }
            
        case NSStreamEventHasBytesAvailable:
        {
            break;
        }
            
        case NSStreamEventHasSpaceAvailable:
        {
            [self tcpWriteToOutput];
            break;
        }
            
        case NSStreamEventEndEncountered:
        {
            [self closeStream:stream];
            break;
        }
          
        case NSStreamEventErrorOccurred:
        {
            [self closeStream:stream];
            break;
        }
            
        default: {
#ifdef DEBUG
            os_log(OS_LOG_DEFAULT, "SAPCorp: Stream sent an unknown event: %{public}lu", (unsigned long)event);
#endif
            break;
        }
    }
}

- (void)createOutputStreamWithCFWriteStreamRef:(CFWriteStreamRef)writeStream
{
    self->_outputStream = (__bridge_transfer NSOutputStream*)writeStream;
    [self->_outputStream setDelegate:self];
    [self->_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self->_outputStream open];
}

- (void)closeStream:(NSStream*)stream
{
    if ([stream streamStatus] != NSStreamStatusClosed) { [stream close]; }
    stream = nil;
}

- (void)tcpWriteToOutput
{
    dispatch_async(dispatch_get_main_queue(), ^{
    
        if ([self->_streamData length] > 0) {

            NSInteger bytesWritten = [self->_outputStream write:[self->_streamData bytes] maxLength:([self->_streamData length] > 1024) ? 1024 : [self->_streamData length]];

            if (bytesWritten > 0) {
                [self->_streamData replaceBytesInRange:NSMakeRange(0, bytesWritten) withBytes:nil length:0];
            } else if (self->_streamCompletionHandler) {
                    
                // close the stream
                [self closeStream:self->_outputStream];
                
                NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:@"Writing to output stream failed", NSLocalizedDescriptionKey, nil];
                NSError *error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:100 userInfo:errorDetail];
                self->_streamCompletionHandler(error);
            }
            
        } else {
            
            // close the stream
            [self closeStream:self->_outputStream];
            
            // write finished
            if (self->_streamCompletionHandler) { self->_streamCompletionHandler(nil); }
        }
    });
}

@end
