/*
    MTRemoteLoggingManager.m
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

#import "MTRemoteLoggingManager.h"
#import "MTDaemonConnection.h"
#import "MTSyslog.h"
#import "MTWebhook.h"
#import "MTPrivileges.h"
#import "Constants.h"

@interface MTRemoteLoggingManager ()
@property (nonatomic, strong, readwrite) NSArray<NSNumber*> *retryIntervals;
@property (nonatomic, strong, readwrite) NSMutableArray<NSDictionary*> *pendingDataQueue;
@property (nonatomic, strong, readwrite) MTPrivileges *privilegesApp;
@property (nonatomic, strong, readwrite) MTDaemonConnection *daemonConnection;
@property (nonatomic, strong, readwrite) NSBackgroundActivityScheduler *retryActivity;
@property (nonatomic, strong, readwrite) NSString *serverType;
@property (nonatomic, strong, readwrite) id loggingObject;
@property (assign) NSUInteger currentRetryIndex;
@property (assign) BOOL isSending;
@property (assign) BOOL isRunning;
@end

@implementation MTRemoteLoggingManager

- (instancetype)initWithRetryIntervals:(NSArray<NSNumber*>*)intervals
{
    self = [super init];
    
    if (self) {

        _currentRetryIndex = 0;
        _isSending = NO;
        _retryIntervals = ([intervals count] > 0) ? intervals : [NSArray arrayWithObject:[NSNumber numberWithInteger:300]];

        _privilegesApp = [[MTPrivileges alloc] init];
        _daemonConnection = [[MTDaemonConnection alloc] init];
        _pendingDataQueue = [[NSMutableArray alloc] init];
                
        MTPrivilegesLoggingConfiguration *remoteLoggingConfiguration = [_privilegesApp remoteLoggingConfiguration];
        
        if (remoteLoggingConfiguration) {
            
            if ([[remoteLoggingConfiguration serverType] isEqualToString:kMTRemoteLoggingServerTypeSyslog]) {

                MTSyslogOptions *syslogOptions = [remoteLoggingConfiguration syslogOptions];
                MTSyslog *syslogObject = [[MTSyslog alloc] initWithServerAddress:[remoteLoggingConfiguration serverAddress]
                                                                      serverPort:[syslogOptions serverPort]
                                                                          useTLS:[syslogOptions useTLS]
                ];
                
                _loggingObject = syslogObject;
                _serverType = kMTRemoteLoggingServerTypeSyslog;
                
                if (![syslogOptions useTLS]) {

                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Remote syslog is configured without TLS. Events will be sent as clear text until TLS is enabled.");
                }
            
            } else if ([[remoteLoggingConfiguration serverType] isEqualToString:kMTRemoteLoggingServerTypeWebhook]) {
                
                NSURL *webhookURL = nil;
                NSString *webhookURLString = [remoteLoggingConfiguration serverAddress];
                if (webhookURLString) { webhookURL = [NSURL URLWithString:webhookURLString]; }
                    
                MTWebhook *webhookObject = [[MTWebhook alloc] initWithURL:webhookURL];
                _loggingObject = webhookObject;
                
                _serverType = kMTRemoteLoggingServerTypeWebhook;
            }
        }
    }
    
    return self;
}

- (BOOL)start
{
    BOOL success = NO;
    
    if (!_isRunning) {

        _isRunning = YES;
        
        if (_queueUnsentEvents) {

            __block NSArray *eventsToAdd = nil;
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            
            [self queuedEventsWithReply:^(NSArray *queuedEvents, NSError *error) {

                if (error) {
                    
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to get queued events: %{public}@", error);
                    
                } else {
                    
                    eventsToAdd = [queuedEvents copy];
                }
                
                dispatch_semaphore_signal(semaphore);
            }];
            
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
            if ([eventsToAdd count] > 0) {
                
                os_log(OS_LOG_DEFAULT, "SAPCorp: Imported events from queue: %ld", [eventsToAdd count]);
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [self->_pendingDataQueue setArray:eventsToAdd];
                
                    // process the queued events
                    [self sendNextEventWithCompletionHandler:nil];
                });
            }
        }
        
        success = YES;
    }

    return success;
}

- (void)sendEvent:(NSDictionary*)event completionHandler:(void (^) (BOOL success, NSError *error))completionHandler
{
    if (_isRunning) {

        [self cancelRetries];
        
        dispatch_async(dispatch_get_main_queue(), ^{

            // add the current event
            if (event) { [self->_pendingDataQueue addObject:event]; }
        
            // store all unsent data
            if (self->_queueUnsentEvents) {

                NSArray *queueCopy = [self->_pendingDataQueue copy];
                [self queueEventsInArray:queueCopy completionHandler:^(BOOL success, NSError *error) {
                    
                    if (!success) {
                        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to update event queue: %{public}@", error);
                    }
                }];
            }

            // only start sending if we're not currently in a send operation
            if (!self->_isSending && [self->_pendingDataQueue count] > 0) {

                self->_currentRetryIndex = 0;
                
                [self sendNextEventWithCompletionHandler:^(BOOL success, NSError *error) {

                    if (completionHandler) { completionHandler(success, error); }
                }];
                
            } else {

                if (completionHandler) { completionHandler(YES, [self errorWithDescription:@"The event has been queued because another operation had to finish first"]); }
            }
        });
        
    } else {
        
        if (completionHandler) {
            
            completionHandler(NO, [self errorWithDescription:@"Logging manager has not been started"]);
        }
    }
}

- (void)sendNextEventWithCompletionHandler:(void (^) (BOOL success, NSError *error))completionHandler
{
    dispatch_async(dispatch_get_main_queue(), ^{
                
        NSUInteger queueCount = [self->_pendingDataQueue count];

        if (queueCount > 0) {

            [self processPendingEvent:[self->_pendingDataQueue firstObject] completionHandler:completionHandler];
            
        } else {
            
            self->_isSending = NO;
                
            // make sure all queued events are removed from disk since all items sent
            [self queueEventsInArray:[NSArray array] completionHandler:^(BOOL success, NSError *error) {
                
                if (!success) {
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to flush event queue: %{public}@", error);
                }
            }];
            
            if (completionHandler) { completionHandler(YES, nil); }
        }
    });
}

- (void)processPendingEvent:arrayItem completionHandler:(void (^) (BOOL success, NSError *error))completionHandler
{
    _isSending = YES;

    MTSyslog *syslogEvent = nil;
    MTWebhook *webhookEvent = nil;
    NSError *completionError = nil;
    BOOL validServerType = NO;
    
    if ([arrayItem isKindOfClass:[NSDictionary class]]) {
        
        NSDictionary *queuedEvent = (NSDictionary*)arrayItem;
        
        // check if the event has the correct type
        id eventObject = [queuedEvent objectForKey:_serverType];
        
        if ([eventObject isKindOfClass:[NSData class]]) {
            
            NSData *eventData = (NSData*)eventObject;
            
            if ([_serverType isEqualToString:kMTRemoteLoggingServerTypeSyslog]) {
                
                validServerType = YES;
                
                syslogEvent = (MTSyslog*)_loggingObject;
                [syslogEvent writeData:eventData completionHandler:^(NSError *error) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self finishEventProcessingWithError:error completionHandler:completionHandler];
                    });
                }];
                
            } else if ([_serverType isEqualToString:kMTRemoteLoggingServerTypeWebhook]) {
                
                validServerType = YES;
                
                webhookEvent = (MTWebhook*)_loggingObject;
                
                // if the event's timestamp is older than one minute, make sure it
                // has its "delayed" key set to true
                NSDictionary *eventDict = [NSJSONSerialization JSONObjectWithData:eventData options:0 error:nil];
                
                if (eventDict) {
                    
                    NSString *tsString = [eventDict objectForKey:kMTWebhookContentKeyTimestamp];
                    
                    if (tsString) {
                        
                        NSISO8601DateFormatter *dateFormatter = [[NSISO8601DateFormatter alloc] init];
                        NSDate *eventTimestamp = [dateFormatter dateFromString:tsString];
                        
                        if (eventTimestamp && [[NSDate date] timeIntervalSinceDate:eventTimestamp] > kMTQueuedEventsTreatAsDelayedInterval) {
                            
                            NSMutableDictionary *newEventDict = [NSMutableDictionary dictionaryWithDictionary:eventDict];
                            [newEventDict setObject:[NSNumber numberWithBool:YES] forKey:kMTWebhookContentKeyDelayed];
                            eventData = [MTWebhook composedDataWithDictionary:newEventDict];
                        }
                    }
                    
                } else {
                    
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Webhook event seems to be malformed");
                }

                [webhookEvent postData:eventData completionHandler:^(NSError *error) {
                                        
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self finishEventProcessingWithError:error completionHandler:completionHandler];
                    });
                }];
                
            } else {
                
                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Cannot send event because of invalid server type");
            }
            
        } else {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Skipping remote logging event because of wrong event type");
        }
        
    } else {
        
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Skipping remote logging event because it's malformed");
    }
    
    if (!validServerType) {

        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishEventProcessingWithError:completionError completionHandler:completionHandler];
        });
    }
}

- (void)finishEventProcessingWithError:(NSError*)completionError completionHandler:(void (^) (BOOL success, NSError *error))completionHandler
{
    _isSending = NO;

    if (completionError) {

        if (completionHandler) {

            completionHandler(NO, completionError);
            
        } else {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Remote logging failed: %{public}@", completionError);
        }
        
        if (_queueUnsentEvents) {
            
            // schedule retry
            [self scheduleRetry];
            
        } else {
            
            dispatch_async(dispatch_get_main_queue(), ^{ [self->_pendingDataQueue removeAllObjects]; });
        }
        
    } else {
        
        // update queue after successful send
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ([self->_pendingDataQueue count] > 0) { [self->_pendingDataQueue removeObjectAtIndex:0]; }
            
            if (self->_queueUnsentEvents) {
                
                NSArray *queueCopy = [self->_pendingDataQueue copy];
                [self queueEventsInArray:queueCopy completionHandler:^(BOOL success, NSError *error) {
                    
                    if (!success) {
                        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to update event queue: %{public}@", error);
                    }
                }];
            }
            
            self->_currentRetryIndex = 0;
        
            [self sendNextEventWithCompletionHandler:completionHandler];
        });
    }
}

- (NSError *)errorWithDescription:(NSString *)description
{
    NSError *error = nil;
    
    if (description) {
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, nil];
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:100 userInfo:errorDetail];
    }
    
    return error;
}

- (void)queuedEventsWithReply:(void (^) (NSArray *queuedEvents, NSError *error))reply
{
    [_daemonConnection connectToDaemonAndExecuteCommandBlock:^{
        
        [[[self->_daemonConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            if (reply) { reply(nil, error); }
            
        }] queuedEventsWithReply:^(NSArray *queuedEvents, NSError *error) {
            
            if (reply) { reply(queuedEvents, error); }
        }];
    }];
}

- (void)cancelRetries
{
    if (_retryActivity) {
        
        [_retryActivity invalidate];
        _retryActivity = nil;
    }
}

- (void)scheduleRetry
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSInteger intervalIndex = MIN(self->_currentRetryIndex, [self->_retryIntervals count] - 1);
        NSTimeInterval interval = [[self->_retryIntervals objectAtIndex:intervalIndex] doubleValue];
        
        [self cancelRetries];
    
        self->_retryActivity = [[NSBackgroundActivityScheduler alloc] initWithIdentifier:@"corp.sap.privileges.remotelogging"];
        if (interval >= 1) { [self->_retryActivity setInterval:interval]; }
        if (interval > 10) { [self->_retryActivity setTolerance:10]; }
        [self->_retryActivity scheduleWithBlock:^(NSBackgroundActivityCompletionHandler completionHandler) {
            
            [self sendNextEventWithCompletionHandler:^(BOOL success, NSError *error) {
                
                if (error) {
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Remote logging failed: %{public}@", error);
                }
                
                completionHandler(NSBackgroundActivityResultFinished);
            }];
        }];
    
        // increase retry index for next attempt
        self->_currentRetryIndex++;
        
        os_log(OS_LOG_DEFAULT, "SAPCorp: A later attempt will be made to resend the queued event(s)");
    });
}

- (void)queueEventsInArray:(NSArray*)events completionHandler:(void (^)(BOOL success, NSError *error))completionHandler
{
    if (events) {
        
        NSMutableArray *finalEvents = [[NSMutableArray alloc] initWithArray:events];
        
        // if the array contains more events than the configured
        // maximum, we remove the necessary number of items from
        // the beginning of the array
        NSInteger configuredMaximum = [[_privilegesApp remoteLoggingConfiguration] queuedEventsMax];
        
        if (configuredMaximum > 0) {
            
            NSInteger removeCount = [finalEvents count] - configuredMaximum;
            
            if (removeCount > 0) {
                
                os_log(OS_LOG_DEFAULT, "SAPCorp: Events in the queue exceed the configured maximum of %ld. Removing: %ld", configuredMaximum, removeCount);
                NSIndexSet *toRemove = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, removeCount)];
                [finalEvents removeObjectsAtIndexes:toRemove];
            }
        }
                
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self->_daemonConnection connectToDaemonAndExecuteCommandBlock:^{
                
                [[[self->_daemonConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
                    
                    if (completionHandler) {completionHandler(NO, error); }
                    
                }] queueEventsInArray:finalEvents completionHandler:^(BOOL success, NSError *error) {
                    
                    if (completionHandler) {completionHandler(success, error); }
                }];
            }];
        });
    }
}

- (void)dealloc
{
    [self cancelRetries];
    _loggingObject = nil;
}

@end
