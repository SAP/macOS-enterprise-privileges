/*
 Constants.h
 Copyright 2022 SAP SE
 
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

#define kMTAdminGroupID                 80
#define kMTDockTimeoutDefault           20
#define kMTReasonMinLengthDefault       10
#define kMTReasonMaxLengthDefault       100
#define kMTFixedTimeoutValues           @[@0, @5, @10, @20, @60]

#define kMTDefaultsToggleTimeout        @"DockToggleTimeout"
#define kMTDefaultsToggleMaxTimeout     @"DockToggleMaxTimeout"
#define kMTDefaultsEnforcePrivileges    @"EnforcePrivileges"
#define kMTDefaultsAuthRequired         @"RequireAuthentication"
#define kMTDefaultsLimitToUser          @"LimitToUser"
#define kMTDefaultsLimitToGroup         @"LimitToGroup"
#define kMTDefaultsRequireReason        @"ReasonRequired"
#define kMTDefaultsReasonMinLength      @"ReasonMinLength"
#define kMTDefaultsReasonMaxLength      @"ReasonMaxLength"
#define kMTDefaultsReasonPresets        @"ReasonPresetList"
#define kMTDefaultsRemoteLogging        @"RemoteLogging"
#define kMTDefaultsRLServerType         @"ServerType"
#define kMTDefaultsRLServerAddress      @"ServerAddress"
#define kMTDefaultsRLServerPort         @"ServerPort"
#define kMTDefaultsRLEnableTCP          @"EnableTCP"
#define kMTDefaultsRLSyslogOptions      @"SyslogOptions"
#define kMTDefaultsRLSyslogFacility     @"LogFacility"
#define kMTDefaultsRLSyslogSeverity     @"LogSeverity"
#define kMTDefaultsRLSyslogMaxSize      @"MaximumMessageSize"
