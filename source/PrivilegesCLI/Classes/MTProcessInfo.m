/*
    MTProcessInfo.m
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

#import "MTProcessInfo.h"

@implementation MTProcessInfo

- (BOOL)showStatus
{
    BOOL show = [[self arguments] containsObject:@"-s"] || [[self arguments] containsObject:@"--status"];
    return show;
}

- (BOOL)requestPrivileges
{
    BOOL request = [[self arguments] containsObject:@"-a"] || [[self arguments] containsObject:@"--add"];
    return request;
}

- (BOOL)revertPrivileges
{
    BOOL revert = [[self arguments] containsObject:@"-r"] || [[self arguments] containsObject:@"--remove"];
    return revert;
}

- (BOOL)showVersion
{
    BOOL show = [[self arguments] containsObject:@"-v"] || [[self arguments] containsObject:@"--version"];
    return show;
}

- (NSURL*)launchURL
{
    NSURL *url = nil;
    
    NSString *launchPath = [[self arguments] firstObject];
    if (launchPath) { url = [NSURL fileURLWithPath:launchPath]; }

    return url;
}

- (NSString *)requestReason
{
    NSString *reason = nil;
    
    NSInteger index = [[self arguments] indexOfObject:@"-n"];
    if (index == NSNotFound) { index = [[self arguments] indexOfObject:@"--reason"]; }
    
    if (index != NSNotFound && index + 1 < [[self arguments] count]) {
        
        reason = [[self arguments] objectAtIndex:index + 1];
    }
    
    return reason;
}

@end
