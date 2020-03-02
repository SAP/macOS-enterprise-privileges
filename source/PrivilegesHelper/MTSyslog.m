/*
MTSyslog.m
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

#import "MTSyslog.h"
#import "MTSocketWrite.h"

@interface MTSyslog ()
@property (atomic, strong, readwrite) NSString *serverAddress;
@property (atomic, assign) NSUInteger serverPort;
@property (atomic, assign) MTSocketTransportLayerProtocol serverProtocol;
@property (atomic, strong, readwrite) MTSocketWrite *socket;
@end

@implementation MTSyslog

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

- (void)sendMessage:(MTSyslogMessage*)syslogMessage completionHandler:(void (^) (NSError* _Nullable error))completionHandler
{
    NSString *errorMsg = nil;
    NSString *messageString = [syslogMessage messageString];

    if (messageString) {
        
        _socket = [[MTSocketWrite alloc] initWithServerAddress:_serverAddress
                                                    serverPort:_serverPort
                                                   andProtocol:_serverProtocol
                                 ];
        if (_socket) {

            [_socket writeMessage:messageString completionHandler:^(NSError * _Nullable error) {
                if (completionHandler) { completionHandler(error); }
                self->_socket = nil;
                }];
            
        } else {
            errorMsg = @"MTSocketWrite object could not be initialized";
        }
            
    } else {
        errorMsg = @"Syslog message string could not be created";
    }
        
    if (errorMsg && completionHandler) {
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:errorMsg, NSLocalizedDescriptionKey, nil];
        NSError *error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] code:100 userInfo:errorDetail];
        
        completionHandler(error);
    }
}

@end
