/*
    main.m
    Copyright 2024 SAP SE
     
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
#import "PrivilegesXPC.h"
#import "MTCodeSigning.h"
#import <os/log.h>

@interface ServiceDelegate : NSObject <NSXPCListenerDelegate>
@end

@interface ExtendedNSXPCConnection : NSXPCConnection
@property audit_token_t auditToken;
@end

OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

@implementation ServiceDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection 
{
    BOOL acceptConnection = NO;
    
    // see how we have been signed and make sure only processes with the same signing authority can connect.
    // additionally the calling application must have the same version number as this xpc service and must be
    // one of the components using a bundle identifier starting with "corp.sap.privileges"
    NSError *error = nil;
    NSString *signingAuth = [MTCodeSigning getSigningAuthorityWithError:&error];
    NSString *requiredVersion = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    if (signingAuth) {
        
        NSString *reqString = [MTCodeSigning codeSigningRequirementsWithCommonName:signingAuth
                                                                  bundleIdentifier:@"corp.sap.privileges*" 
                                                                     versionString:requiredVersion
        ];
        SecTaskRef taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
       
        if (taskRef) {            
            
            if (SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(reqString)) == errSecSuccess) {

                acceptConnection = YES;
                   
                newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(PrivilegesXPCProtocol)];
                PrivilegesXPC *exportedObject = [PrivilegesXPC new];
                newConnection.exportedObject = exportedObject;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
                [newConnection setInvalidationHandler:^{
                              
                    [newConnection setInvalidationHandler:nil];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        os_log(OS_LOG_DEFAULT, "SAPCorp: %{public}@ invalidated", newConnection);
                    });
                }];
#pragma clang diagnostic pop

                [newConnection resume];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    os_log(OS_LOG_DEFAULT, "SAPCorp: %{public}@ established", newConnection);
                });
    
            } else {
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Code signature verification failed");
            }
                
            CFRelease(taskRef);
        }
            
    } else {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Failed to get code signature: %{public}@", error);
    }
        
    return acceptConnection;
}

@end

int main(int argc, const char *argv[])
{
    // Create the delegate for the service.
    ServiceDelegate *delegate = [ServiceDelegate new];
    
    // Set up the one NSXPCListener for this service. It will handle all incoming connections.
    NSXPCListener *listener = [NSXPCListener serviceListener];
    listener.delegate = delegate;
    
    // Resuming the serviceListener starts this service. This method does not return.
    [listener resume];
    
    return 0;
}
