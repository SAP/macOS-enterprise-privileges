/*
    MTProcessInfo.m
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

#import "MTProcessInfo.h"

@interface MTProcessInfo ()
@property (assign) BOOL currentDateIsEndDate;
@end

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

- (BOOL)systemExtension
{
    BOOL request = [[self arguments] containsObject:@"-e"] || [[self arguments] containsObject:@"--extension"];
    return request;
}

- (MTExtensionRequestType)extensionRequestType
{
    int type = MTExtensionRequestTypeInvalid;
    
    NSInteger index = [[self arguments] indexOfObject:@"-e"];
    if (index == NSNotFound) { index = [[self arguments] indexOfObject:@"--extension"]; }
    
    if (index != NSNotFound && index + 1 < [[self arguments] count]) {
        
        NSString *argument = [[self arguments] objectAtIndex:index + 1];

        NSDictionary *requestTypes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:MTExtensionRequestTypeEnable],    @"on",
                                      [NSNumber numberWithInt:MTExtensionRequestTypeDisable],   @"off",
                                      [NSNumber numberWithInt:MTExtensionRequestTypeManaged],   @"managed",
                                      [NSNumber numberWithInt:MTExtensionRequestTypeSuspend],   @"suspend",
                                      [NSNumber numberWithInt:MTExtensionRequestTypeStatus],    @"status",
                                      nil
        ];

        id dictValue = [requestTypes objectForKey:argument];
        if (dictValue) { type = [dictValue intValue]; }
    }
    
    return type;
}


- (BOOL)showHistory
{
    BOOL show = [[self arguments] containsObject:@"-h"] || [[self arguments] containsObject:@"--history"];
    return show;
}

- (NSDate*)historyStartDate
{
    NSDate *startDate = nil;
    _currentDateIsEndDate = YES;
    
    NSInteger index = [[self arguments] indexOfObject:@"-l"];
    if (index == NSNotFound) { index = [[self arguments] indexOfObject:@"--last"]; }
    
    if (index != NSNotFound && index + 1 < [[self arguments] count]) {
        
        NSString *durationString = [[self arguments] objectAtIndex:index + 1];
        
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^([0-9]+)([mhd]?)$"
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil
        ];

        NSTextCheckingResult *match = [regex firstMatchInString:durationString
                                                        options:0
                                                          range:NSMakeRange(0, [durationString length])];

        if (match) {
            
            NSString *numberString = [durationString substringWithRange:[match rangeAtIndex:1]];
            NSInteger value = [numberString integerValue];
            
            if (value > 0) {
                
                NSString *unitString = [durationString substringWithRange:[match rangeAtIndex:2]];
                
                NSCalendarUnit unit = NSCalendarUnitMinute;
                
                if ([[unitString lowercaseString] isEqualToString:@"h"]) {
                    
                    unit = NSCalendarUnitHour;
                    
                } else if ([[unitString lowercaseString] isEqualToString:@"d"]) {
                    
                    unit = NSCalendarUnitDay;
                }
                
                startDate = [[NSCalendar currentCalendar] dateByAddingUnit:unit value:-value toDate:[NSDate date] options:0];
            }
        }
        
    } else {
        
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDate *startOfToday = [calendar startOfDayForDate:[NSDate now]];
        
        index = [[self arguments] indexOfObject:@"-Y"];
        if (index == NSNotFound) { index = [[self arguments] indexOfObject:@"--yesterday"]; }
        
        if (index != NSNotFound) {
            
            NSDate *startOfYesterday = [calendar dateByAddingUnit:NSCalendarUnitDay
                                                            value:-1
                                                           toDate:startOfToday
                                                          options:0
            ];
            
            _currentDateIsEndDate = NO;
            return startOfYesterday;
        }
        
        index = [[self arguments] indexOfObject:@"-T"];
        if (index == NSNotFound) { index = [[self arguments] indexOfObject:@"--today"]; }
        if (index != NSNotFound) { return startOfToday; }
    }
    
    return startDate;
}

- (NSDate*)historyEndDate
{
    NSDate *endDate = [NSDate now];
    
    if (!_currentDateIsEndDate) {
        
        NSInteger index = [[self arguments] indexOfObject:@"-Y"];
        if (index == NSNotFound) { index = [[self arguments] indexOfObject:@"--yesterday"]; }
        
        if (index != NSNotFound) {
            
            NSCalendar *calendar = [NSCalendar currentCalendar];
            NSDate *startOfToday = [calendar startOfDayForDate:endDate];
            endDate = [startOfToday dateByAddingTimeInterval:-1];
        }
    }
    
    return endDate;
}

- (BOOL)historyFormatJSON
{
    BOOL json = [[self arguments] containsObject:@"-j"] || [[self arguments] containsObject:@"--json"];
    return json;
}

- (BOOL)historyOnlyShowsPrivilegeChanges
{
    BOOL privilegeChangesOnly = [[self arguments] containsObject:@"-p"] || [[self arguments] containsObject:@"--privilege-changes-only"];
    return privilegeChangesOnly;
}

@end
