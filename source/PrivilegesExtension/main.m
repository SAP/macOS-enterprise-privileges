/*
    main.m
    Copyright 2016-2026 SAP SE
     
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
#import <uuid/uuid.h>
#import <OpenDirectory/OpenDirectory.h>
#import <bsm/libbsm.h>
#import <unistd.h>
#import "MTPrivilegesExtension.h"
#import "Constants.h"

@interface Main : NSObject
@property (nonatomic, strong, readwrite) MTPrivilegesExtension *privilegesExtension;
@end

typedef struct {
    es_client_t *fileClient;
    es_client_t *execClient;
    es_client_t *userClient;
} PrivilegesESClients;

static NSString *lastODEventFingerprint = nil;
static PrivilegesESClients endpointSecurityClients = { NULL, NULL, NULL };

@implementation Main

- (void)run
{
    os_log(OS_LOG_DEFAULT, "SAPCorp: Running");
    
    dispatch_main();
}
@end

static os_log_t ExtensionLog(void)
{
    static os_log_t log;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        log = os_log_create(kMTLogPersistentSubsystem, kMTLogPersistentCategory);
    });
    
    return log;
}

static void DeleteEndpointSecurityClient(es_client_t **client)
{
    if (client != NULL && *client != NULL) {
        
        es_delete_client(*client);
        *client = NULL;
    }
}

static void DeleteEndpointSecurityClients(PrivilegesESClients *clients)
{
    if (clients != NULL) {
        
        DeleteEndpointSecurityClient(&clients->fileClient);
        DeleteEndpointSecurityClient(&clients->execClient);
        DeleteEndpointSecurityClient(&clients->userClient);
    }
}

static NSString *EndpointSecurityClientErrorMessage(NSString *clientLabel, es_new_client_result_t result)
{
    NSString *errorMsg = [NSString stringWithFormat:@"SAPCorp: Failed to create endpoint security client (%@)", clientLabel];

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
    
    return errorMsg;
}

static BOOL CreateEndpointSecurityClient(es_client_t **client, NSString *clientLabel, void (^eventHandler)(es_client_t *client, const es_message_t *message))
{
    BOOL success = NO;
    
    if (client != NULL) {
        
        *client = NULL;
        es_new_client_result_t result = es_new_client(client, eventHandler);

        if (result == ES_NEW_CLIENT_RESULT_SUCCESS) {
            
            success = YES;
            
        } else {
            
            NSString *errorMsg = EndpointSecurityClientErrorMessage(clientLabel, result);
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "%{public}@", errorMsg);
        }
    }
    
    return success;
}

static BOOL SubscribeEndpointSecurityClient(es_client_t *client, es_event_type_t events[], uint32_t eventCount, NSString *eventLabel)
{
    BOOL success = NO;
    
    if (client != NULL) {
        
        if (es_subscribe(client, events, eventCount) == ES_RETURN_SUCCESS) {
            
            success = YES;
            
        } else {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to subscribe to %{public}@", eventLabel);
        }
    }
    
    return success;
}

static BOOL ConfigureInvertedTargetPathMuting(es_client_t *client, NSArray<NSString*> *paths, NSString *clientLabel)
{
    BOOL success = NO;
    
    if (client != NULL) {
        
        if (es_unmute_all_target_paths(client) != ES_RETURN_SUCCESS) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to unmute target paths for %{public}@", clientLabel);
            
        } else if (es_invert_muting(client, ES_MUTE_INVERSION_TYPE_TARGET_PATH) != ES_RETURN_SUCCESS) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to invert target path muting for %{public}@", clientLabel);
            
        } else {
            
            success = YES;
            
            for (NSString *aPath in paths) {
                
                if (es_mute_path(client, [aPath UTF8String], ES_MUTE_PATH_TYPE_TARGET_PREFIX) != ES_RETURN_SUCCESS) {
                    
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to mute target path %{public}@ for %{public}@", aPath, clientLabel);
                    success = NO;
                    break;
                }
            }
        }
    }
    
    return success;
}

static NSString* NSStringFromESStringToken(es_string_token_t token)
{
    NSString *string = nil;
    
    if (token.data != NULL && token.length > 0) {
    
        string = [[NSString alloc] initWithBytes:token.data
                                          length:token.length
                                        encoding:NSUTF8StringEncoding
        ];
    }

    return string;
}

static NSString *RecordNameFromGeneratedUID(NSString *generatedUID, ODRecordType recordType)
{
    if ([generatedUID length] == 0) { return nil; }

    NSError *error = nil;
    ODNode *node = [ODNode nodeWithSession:[ODSession defaultSession]
                                      type:kODNodeTypeAuthentication
                                     error:&error];

    if (!node) {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Failed to create OD node: %{public}@", error);
        return nil;
    }

    ODQuery *query = [ODQuery queryWithNode:node
                             forRecordTypes:recordType
                                  attribute:kODAttributeTypeGUID
                                  matchType:kODMatchEqualTo
                                queryValues:generatedUID
                           returnAttributes:@[kODAttributeTypeRecordName]
                             maximumResults:1
                                      error:&error];

    if (!query) {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Failed to create OD query: %{public}@", error);
        return nil;
    }

    NSArray *results = [query resultsAllowingPartial:NO error:&error];

    if ([results count] == 0) { return nil; }

    ODRecord *record = [results firstObject];
    NSArray *recordNames = [record valuesForAttribute:kODAttributeTypeRecordName error:&error];

    return [recordNames firstObject];
}

static NSDictionary *MemberInfoFromODMemberID(const es_od_member_id_t *member)
{
    if (member == NULL) { return nil; }

    NSString *memberName = nil;
    es_od_record_type_t memberType = ES_OD_RECORD_TYPE_USER;

    switch (member->member_type) {

        case ES_OD_MEMBER_TYPE_USER_NAME:
            memberName = NSStringFromESStringToken(member->member_value.name);
            break;

        case ES_OD_MEMBER_TYPE_USER_UUID: {
            uuid_string_t uuidString;
            uuid_unparse(member->member_value.uuid, uuidString);
            NSString *generatedUID = [NSString stringWithUTF8String:uuidString];

            memberName = RecordNameFromGeneratedUID(generatedUID, kODRecordTypeUsers);

            if (!memberName) { memberName = generatedUID; }
            
            break;
        }

        case ES_OD_MEMBER_TYPE_GROUP_UUID: {
            uuid_string_t uuidString;
            uuid_unparse(member->member_value.uuid, uuidString);
            NSString *generatedUID = [NSString stringWithUTF8String:uuidString];

            memberName = RecordNameFromGeneratedUID(generatedUID, kODRecordTypeGroups);

            if (!memberName) { memberName = generatedUID; }
            memberType = ES_OD_RECORD_TYPE_GROUP;
            
            break;
        }
    }

    return ([memberName length] == 0) ? nil : [NSDictionary dictionaryWithObjectsAndKeys:
                                                memberName, @"name",
                                                [NSNumber numberWithInt:memberType], @"type",
                                                nil
                                               ];
}

// for preventing duplicate messages for user/group events
static NSString *ODEventFingerprint(const es_message_t *message)
{
    NSString *fingerprint = nil;
    
    if (message != NULL) {
        
        es_od_member_id_t *member = 0;
        es_string_token_t groupName = { 0 };
        es_process_t *instigator = NULL;
        
        switch (message->event_type) {
                
            case ES_EVENT_TYPE_NOTIFY_OD_GROUP_ADD:
                if (message->event.od_group_add == NULL) { return nil; }
                
                member = message->event.od_group_add->member;
                groupName = message->event.od_group_add->group_name;
                instigator = message->event.od_group_add->instigator;
                break;
                
                
            case ES_EVENT_TYPE_NOTIFY_OD_GROUP_REMOVE:
                if (message->event.od_group_remove == NULL) { return nil; }
                
                member = message->event.od_group_remove->member;
                groupName = message->event.od_group_remove->group_name;
                instigator = message->event.od_group_remove->instigator;
                break;
                
            default:
                return nil;
        }
        
        NSString *group = NSStringFromESStringToken(groupName);
        
        NSDictionary *memberInfo = MemberInfoFromODMemberID(member);
        NSString *memberName = memberInfo[@"name"];
        NSNumber *memberType = memberInfo[@"type"];
        
        pid_t processPID = audit_token_to_pid(message->process->audit_token);
        pid_t instigatorPID = audit_token_to_pid(instigator->audit_token);
        
        fingerprint = [NSString stringWithFormat:@"%d|%@|%@|%@|%d|%d",
                       message->event_type,
                       group,
                       memberName ?: @"",
                       memberType ?: [NSNumber numberWithInt:0],
                       processPID,
                       instigatorPID
        ];
    }

    return fingerprint;
}

static NSDictionary *ProcessInfoDictionary(const es_process_t *process)
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    if (process != NULL) {
        
        // pid
        dict[@"pid"] = [NSNumber numberWithUnsignedInt:audit_token_to_pid(process->audit_token)];
        dict[@"ppid"] = [NSNumber numberWithUnsignedInt:process->ppid];
        
        // audit token
        dict[@"audit_token"] = [NSArray arrayWithObjects:
                                [NSNumber numberWithUnsignedInt:process->audit_token.val[0]],
                                [NSNumber numberWithUnsignedInt:process->audit_token.val[1]],
                                [NSNumber numberWithUnsignedInt:process->audit_token.val[2]],
                                [NSNumber numberWithUnsignedInt:process->audit_token.val[3]],
                                [NSNumber numberWithUnsignedInt:process->audit_token.val[4]],
                                [NSNumber numberWithUnsignedInt:process->audit_token.val[5]],
                                [NSNumber numberWithUnsignedInt:process->audit_token.val[6]],
                                [NSNumber numberWithUnsignedInt:process->audit_token.val[7]],
                                nil
        ];
        
        // executable
        dict[@"executable"] = (process->executable) ? NSStringFromESStringToken(process->executable->path) : @"";
                
        // tty
        dict[@"tty"] = (process->tty) ? NSStringFromESStringToken(process->tty->path) : @"";
        
        // start time
        NSDate *startTime = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)process->start_time.tv_sec + process->start_time.tv_usec / 1000000.0];
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        NSString *timeString = [dateFormatter stringFromDate:startTime];
        
        dict[@"start_time"] = timeString;
        
        // responsible audit token
        dict[@"responsible_audit_token"] = [NSArray arrayWithObjects:
                                            [NSNumber numberWithUnsignedInt:process->responsible_audit_token.val[0]],
                                            [NSNumber numberWithUnsignedInt:process->responsible_audit_token.val[1]],
                                            [NSNumber numberWithUnsignedInt:process->responsible_audit_token.val[2]],
                                            [NSNumber numberWithUnsignedInt:process->responsible_audit_token.val[3]],
                                            [NSNumber numberWithUnsignedInt:process->responsible_audit_token.val[4]],
                                            [NSNumber numberWithUnsignedInt:process->responsible_audit_token.val[5]],
                                            [NSNumber numberWithUnsignedInt:process->responsible_audit_token.val[6]],
                                            [NSNumber numberWithUnsignedInt:process->responsible_audit_token.val[7]],
                                            nil
        ];
        
        // parent audit token
        dict[@"parent_audit_token"] = [NSArray arrayWithObjects:
                                       [NSNumber numberWithUnsignedInt:process->parent_audit_token.val[0]],
                                       [NSNumber numberWithUnsignedInt:process->parent_audit_token.val[1]],
                                       [NSNumber numberWithUnsignedInt:process->parent_audit_token.val[2]],
                                       [NSNumber numberWithUnsignedInt:process->parent_audit_token.val[3]],
                                       [NSNumber numberWithUnsignedInt:process->parent_audit_token.val[4]],
                                       [NSNumber numberWithUnsignedInt:process->parent_audit_token.val[5]],
                                       [NSNumber numberWithUnsignedInt:process->parent_audit_token.val[6]],
                                       [NSNumber numberWithUnsignedInt:process->parent_audit_token.val[7]],
                                       nil
        ];
        
        // code signing
        dict[@"is_platform_binary"] = [NSNumber numberWithBool:process->is_platform_binary];
        dict[@"is_es_client"] = [NSNumber numberWithBool:process->is_es_client];
        dict[@"team_id"] = (process->team_id.length) ? NSStringFromESStringToken(process->team_id) : @"";
        dict[@"signing_id"] = (process->signing_id.length) ? NSStringFromESStringToken(process->signing_id) : @"";
        
        // cdhash
        NSMutableString *hash = [[NSMutableString alloc] init];
        for (int i = 0; i < sizeof(process->cdhash); i++) { [hash appendFormat:@"%02x", process->cdhash[i]]; }
        dict[@"cdhash"] = ([hash length] > 0) ? hash : @"";
    }

    return dict;
}

static NSString *JSONStringFromJSONObject(id jsonObject)
{
    NSString *jsonString = nil;
    
    if (jsonObject && [NSJSONSerialization isValidJSONObject:jsonObject]) {
        
        NSData *data = [NSJSONSerialization dataWithJSONObject:jsonObject
                                                       options:NSJSONWritingWithoutEscapingSlashes
                                                         error:nil
        ];
        
        if (data) { jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]; }
    }
    
    return jsonString;
}

static NSString *PrivilegesLogJSONString(NSDictionary *privilegesInfo, NSDictionary *esfInfo)
{
    NSDictionary *logInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                             privilegesInfo ?: [NSDictionary dictionary], @"privileges",
                             esfInfo ?: [NSDictionary dictionary], @"esf",
                             nil
    ];
    
    return JSONStringFromJSONObject(logInfo);
}

static NSString *ProcessLogJSONString(NSString *eventType, NSString *subject, const es_process_t *process)
{
    NSDictionary *esfInfo = [NSDictionary dictionaryWithObject:ProcessInfoDictionary(process)
                                                        forKey:@"process"
    ];
    
    NSDictionary *privInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              eventType ?: @"", @"event_type",
                              subject ?: @"", @"subject",
                              nil
    ];
    
    return PrivilegesLogJSONString(privInfo, esfInfo);
}

static NSString *PrivilegesChangeLogJSONString(NSString *memberName, es_od_record_type_t memberType, BOOL isAdmin, const es_process_t *instigator)
{
    NSDictionary *esfInfo = [NSDictionary dictionaryWithObject:ProcessInfoDictionary(instigator)
                                                        forKey:@"process"
    ];
    
    NSDictionary *privInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              (isAdmin) ? @"ADMIN_ADD" : @"ADMIN_REMOVE", @"event_type",
                              (memberType == ES_OD_RECORD_TYPE_GROUP) ? @"group" : @"user", @"subject",
                              memberName ?: @"", @"id",
                              nil
    ];
    
    return PrivilegesLogJSONString(privInfo, esfInfo);
}

# pragma mark - Event handlers

static void handle_unlink_events(es_client_t *client, const es_message_t *message)
{
    NSString *itemPath = NSStringFromESStringToken(message->event.unlink.target->path);
    NSString *jsonString = ProcessLogJSONString(@"DELETE", itemPath, message->process);
   
    os_log_with_type(ExtensionLog(), OS_LOG_TYPE_DEFAULT, "SAPCorp: Prevented deletion of protected item: %{public}@", itemPath);
    os_log_with_type(ExtensionLog(), OS_LOG_TYPE_DEFAULT, "%{public}@", jsonString);
    
    es_respond_auth_result(client, message, ES_AUTH_RESULT_DENY, false);
}

static void handle_rename_events(es_client_t *client, const es_message_t *message)
{
    NSString *itemPath = NSStringFromESStringToken(message->event.rename.source->path);
    NSString *jsonString = ProcessLogJSONString(@"RENAME", itemPath, message->process);
   
    os_log_with_type(ExtensionLog(), OS_LOG_TYPE_DEFAULT, "SAPCorp: Prevented renaming of protected item: %{public}@", itemPath);
    os_log_with_type(ExtensionLog(), OS_LOG_TYPE_DEFAULT, "%{public}@", jsonString);
    
    es_respond_auth_result(client, message, ES_AUTH_RESULT_DENY, false);
}

static void handle_clone_events(es_client_t *client, const es_message_t *message)
{
    NSString *itemPath = NSStringFromESStringToken(message->event.clone.source->path);
    NSString *jsonString = ProcessLogJSONString(@"CLONE", itemPath, message->process);
   
    os_log_with_type(ExtensionLog(), OS_LOG_TYPE_DEFAULT, "SAPCorp: Prevented cloning of protected item: %{public}@", itemPath);
    os_log_with_type(ExtensionLog(), OS_LOG_TYPE_DEFAULT, "%{public}@", jsonString);
    
    es_respond_auth_result(client, message, ES_AUTH_RESULT_DENY, false);
}

static void handle_create_events(es_client_t *client, const es_message_t *message)
{
    es_event_create_t createEvent = message->event.create;
    
    NSString *itemName = NSStringFromESStringToken(createEvent.destination.new_path.filename);
    NSString *destinationPath = NSStringFromESStringToken(createEvent.destination.existing_file->path);
    NSString *subject = [destinationPath stringByAppendingPathComponent:itemName];
    NSString *jsonString = ProcessLogJSONString(@"CREATE", subject, message->process);
   
    os_log_with_type(ExtensionLog(), OS_LOG_TYPE_DEFAULT, "SAPCorp: Prevented creation of item: %{public}@", subject);
    os_log_with_type(ExtensionLog(), OS_LOG_TYPE_DEFAULT, "%{public}@", jsonString);
    
    es_respond_auth_result(client, message, ES_AUTH_RESULT_DENY, false);
}

static void handle_exec_events(es_client_t *client, const es_message_t *message)
{
    es_auth_result_t authResult = ES_AUTH_RESULT_ALLOW;

    es_event_exec_t execEvent = message->event.exec;
    NSString *signingID = NSStringFromESStringToken(execEvent.target->signing_id);
    
    if ([signingID isEqualToString:@"com.apple.xpc.launchctl"]) {
        
        bool isPlatformBinary = execEvent.target->is_platform_binary;
        int count = es_exec_arg_count(&execEvent);

        if (count > 1 && isPlatformBinary) {
            
            NSMutableArray *arguments = [[NSMutableArray alloc] init];
            
            for (int i = 1; i < count; i++) {
                
                es_string_token_t argument = es_exec_arg(&execEvent, i);
                
                if (argument.length > 0) {
                    
                    NSString *argumentString = NSStringFromESStringToken(argument);
                    
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
                    
                    NSString *protectedPlist = [filteredArray firstObject];
                    NSString *jsonString = ProcessLogJSONString(@"EXEC", protectedPlist, execEvent.target);
                    
                    os_log_with_type(ExtensionLog(), OS_LOG_TYPE_DEFAULT, "SAPCorp: Prevented unloading of protected launchd plist: %{public}@", protectedPlist);
                    os_log_with_type(ExtensionLog(), OS_LOG_TYPE_DEFAULT, "%{public}@", jsonString);
                    
                    authResult = ES_AUTH_RESULT_DENY;
                }
            }
        }
    }

    es_respond_auth_result(client, message, authResult, false);
}

static void handle_group_events(es_client_t *client, const es_message_t *message)
{
#pragma unused(client)
    
    if (message != NULL) {
        
        NSString *fingerprint = ODEventFingerprint(message);
        
        if ([fingerprint isEqualToString:lastODEventFingerprint]) {
            os_log(OS_LOG_DEFAULT, "SAPCorp: Ignoring duplicate event");
            return;
        }
        
        lastODEventFingerprint = fingerprint;
        
        NSDictionary *memberInfo = nil;
        NSString *groupName = nil;
        es_process_t *instigator = NULL;
        BOOL isAdmin = NO;
        
        switch (message->event_type) {
                
            case ES_EVENT_TYPE_NOTIFY_OD_GROUP_ADD:
                if (message->event.od_group_add == NULL) { return; }
                memberInfo = MemberInfoFromODMemberID(message->event.od_group_add->member);
                groupName = NSStringFromESStringToken(message->event.od_group_add->group_name);
                instigator = message->event.od_group_add->instigator;
                isAdmin = YES;
                break;
                
                
            case ES_EVENT_TYPE_NOTIFY_OD_GROUP_REMOVE:
                if (message->event.od_group_remove == NULL) { return; }
                memberInfo = MemberInfoFromODMemberID(message->event.od_group_remove->member);
                groupName = NSStringFromESStringToken(message->event.od_group_remove->group_name);
                instigator = message->event.od_group_remove->instigator;
                break;
                
            default:
                return;
        }
        
        if ([groupName isEqualToString:@"admin"]) {
            
            NSString *memberName = [memberInfo objectForKey:@"name"];
            es_od_record_type_t memberType = [[memberInfo objectForKey:@"type"] intValue];

            if ([memberName length] > 0) {
                
                NSString *jsonString = PrivilegesChangeLogJSONString(memberName, memberType, isAdmin, instigator);
                
                // regular log message
                NSMutableString *logMessage = [NSMutableString stringWithFormat:@"SAPCorp: %@ %@ %@ administrator privileges",
                                               (memberType == ES_OD_RECORD_TYPE_GROUP) ? @"Group" : @"User",
                                               memberName,
                                               (isAdmin) ? @"gained" : @"lost"
                ];
                                
                if (instigator != NULL && instigator->executable != NULL) {
                    
                    NSString *instigatorPath = NSStringFromESStringToken(instigator->executable->path);
                    if (instigatorPath) { [logMessage appendFormat:@" instigated by %@", instigatorPath]; }
                }
                
                os_log_with_type(ExtensionLog(), OS_LOG_TYPE_DEFAULT, "%{public}@", logMessage);
                os_log_with_type(ExtensionLog(), OS_LOG_TYPE_DEFAULT, "%{public}@", jsonString);
            }
        }
    }
}

static void handle_auth_event(es_client_t *client, const es_message_t *message, bool isPaused)
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
                
            case ES_EVENT_TYPE_AUTH_CREATE:
                handle_create_events(client, message);
                break;
                
            case ES_EVENT_TYPE_AUTH_EXEC:
                handle_exec_events(client, message);
                break;
                
            default:
                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Unexpected auth event type encountered: %d", message->event_type);
        }
    }
}

API_AVAILABLE(macos(14.0))
static void handle_user_event(es_client_t *client, const es_message_t *message, bool isPaused)
{
    if (isPaused) { return; }

    switch (message->event_type) {
            
        case ES_EVENT_TYPE_NOTIFY_OD_GROUP_ADD:
        case ES_EVENT_TYPE_NOTIFY_OD_GROUP_REMOVE:
            handle_group_events(client, message);
            break;

        default:
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Unexpected user event type encountered: %d", message->event_type);
    }
}

#pragma mark - Client initialization

static BOOL InitializeFileClient(PrivilegesESClients *clients, MTPrivilegesExtension *privilegesExtension)
{
    BOOL success = NO;
    
    if (clients != NULL && privilegesExtension != nil) {
        
        success = CreateEndpointSecurityClient(&clients->fileClient, @"file events", ^(es_client_t *client, const es_message_t *message) {
            handle_auth_event(client, message, [privilegesExtension isPaused]);
        });
        
        if (success) {
            
            NSArray *protectedPaths = [NSArray arrayWithObjects:
                                       @"/Applications/Privileges.app",
                                       @"/Library/LaunchDaemons/corp.sap.privileges.daemon.plist",
                                       @"/Library/LaunchDaemons/corp.sap.privileges.helper.plist",
                                       @"/Library/LaunchDaemons/corp.sap.privileges.watcher.plist",
                                       @"/Library/LaunchAgents/corp.sap.privileges.agent.plist",
                                       nil
            ];
            
            success = ConfigureInvertedTargetPathMuting(clients->fileClient, protectedPaths, @"file events");
        }
        
        if (success) {
            
            es_event_type_t fileEvents[] = {
                ES_EVENT_TYPE_AUTH_CLONE,
                ES_EVENT_TYPE_AUTH_CREATE,
                ES_EVENT_TYPE_AUTH_RENAME,
                ES_EVENT_TYPE_AUTH_UNLINK
            };
            
            success = SubscribeEndpointSecurityClient(
                                                      clients->fileClient,
                                                      fileEvents,
                                                      sizeof(fileEvents) / sizeof(fileEvents[0]),
                                                      @"file events"
                                                      );
        }
    }
    
    return success;
}

static BOOL InitializeExecClient(PrivilegesESClients *clients, MTPrivilegesExtension *privilegesExtension)
{
    BOOL success = NO;
    
    if (clients != NULL && privilegesExtension != nil) {
        
        success = CreateEndpointSecurityClient(&clients->execClient, @"exec events", ^(es_client_t *client, const es_message_t *message) {
            handle_auth_event(client, message, [privilegesExtension isPaused]);
        });
        
        if (success) {
            
            NSArray *protectedExecPaths = [NSArray arrayWithObject:@"/bin/launchctl"];
            success = ConfigureInvertedTargetPathMuting(clients->execClient, protectedExecPaths, @"exec events");
        }
        
        if (success) {
            
            es_event_type_t execEvents[] = {
                ES_EVENT_TYPE_AUTH_EXEC
            };
            
            success = SubscribeEndpointSecurityClient(
                                                      clients->execClient,
                                                      execEvents,
                                                      sizeof(execEvents) / sizeof(execEvents[0]),
                                                      @"exec events"
                                                      );
        }
    }
    
    return success;
}

API_AVAILABLE(macos(14.0))
static BOOL InitializeUserClient(PrivilegesESClients *clients, MTPrivilegesExtension *privilegesExtension)
{
    BOOL success = NO;
    
    if (clients != NULL && privilegesExtension != nil) {
        
        success = CreateEndpointSecurityClient(&clients->userClient, @"user/group events", ^(es_client_t *client, const es_message_t *message) {
            handle_user_event(client, message, [privilegesExtension isPaused]);
        });
        
        if (success) {
            
            es_event_type_t userEvents[] = {
                ES_EVENT_TYPE_NOTIFY_OD_GROUP_ADD,
                ES_EVENT_TYPE_NOTIFY_OD_GROUP_REMOVE
            };
            
            success = SubscribeEndpointSecurityClient(
                                                      clients->userClient,
                                                      userEvents,
                                                      sizeof(userEvents) / sizeof(userEvents[0]),
                                                      @"user/group events"
                                                      );
        }
    }
    
    return success;
}

static BOOL InitializeEndpointSecurityClients(PrivilegesESClients *clients, MTPrivilegesExtension *privilegesExtension)
{
    BOOL success = NO;
    
    if (clients != NULL && privilegesExtension != nil) {
        
        DeleteEndpointSecurityClients(clients);
        
        if (InitializeFileClient(clients, privilegesExtension) &&
            InitializeExecClient(clients, privilegesExtension)) {
            
            success = YES;
            
            if (@available(macOS 14.0, *)) {
                success = InitializeUserClient(clients, privilegesExtension);
            }
        }
        
        if (!success) {
            DeleteEndpointSecurityClients(clients);
        }
    }
    
    return success;
}

int main(int argc, char *argv[])
{
#pragma unused(argc)
#pragma unused(argv)
    
    os_log(OS_LOG_DEFAULT, "SAPCorp: Starting");
    
    @autoreleasepool {
        
        Main *m = [[Main alloc] init];
        m.privilegesExtension = [[MTPrivilegesExtension alloc] init];
      
        while (![m.privilegesExtension isRunning]) {
            
            if (InitializeEndpointSecurityClients(&endpointSecurityClients, m.privilegesExtension)) {
                
                [m.privilegesExtension setIsRunning:YES];
                
            } else {
                
                sleep(5);
            }
        }
        
        [m run];
    }

    return 0;
}
