/*
    main.m
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

#import <EndpointSecurity/EndpointSecurity.h>
#import <Cocoa/Cocoa.h>
#import <os/log.h>
#import "MTPrivilegesExtension.h"

@interface Main : NSObject
@property (nonatomic, strong, readwrite) MTPrivilegesExtension *privilegesExtension;
@end

@implementation Main

- (void)run
{
    os_log(OS_LOG_DEFAULT, "SAPCorp: Running");
    
    dispatch_main();
}

@end

# pragma mark - Event handlers

static void handle_unlink_events(es_client_t *client, const es_message_t *message)
{
    NSString *filePath = [NSString stringWithUTF8String:message->event.unlink.target->path.data];
   
    os_log(OS_LOG_DEFAULT, "SAPCorp: Prevented deletion of protected file: %{public}@", filePath);
    es_respond_auth_result(client, message, ES_AUTH_RESULT_DENY, false);
}

static void handle_rename_events(es_client_t *client, const es_message_t *message)
{
    NSString *filePath = [NSString stringWithUTF8String:message->event.rename.source->path.data];
   
    os_log(OS_LOG_DEFAULT, "SAPCorp: Prevented renaming of protected file: %{public}@", filePath);
    es_respond_auth_result(client, message, ES_AUTH_RESULT_DENY, false);
}

static void handle_clone_events(es_client_t *client, const es_message_t *message)
{
    NSString *filePath = [NSString stringWithUTF8String:message->event.clone.source->path.data];
   
    os_log(OS_LOG_DEFAULT, "SAPCorp: Prevented cloning of protected file: %{public}@", filePath);
    es_respond_auth_result(client, message, ES_AUTH_RESULT_DENY, false);
}

static void handle_exec_events(es_client_t *client, const es_message_t *message)
{
    es_auth_result_t authResult = ES_AUTH_RESULT_ALLOW;

    es_event_exec_t execEvent = message->event.exec;
    NSString *signingID = [NSString stringWithUTF8String:execEvent.target->signing_id.data];
    
    if ([signingID isEqualToString:@"com.apple.xpc.launchctl"]) {
        
        bool isPlatformBinary = execEvent.target->is_platform_binary;
        int count = es_exec_arg_count(&execEvent);

        if (count > 1 && isPlatformBinary) {
            
            NSMutableArray *arguments = [[NSMutableArray alloc] init];
            
            for (int i = 1; i < count; i++) {
                
                es_string_token_t argument = es_exec_arg(&execEvent, i);
                
                if (argument.length > 0) {
                    
                    NSString *argumentString = [[NSString alloc] initWithBytes:argument.data
                                                                        length:argument.length
                                                                      encoding:NSUTF8StringEncoding
                    ];
                    
                    if (i == 1 && ![argumentString isEqualToString:@"unload"] && ![argumentString isEqualToString:@"bootout"]) {
                        
                        break;
                        
                    } else {
                        
                        [arguments addObject:argumentString];
                    }
                }
            }
            
            if ([arguments count] > 0) {

                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF LIKE[c] %@", @"*/corp.sap.privileges.*.plist"];
                NSArray *filteredArray = [arguments filteredArrayUsingPredicate:predicate];
                
                if ([filteredArray count] > 0) {
                    
                    os_log(OS_LOG_DEFAULT, "SAPCorp: Prevented unloading of protected launchd plist: %{public}@", [filteredArray firstObject]);
                    authResult = ES_AUTH_RESULT_DENY;
                }
            }
        }
    }

    es_respond_auth_result(client, message, authResult, false);
}

static void handle_event(es_client_t *client, const es_message_t *message, bool isPaused)
{
    if (isPaused) {
        
        es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false);
        
    } else {
        
        switch (message->event_type) {
                
            case ES_EVENT_TYPE_AUTH_UNLINK:
                handle_unlink_events(client, message);
                break;
                
            case ES_EVENT_TYPE_AUTH_RENAME:
                handle_rename_events(client, message);
                break;
                
            case ES_EVENT_TYPE_AUTH_CLONE:
                handle_clone_events(client, message);
                break;
                
            case ES_EVENT_TYPE_AUTH_EXEC:
                handle_exec_events(client, message);
                break;
                
            default:
                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Unexpected event type encountered: %d", message->event_type);
        }
    }
}

int main(int argc, char *argv[])
{
    os_log(OS_LOG_DEFAULT, "SAPCorp: Starting");
    
    Main *m = [[Main alloc] init];
    m.privilegesExtension = [[MTPrivilegesExtension alloc] init];
  
    while (![m.privilegesExtension isRunning]) {
        
#pragma mark - Initialize ES client for file changes
    
        es_client_t *fileClient;
        es_new_client_result_t result = es_new_client(&fileClient, ^(es_client_t *client, const es_message_t *message) {
            handle_event(client, message, [m.privilegesExtension isPaused]);
        });

        if (result != ES_NEW_CLIENT_RESULT_SUCCESS) {
            
            NSString *errorMsg = @"SAPCorp: Failed to create endpoint security client (1)";
            
            switch (result) {
                    
                case ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED:
                    errorMsg = [errorMsg stringByAppendingString:@" because of a lack of TCC permissions (Full Disk Access?)"];
                    break;
                    
                case ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED:
                    errorMsg = [errorMsg stringByAppendingString:@" because of a missing endpoint security entitlement"];
                    break;
                    
                default:
                    errorMsg = [errorMsg stringByAppendingFormat:@": %d", result];
            }
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "%{public}@", errorMsg);
            
            sleep(5);
            continue;
        }

        // subscribe to relevant events
        es_event_type_t fileEvents[] = {
            ES_EVENT_TYPE_AUTH_UNLINK,
            ES_EVENT_TYPE_AUTH_RENAME,
            ES_EVENT_TYPE_AUTH_CLONE
        };
        
        es_unmute_all_target_paths(fileClient);
        es_invert_muting(fileClient, ES_MUTE_INVERSION_TYPE_TARGET_PATH);
        
        NSArray *protectedPaths = [NSArray arrayWithObjects:
                                   @"/Applications/Privileges.app",
                                   @"/Library/LaunchDaemons/corp.sap.privileges.daemon.plist",
                                   @"/Library/LaunchDaemons/corp.sap.privileges.helper.plist",
                                   @"/Library/LaunchDaemons/corp.sap.privileges.watcher.plist",
                                   @"/Library/LaunchAgents/corp.sap.privileges.agent.plist",
                                   nil
        ];
        for (NSString *aPath in protectedPaths) {
            es_mute_path(fileClient, [aPath UTF8String], ES_MUTE_PATH_TYPE_TARGET_PREFIX);
        }

        if (es_subscribe(fileClient, fileEvents, sizeof(fileEvents) / sizeof(fileEvents[0])) != ES_RETURN_SUCCESS) {
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to subscribe to file events");
            es_delete_client(fileClient);
            sleep(5);
            continue;
        }
        
#pragma mark - Initialize ES client for EXEC events
        
        es_client_t *execClient;
        result = es_new_client(&execClient, ^(es_client_t *client, const es_message_t *message) {
            handle_event(client, message, [m.privilegesExtension isPaused]);
        });

        if (result != ES_NEW_CLIENT_RESULT_SUCCESS) {
            
            NSString *errorMsg = @"SAPCorp: Failed to create endpoint security client (2)";
            
            switch (result) {
                    
                case ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED:
                    errorMsg = [errorMsg stringByAppendingString:@" because of a lack of TCC permissions (Full Disk Access?)"];
                    break;
                    
                case ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED:
                    errorMsg = [errorMsg stringByAppendingString:@" because of a missing endpoint security entitlement"];
                    break;
                    
                default:
                    errorMsg = [errorMsg stringByAppendingFormat:@": %d", result];
            }
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "%{public}@", errorMsg);
            
            sleep(5);
            continue;
        }

        // subscribe to relevant events
        es_event_type_t execEvents[] = { ES_EVENT_TYPE_AUTH_EXEC };
        
        es_unmute_all_target_paths(execClient);
        es_invert_muting(execClient, ES_MUTE_INVERSION_TYPE_TARGET_PATH);
        
        NSArray *protectedExecPaths = [NSArray arrayWithObjects:
                                       @"/bin/launchctl",
                                       nil
        ];
            
        for (NSString *aPath in protectedExecPaths) {
            es_mute_path(execClient, [aPath UTF8String], ES_MUTE_PATH_TYPE_TARGET_PREFIX);
        }

        if (es_subscribe(execClient, execEvents, sizeof(execEvents) / sizeof(execEvents[0])) != ES_RETURN_SUCCESS) {
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to subscribe to EXEC events");
            es_delete_client(execClient);
            sleep(5);
            continue;
        }
        
        [m.privilegesExtension setIsRunning:YES];
    }
    
    [m run];

    return 0;
}
