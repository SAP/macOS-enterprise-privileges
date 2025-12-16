/*
    MTExtensionRequestType.h
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

/*!
 @enum          MTExtensionRequestType
 @abstract      Specifies the type of a system extension request.
 @constant      MTExtensionRequestTypeDisable Specifies a request to disable a system extension.
 @constant      MTExtensionRequestTypeEnable Specifies a request to enable a system extension.
 @constant      MTExtensionRequestTypeManaged Specifies a request to enable or disable a system extension based on a managed configuration.
 @constant      MTExtensionRequestTypeSuspend Specifies a request to suspend a system extension, leaving it enabled but suspending all of its activities.
 @constant      MTExtensionRequestTypeStatus Specifies a request to get the status of a system extension.
 @constant      MTExtensionRequestTypeInvalid Specifies a an invalid request.
 
*/
typedef enum {
    MTExtensionRequestTypeDisable   = 0,
    MTExtensionRequestTypeEnable    = 1,
    MTExtensionRequestTypeManaged   = 2,
    MTExtensionRequestTypeSuspend   = 3,
    MTExtensionRequestTypeStatus    = 4,
    MTExtensionRequestTypeInvalid   = 9
} MTExtensionRequestType;
