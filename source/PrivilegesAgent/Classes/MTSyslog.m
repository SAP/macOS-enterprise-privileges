/*
    MTSyslog.m
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

#import "MTSyslog.h"

@interface MTSyslog ()
@property (nonatomic, strong, readwrite) NSString *serverAddress;
@property (nonatomic, strong, readwrite) NSURLSessionStreamTask *syslogTask;
@property (nonatomic, strong, readwrite) NSURLSession *session;
@property (assign) NSUInteger serverPort;
@property (assign) BOOL useTLS;
@property (assign) BOOL isConnected;
@end

@implementation MTSyslog

- (instancetype)initWithServerAddress:(NSString*)serverAddress serverPort:(NSUInteger)serverPort useTLS:(BOOL)useTLS
{
    self = [super init];
    
    if (self) {
        
        _serverAddress = serverAddress;
        _serverPort = serverPort;
        _useTLS = useTLS;
        
        if (_serverPort == 0) { _serverPort = (_useTLS) ? 6514 : 514; }
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    
    return self;
}

- (void)ensureConnected
{
    if (_isConnected && _syslogTask && [_syslogTask state] == NSURLSessionTaskStateRunning) {
        
        return;
        
    } else {
        
        _isConnected = NO;
        
        // cancel any existing task
        if (_syslogTask) {
            
            [_syslogTask cancel];
            _syslogTask = nil;
        }
        
        _syslogTask = [_session streamTaskWithHostName:_serverAddress port:_serverPort];
        if (_useTLS) { [_syslogTask startSecureConnection]; }
        
        [_syslogTask resume];
        
        
        _isConnected = YES;
    }
}

- (void)writeData:(NSData*)data completionHandler:(void (^) (NSError *error))completionHandler
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self ensureConnected];

        [self->_syslogTask writeData:data
                             timeout:10
                   completionHandler:^(NSError *error) {
            
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{ self->_isConnected = NO; });
            }
            
            if (completionHandler) { completionHandler(error); }
        }];
    });
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{ self->_isConnected = NO; });
    }
}

- (void)dealloc
{
    [_syslogTask cancel];
    [_session invalidateAndCancel];
}

@end
