/*
    MTSystemExtension.m
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

#import "MTSystemExtension.h"
#import "MTHelperConnection.h"
#import "Constants.h"

@interface MTSystemExtension ()
@property (nonatomic, strong, readwrite) MTHelperConnection *helperConnection;
@end

@implementation MTSystemExtension

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _helperConnection = [[MTHelperConnection alloc] init];
    }
    
    return self;
}

- (void)statusWithReply:(void(^)(NSString *status))reply
{
    NSString *extensionStatus = kMTExtensionStatusDisabled;
    
    // get the current status of the extension
    [_helperConnection connectToHelperAndExecuteCommandBlock:^{
        
        [[[self->_helperConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to helper: %{public}@", error);
            if (reply) { reply(extensionStatus); }
            
        }] extensionStatusWithReply:^(NSString *status) {

            if (reply) { reply(([status length] > 0) ? status : extensionStatus); }
        }];
    }];
}

- (void)enableWithCompletionHandler:(void(^)(BOOL success, NSError *error))completionHandler;
{
    [_helperConnection connectToHelperAndExecuteCommandBlock:^{
        
        [[[self->_helperConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to helper: %{public}@", error);
            if (completionHandler) { completionHandler(NO, error); }
            
        }] enableExtensionWithCompletionHandler:^(BOOL success, NSError *error) {
            
            if (completionHandler) { completionHandler(success, error); }
        }];
    }];
}

- (void)disableWithCompletionHandler:(void(^)(BOOL success, NSError *error))completionHandler;
{
    [_helperConnection connectToHelperAndExecuteCommandBlock:^{
        
        [[[self->_helperConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to helper: %{public}@", error);
            if (completionHandler) { completionHandler(NO, error); }
            
        }] disableExtensionWithCompletionHandler:^(BOOL success, NSError *error) {
            
            if (completionHandler) { completionHandler(success, error); }
        }];
    }];
}

- (void)suspendWithCompletionHandler:(void(^)(BOOL success, NSError *error))completionHandler;
{
    [_helperConnection connectToHelperAndExecuteCommandBlock:^{
        
        [[[self->_helperConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to helper: %{public}@", error);
            if (completionHandler) { completionHandler(NO, error); }
            
        }] suspendExtensionWithCompletionHandler:^(BOOL success, NSError *error) {
            
            if (completionHandler) { completionHandler(success, error); }
        }];
    }];
}

- (void)dealloc
{
    if (_helperConnection) { [_helperConnection invalidate]; }
}

@end
