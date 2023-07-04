//
//  main.m
//  DetectKeylogger
//
//  Created by Pritam Salunkhe on 04/07/23.
//
#import "EventTaps.h"
#import <Foundation/Foundation.h>

//tap id
#define TAP_ID @"tapID"
//tap options
#define TAP_OPTIONS @"tapOptions"

//tap source path
#define TAP_SOURCE_PATH @"sourcePath"

//tap source pid
#define TAP_SOURCE_PID @"sourcePID"

//tap destination path
#define TAP_DESTINATION_PATH @"destinationPath"

//tap destination pid
#define TAP_DESTINATION_PID @"destinationPID"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        //event taps
        NSMutableArray* eventTaps = nil;
        
        //current tap
        //NSDictionary* eventTap = nil;
        
        //signing info
        //NSDictionary* signingInfo = nil;
        
        //output
        NSMutableString* output = nil;
        
        //scan
        eventTaps = [[[[[EventTaps alloc] init] enumerate] allValues] mutableCopy];
        
        //init output string
        output = [NSMutableString string];
        
        //start JSON
        [output appendString:@"["];
        
        //add each tap
        for(NSDictionary* eventTap in eventTaps)
        {
            [output appendFormat:@"{\"%@\": \"%@\", \"%@\": \"%@\", \"%@\": \"%@\", \"%@\": \"%@\", \"%@\": \"%@\"},", TAP_ID, eventTap[TAP_ID], TAP_SOURCE_PID, eventTap[TAP_SOURCE_PID], TAP_SOURCE_PATH, eventTap[TAP_SOURCE_PATH], TAP_DESTINATION_PID, eventTap[TAP_DESTINATION_PID], TAP_DESTINATION_PATH, eventTap[TAP_DESTINATION_PATH]];
        }
        
        //remove last ','
        if(YES == [output hasSuffix:@","])
        {
            //remove
            [output deleteCharactersInRange:NSMakeRange([output length]-1, 1)];
        }
        
        //terminate list
        [output appendString:@"]"];
        
        //pretty print?
        
    }
    return 0;
}
