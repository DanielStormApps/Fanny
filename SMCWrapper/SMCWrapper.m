//
//  SMCWrapper.m
//
//  Created by Fergus Morrow on 27/09/2014
//  Licensed under the GNU General Public License.

#import "SMCWrapper.h"

@implementation SMCWrapper

// AppleSMC IOService connection
io_connect_t conn;
// Shared Instance (Singleton)
static SMCWrapper *sharedInstance = nil;

/**
 * sharedWrapper - Singleton instance retreival method.
 */
+(SMCWrapper *) sharedWrapper{
    if ( sharedInstance == nil ){
        sharedInstance = [[SMCWrapper alloc] init];
    }
    return sharedInstance;
}

/**
 * SMCOpen - Opens a connection (&conn) to the AppleSMC IOService.
 *
 * (a) Retrieve the master-port to allow RPC calls with I/O Kit.
 * (b) Attempt to get the "AppleSMC" IOService;
 *    - IOServiceMatching returns a CFMutableDictionaryRef of any matching services;
 *    - IOServiceGetMatchingServices then looks up these actual services,
 *       allowing us to iterate through them
 *    - We then connect to the first matching service (via IOSericeOpen)
 */
-(BOOL) SMCOpen{
    kern_return_t result;
    mach_port_t   masterPort;
    io_iterator_t iterator;
    io_object_t   device;
    
    // Master port allows RPC calls for user-space code to communicate with I/O kit
    result = IOMasterPort(MACH_PORT_NULL, &masterPort);
    
    // Attempt to get the AppleSMC IOService
    CFMutableDictionaryRef matchingDictionary = IOServiceMatching("AppleSMC");
    result = IOServiceGetMatchingServices(masterPort, matchingDictionary, &iterator);
    if (result != kIOReturnSuccess)
    {
        printf("Error: IOServiceGetMatchingServices() = %08x\n", result);
        return NO;
    }
    
    // Take the first item from the IOIterator as the device, and check it's valid.
    device = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (device == 0)
    {
        printf("Error: no SMC found\n");
        return NO;
    }
    
    // Open this service, saving a connection in to conn (of type io_connect_t)
    result = IOServiceOpen(device, mach_task_self(), 0, &conn);
    IOObjectRelease(device);
    if (result != kIOReturnSuccess)
    {
        printf("Error: IOServiceOpen() = %08x\n", result);
        return NO;
    }
    
    return YES;
}

/**
 * _strtoul:forSize:inBase - Takes C string (char *) and generates an Unsigned
 *  Integer (32bit) by treating each individual char as an 8bit value. Acts in
 *  the opposite to _ultostr.
 */
-(UInt32) _strtoul:(char *)str
           forSize:(int)size
            inBase:(int)base
{
    UInt32 total = 0;
    int i;
    
    for (i = 0; i < size; i++)
    {
        if (base == 16)
            total += str[i] << (size - 1 - i) * 8;
        else
            total += (unsigned char) (str[i] << (size - 1 - i) * 8);
    }
    return total;
}

/**
 * _ultostr:str:forValue - Takes a reference C string (char *) and an Unsigned
 *  Integer (32bit), and creates a string representation (char[4]) of the
 *  integer. (Essentially breaking the 32bit Integer in to an array of 4 8bit
 *  values)
 */
-(void) _ultostr:(char *)str
          forValue:(UInt32)val
{
    str[0] = '\0';
    sprintf(str, "%c%c%c%c",
            (unsigned int) val >> 24,
            (unsigned int) val >> 16,
            (unsigned int) val >> 8,
            (unsigned int) val);
}

/**
 * SMCCall:forKeyData:outputKeyDataIn - A wrapper method around
 *  IOConnectCallStructMethod - which is responsible for IOService calls.
 */
 
-(kern_return_t) SMCCall:(int)index
              forKeyData:(SMCKeyData_t *)inputStructure
         outputKeyDataIn:(SMCKeyData_t *)outputStructure
{
    size_t   structureInputSize;
    size_t   structureOutputSize;
    
    structureInputSize = sizeof(SMCKeyData_t);
    structureOutputSize = sizeof(SMCKeyData_t);
    
    return IOConnectCallStructMethod( conn, index,
                                     // inputStructure
                                     inputStructure, structureInputSize,
                                     // ouputStructure
                                     outputStructure, &structureOutputSize );
}


/**
 * SMCReadKey:outputValue - Reads an SMCKey (UInt32Char/char[5]), by
 *  populating and maintaining to SMCKeyData structures and utilising SMCCall.
 */
-(kern_return_t) SMCReadKey:(UInt32Char_t)key
                outputValue:(SMCVal_t *)val
{
    kern_return_t result;
    SMCKeyData_t  inputStructure;
    SMCKeyData_t  outputStructure;
    
    // Blank out memory allocations for our structures
    memset(&inputStructure, 0, sizeof(SMCKeyData_t));
    memset(&outputStructure, 0, sizeof(SMCKeyData_t));
    memset(val, 0, sizeof(SMCVal_t));
    
    // Populate our input structure with our key as an unsigned int (x32)
    inputStructure.key = [self _strtoul:key forSize:4 inBase:16];
    inputStructure.data8 = SMC_CMD_READ_KEYINFO;
    
    // Make our call and check the result.
    result = [self SMCCall: KERNEL_INDEX_SMC
                forKeyData: &inputStructure
           outputKeyDataIn: &outputStructure];

    
    if (result != kIOReturnSuccess){
        return result;
    }
    
    // Populate our output structure (@todo - is this needed..?
    //  dataSize is, afterall passed in by reference.)
    val->dataSize = outputStructure.keyInfo.dataSize;

    [self _ultostr: val->dataType
          forValue: outputStructure.keyInfo.dataType];
    
    // Make our second call, with SMC_CMD_READ_BYTES to get the value,
    //  and not KEYINFO this time.
    inputStructure.keyInfo.dataSize = val->dataSize;
    inputStructure.data8 = SMC_CMD_READ_BYTES;
    
    // Make a second call, this time with SMC_CMD_READ_BYTES set.
    result = [self SMCCall: KERNEL_INDEX_SMC
                forKeyData: &inputStructure
           outputKeyDataIn: &outputStructure];
    
    if (result != kIOReturnSuccess){
        return result;
    }
    
    memcpy(val->bytes, outputStructure.bytes, sizeof(outputStructure.bytes));
    return kIOReturnSuccess;
}


/**
 * readKey:intoNumber - Reads a given key from the SMC and formats the corresponding
 *  value as an NSNumber (passed by reference). Returns a BOOL indicating success.
 */
-(BOOL) readKey:(char *)key intoNumber:(NSNumber **)value{
    NSString *stringVal;
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    NSNumber *num;
    num = [NSNumber numberWithInt:0];
 
    if (! [self readKey:key asString:&stringVal] ){
        num = [NSNumber numberWithInt:0];
        *value = num;
        return NO;
    }
    
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    num = [f numberFromString:stringVal];
    *value = num;
    return YES;
}


/**
 * readKey:asString - Reads a given key from the SMC and formats the corresponding
 *  value as an NSString (passed by reference). Returns a BOOL indicating success.
 */
-(BOOL) readKey:(char *)key asString:(NSString **)str{
    char cStr[16];   // Something has gone majorly wrong if it's over 15 digits long.
    SMCVal_t val;
    kern_return_t result;
    
    result = [self SMCReadKey: key
                  outputValue: &val];
    
    // Do value checking on val.
    if (result != kIOReturnSuccess) {
        *str = [[NSString alloc] initWithFormat:@""];
        return NO;
    }
    
    // Mac OS X means rubbish FourCC style data type referencing
    [self getStringRepresentation: val.bytes
                          forSize: val.dataSize
                           ofType: val.dataType
                         inBuffer: &cStr[0]];
    
    *str = [[NSString alloc] initWithCString:cStr encoding:NSUTF8StringEncoding];
    return YES;
}


/**
 * SMCClose - Close our connection to the AppleSMC IOService.
 */
-(void) SMCClose{
    IOServiceClose(conn);
}


/**
 * getStringRepresentation:forSize:ofType:inBuffer - Retrieves a C string
 *  representation of the value.
 */
-(void) getStringRepresentation: (SMCBytes_t)bytes
                          forSize: (UInt32)dataSize
                           ofType: (UInt32Char_t)dataType
                         inBuffer: (char *)str
{
    if ((strcmp(dataType, DATATYPE_UINT8) == 0) ||
        (strcmp(dataType, DATATYPE_UINT16) == 0) ||
        (strcmp(dataType, DATATYPE_UINT32) == 0))
        snprintf(str, 15, "%u ", (unsigned int) [self _strtoul:bytes forSize:dataSize inBase:10]);
    else if (strcmp(dataType, DATATYPE_FP1F) == 0 && dataSize == 2)
        snprintf(str, 15, "%.5f ", ntohs(*(UInt16*)bytes) / 32768.0);
    else if (strcmp(dataType, DATATYPE_FP4C) == 0 && dataSize == 2)
        snprintf(str, 15, "%.5f ", ntohs(*(UInt16*)bytes) / 4096.0);
    else if (strcmp(dataType, DATATYPE_FP5B) == 0 && dataSize == 2)
        snprintf(str, 15, "%.5f ", ntohs(*(UInt16*)bytes) / 2048.0);
    else if (strcmp(dataType, DATATYPE_FP6A) == 0 && dataSize == 2)
        snprintf(str, 15, "%.4f ", ntohs(*(UInt16*)bytes) / 1024.0);
    else if (strcmp(dataType, DATATYPE_FP79) == 0 && dataSize == 2)
        snprintf(str, 15, "%.4f ", ntohs(*(UInt16*)bytes) / 512.0);
    else if (strcmp(dataType, DATATYPE_FP88) == 0 && dataSize == 2)
        snprintf(str, 15, "%.3f ", ntohs(*(UInt16*)bytes) / 256.0);
    else if (strcmp(dataType, DATATYPE_FPA6) == 0 && dataSize == 2)
        snprintf(str, 15, "%.2f ", ntohs(*(UInt16*)bytes) / 64.0);
    else if (strcmp(dataType, DATATYPE_FPC4) == 0 && dataSize == 2)
        snprintf(str, 15, "%.2f ", ntohs(*(UInt16*)bytes) / 16.0);
    else if (strcmp(dataType, DATATYPE_FPE2) == 0 && dataSize == 2)
        snprintf(str, 15, "%.2f ", ntohs(*(UInt16*)bytes) / 4.0);
    else if (strcmp(dataType, DATATYPE_SP1E) == 0 && dataSize == 2)
        snprintf(str, 15, "%.5f ", ((SInt16)ntohs(*(UInt16*)bytes)) / 16384.0);
    else if (strcmp(dataType, DATATYPE_SP3C) == 0 && dataSize == 2)
        snprintf(str, 15, "%.5f ", ((SInt16)ntohs(*(UInt16*)bytes)) / 4096.0);
    else if (strcmp(dataType, DATATYPE_SP4B) == 0 && dataSize == 2)
        snprintf(str, 15, "%.4f ", ((SInt16)ntohs(*(UInt16*)bytes)) / 2048.0);
    else if (strcmp(dataType, DATATYPE_SP5A) == 0 && dataSize == 2)
        snprintf(str, 15, "%.4f ", ((SInt16)ntohs(*(UInt16*)bytes)) / 1024.0);
    else if (strcmp(dataType, DATATYPE_SP69) == 0 && dataSize == 2)
        snprintf(str, 15, "%.3f ", ((SInt16)ntohs(*(UInt16*)bytes)) / 512.0);
    else if (strcmp(dataType, DATATYPE_SP78) == 0 && dataSize == 2)
        snprintf(str, 15, "%.3f ", ((SInt16)ntohs(*(UInt16*)bytes)) / 256.0);
    else if (strcmp(dataType, DATATYPE_SP87) == 0 && dataSize == 2)
        snprintf(str, 15, "%.3f ", ((SInt16)ntohs(*(UInt16*)bytes)) / 128.0);
    else if (strcmp(dataType, DATATYPE_SP96) == 0 && dataSize == 2)
        snprintf(str, 15, "%.2f ", ((SInt16)ntohs(*(UInt16*)bytes)) / 64.0);
    else if (strcmp(dataType, DATATYPE_SPB4) == 0 && dataSize == 2)
        snprintf(str, 15, "%.2f ", ((SInt16)ntohs(*(UInt16*)bytes)) / 16.0);
    else if (strcmp(dataType, DATATYPE_SPF0) == 0 && dataSize == 2)
        snprintf(str, 15, "%.0f ", (float)ntohs(*(UInt16*)bytes));
    else if (strcmp(dataType, DATATYPE_SI16) == 0 && dataSize == 2)
        snprintf(str, 15, "%d ", ntohs(*(SInt16*)bytes));
    else if (strcmp(dataType, DATATYPE_SI8) == 0 && dataSize == 1)
        snprintf(str, 15, "%d ", (signed char)*bytes);
    else if (strcmp(dataType, DATATYPE_PWM) == 0 && dataSize == 2)
        snprintf(str, 15, "%.1f%% ", ntohs(*(UInt16*)bytes) * 100 / 65536.0);
}


-(id) init{
    if (self = [super init]){
        if (![self SMCOpen]){
            NSLog(@"Unable to open SMC.");
        }
    }
    return self;
}

-(void) dealloc{
    [self SMCClose];
}

@end
