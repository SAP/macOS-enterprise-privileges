/*
    MTProcessValidation.m
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

#import "MTProcessValidation.h"
#import "Constants.h"
#import <sys/proc_info.h>
#import <sys/sysctl.h>
#import <libproc.h>
#import <os/log.h>

@interface MTProcessValidation ()

@property (nonatomic, strong, readwrite) MTParentProcess *parentProcess;
@property pid_t pid;

@end

@implementation MTProcessValidation

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _pid = getpid();
    }
    
    return self;
}

- (instancetype)initWithPID:(pid_t)pid
{
    self = [super init];
    
    if (self) {
        
        _pid = pid;
        if (_pid <= 0) { self = nil; }
    }
    
    return self;
}

- (MTParentProcess*)parent
{
    if (!_parentProcess) { _parentProcess = [[MTParentProcess alloc] initWithChildPID:_pid]; }
    return _parentProcess;
}

- (BOOL)isValid
{
    BOOL isValid = NO;
    NSArray *validProcesses = [NSArray arrayWithObjects:@"package_script_service", nil];
    NSString *parentProcessName = [[self parent] name];
    
    // just go ahead if the process name is valid and the process
    // is a platform binary (signed with Apple certificates)
    if (parentProcessName && [validProcesses containsObject:parentProcessName] && [[self parent] isPlatformBinary]) {

        // check the open files of the process
        // and get the path to the package
        NSArray *openFiles = [[self parent] openFiles];

        if ([openFiles count] > 0) {

            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH[c] %@", @".pkg"];
            NSArray *filteredArray = [openFiles filteredArrayUsingPredicate:predicate];

            if ([filteredArray count] == 1) {

                // check the package signature
                NSString *pkgPath = [filteredArray firstObject];
                isValid = [self packageIsValidAtPath:pkgPath];

                if (!isValid) { os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Failed to verify signature of package %{public}@", pkgPath); }

            } else {

                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Failed to get package path (multiple paths found)");
            }
            
        } else {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Failed to get package path");
        }
        
    } else {
        
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: The process %{public}@ is not authorized to disable the system extension", parentProcessName);
    }
    
    return isValid;
}

- (BOOL)packageIsValidAtPath:(NSString*)path
{
    BOOL isValid = NO;

    NSTask *checkTask = [[NSTask alloc] init];
    [checkTask setExecutableURL:[NSURL fileURLWithPath:kMTspctlPath]];
    [checkTask setArguments:[NSArray arrayWithObjects:
                             @"-a",
                             @"-vv",
                             @"-t",
                             @"install",
                             path,
                             nil
                            ]
    ];

    NSPipe *errorPipe = [[NSPipe alloc] init];
    [checkTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
    [checkTask setStandardError:errorPipe];
    [checkTask launch];
    [checkTask waitUntilExit];

    NSData *returnData = [[errorPipe fileHandleForReading] readDataToEndOfFile];

    if (returnData) {

        NSString *consoleMsg = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];

        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"origin=(.+)"
                                                                               options: NSRegularExpressionCaseInsensitive
                                                                                 error:nil
        ];
        NSArray *matches = [regex matchesInString:consoleMsg options:0 range:NSMakeRange(0, [consoleMsg length])];

        for (NSTextCheckingResult *match in matches) {

            if ([match numberOfRanges] == 2) {

                NSString *devTeam = [consoleMsg substringWithRange:[match rangeAtIndex:1]];
                isValid = ([devTeam rangeOfString:@"Developer ID Installer:.*(7R5ZEU67FQ)" options:NSRegularExpressionSearch].location != NSNotFound);
            }
        }
    }

    return isValid;
}

@end
