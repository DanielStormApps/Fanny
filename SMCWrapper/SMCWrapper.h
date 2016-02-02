//
//  SMCWrapper.m
//  SMCInfo
//
//  Created by Fergus Morrow on 27/09/2014, based on work by Apple Corp.
//  Licensed under the GNU General Public License.

#import <stdio.h>
#import <string.h>
#import <IOKit/IOKitLib.h>
#import <Foundation/Foundation.h>
#import "smc.h"

@interface SMCWrapper : NSObject

+(SMCWrapper *)sharedWrapper;

// IOService Methods.
-(BOOL) SMCOpen;
-(void) SMCClose;

// SMC RPC Wrappers.
-(kern_return_t) SMCReadKey:(UInt32Char_t)key
                outputValue:(SMCVal_t *)val;

-(kern_return_t) SMCCall:(int)index
              forKeyData:(SMCKeyData_t *)inputStructure
         outputKeyDataIn:(SMCKeyData_t *)outputStructure;

// String<->Unsigned Integer Helper Methods.
-(void) _ultostr:(char *)str
          forValue:(UInt32)val;

-(UInt32) _strtoul:(char *)str
           forSize:(int)size
            inBase:(int)base;

// Gets a string representation for a given SMCKeyData_t struct.
-(void) getStringRepresentation: (SMCBytes_t)bytes
                        forSize: (UInt32)dataSize
                         ofType: (UInt32Char_t)dataType
                       inBuffer: (char *)str;

// "Public" methods; i.e the only real methods used externally.
-(BOOL) readKey:(char *)key intoNumber:(NSNumber **)value;
-(BOOL) readKey:(char *)key asString:(NSString **)str;


@end
