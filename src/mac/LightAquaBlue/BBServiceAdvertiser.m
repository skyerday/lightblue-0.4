/*
 * Copyright (c) 2009 Bea Lam. All rights reserved.
 *
 * This file is part of LightBlue.
 *
 * LightBlue is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * LightBlue is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with LightBlue.  If not, see <http://www.gnu.org/licenses/>.
*/

//
//  BBServiceAdvertiser.m
//  LightAquaBlue
//


#import <IOBluetooth/IOBluetoothUserLib.h>
#import <IOBluetooth/objc/IOBluetoothSDPServiceRecord.h>
#import <IOBluetooth/objc/IOBluetoothSDPUUID.h>
#import <IOBluetooth/objc/IOBluetoothDevicePair.h>

#import "BBServiceAdvertiser.h"


static NSString *kServiceItemKeyServiceClassIDList;
static NSString *kServiceItemKeyServiceName;
static NSString *kServiceItemKeyProtocolDescriptorList;

// template service dictionaries for each pre-defined profile
static NSDictionary *serialPortProfileDict;
static NSDictionary *objectPushProfileDict;
static NSDictionary *fileTransferProfileDict;

@implementation BBServiceAdvertiser



+ (void)initialize
{
	kServiceItemKeyServiceClassIDList = @"0001 - ServiceClassIDList";
	kServiceItemKeyServiceName = @"0100 - ServiceName*";
	kServiceItemKeyProtocolDescriptorList = @"0004 - ProtocolDescriptorList";
	
	// initialize the template service dictionaries
	NSBundle *classBundle = [NSBundle bundleForClass:[BBServiceAdvertiser class]];
	serialPortProfileDict = 
		[[NSDictionary alloc] initWithContentsOfFile:[classBundle pathForResource:@"SerialPortDictionary"
                                                                           ofType:@"plist"]];
	objectPushProfileDict = 
		[[NSDictionary alloc] initWithContentsOfFile:[classBundle pathForResource:@"OBEXObjectPushDictionary"
                                                                           ofType:@"plist"]];
	fileTransferProfileDict = 
		[[NSDictionary alloc] initWithContentsOfFile:[classBundle pathForResource:@"OBEXFileTransferDictionary"
                                                                           ofType:@"plist"]];
	
	//kRFCOMMChannelNone = 0;
	//kRFCOMM_UUID = [[IOBluetoothSDPUUID uuid16:kBluetoothSDPUUID16RFCOMM] retain];	
}

+ (NSDictionary *)serialPortProfileDictionary
{
	return serialPortProfileDict;
}

+ (NSDictionary *)objectPushProfileDictionary
{
	return objectPushProfileDict;
}

+ (NSDictionary *)fileTransferProfileDictionary
{
	return fileTransferProfileDict;
}


+ (void)updateServiceDictionary:(NSMutableDictionary *)sdpEntries
					   withName:(NSString *)serviceName
					   withUUID:(IOBluetoothSDPUUID *)uuid
{
	if (sdpEntries == nil) return;
	
	// set service name
	if (serviceName != nil) {
		[sdpEntries setObject:serviceName forKey:kServiceItemKeyServiceName];
	}
	
	// set service uuid if given
	if (uuid != nil) {
		
		NSMutableArray *currentServiceList = 
		[sdpEntries objectForKey:kServiceItemKeyServiceClassIDList];
		
		if (currentServiceList == nil) {
			currentServiceList = [NSMutableArray array];
		} 
		
		[currentServiceList addObject:[NSData dataWithBytes:[uuid bytes] length:[uuid length]]];
		
		// update dict
		[sdpEntries setObject:currentServiceList forKey:kServiceItemKeyServiceClassIDList];
	}
}


+ (IOReturn)addRFCOMMServiceDictionary:(NSDictionary *)dict
							  withName:(NSString *)serviceName
								  UUID:(NSString *)uuid
							 channelID:(BluetoothRFCOMMChannelID *)outChannelID
				   serviceRecordHandle:(BluetoothSDPServiceRecordHandle *)outServiceRecordHandle
{	
	if (dict == nil)
		return kIOReturnError;

	IOBluetoothSDPUUID* serviceUUID = [BBServiceAdvertiser getUUIDFromString:uuid];
	
	NSMutableDictionary *sdpEntries = [NSMutableDictionary dictionaryWithDictionary:dict];
	[BBServiceAdvertiser updateServiceDictionary:sdpEntries
										withName:serviceName
										withUUID:serviceUUID];
	
	// publish the service
	IOBluetoothSDPServiceRecordRef serviceRecordRef;
	IOReturn status = IOBluetoothAddServiceDict((CFDictionaryRef) sdpEntries, &serviceRecordRef);
	
	if (status == kIOReturnSuccess) {
		
		IOBluetoothSDPServiceRecord *serviceRecord =
			[IOBluetoothSDPServiceRecord withSDPServiceRecordRef:serviceRecordRef];
		
		// get service channel ID & service record handle
		status = [serviceRecord getRFCOMMChannelID:outChannelID];
		if (status == kIOReturnSuccess) {
			status = [serviceRecord getServiceRecordHandle:outServiceRecordHandle];
		}
		
		// cleanup
		IOBluetoothObjectRelease(serviceRecordRef);
	}
	
	return status;
}


+ (IOReturn)removeService:(BluetoothSDPServiceRecordHandle)handle
{
	return IOBluetoothRemoveServiceWithRecordHandle(handle);
}

+ (IOBluetoothSDPUUID *) getUUIDFromString: (NSString *) uuid
{
    IOBluetoothSDPUUID* serviceUUID = nil;
    
    if (uuid != nil) {
		const char* puuid = [uuid UTF8String];
		uint8 auuid[16];
		int index = 0;
		while (*puuid != '\0') {
			if (*puuid == '-') {
				++puuid;
				continue;
			}
			char p = *puuid;
			int code1 = 0;
			int code2 = 0;
            
			if (p >= 48 && p <= 57) {
				code1 = p - 48;
			} else if (p >= 65 && p <= 70) {
				code1 = p - 55;
			} else if (p >= 97 && p <= 102) {
				code1 = p - 87;
			}
            
			p = *(puuid+1);
			if (p >= 48 && p <= 57) {
				code2 = p - 48;
			} else if (p >= 65 && p <= 70) {
				code2 = p - 55;
			} else if (p >= 97 && p <= 102) {
				code2 = p - 87;
			}
            
			auuid[index++] = code1 * 16 + code2;
            
//            NSLog(@"%d: %X", index, code1*16+code2);
            
			puuid += 2;
		}
        
		serviceUUID = [IOBluetoothSDPUUID uuidWithBytes:auuid length:16];
	}
    
    return serviceUUID;
}

@end
