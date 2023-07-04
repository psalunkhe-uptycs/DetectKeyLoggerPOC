//
//  EventTaps.m
//  DetectKeylogger
//
//  Created by Pritam Salunkhe on 04/07/23.
//

#import "EventTaps.h"
#import <notify.h>
#import <libproc.h>
#import <sys/sysctl.h>
#import <CoreGraphics/CoreGraphics.h>

@implementation EventTaps

@synthesize previousTaps;

//get process's path
NSString* getProcessPath(pid_t pid)
{
    //task path
    NSString* processPath = nil;
    
    //buffer for process path
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //status
    int status = -1;
    
    //'management info base' array
    int mib[3] = {0};
    
    //system's size for max args
    unsigned long systemMaxArgs = 0;
    
    //process's args
    char* taskArgs = NULL;
    
    //# of args
    int numberOfArgs = 0;
    
    //size of buffers, etc
    size_t size = 0;
    
    //reset buffer
    memset(pathBuffer, 0x0, PROC_PIDPATHINFO_MAXSIZE);
    
    //first attempt to get path via 'proc_pidpath()'
    status = proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    if(0 != status)
    {
        //init task's name
        processPath = [NSString stringWithUTF8String:pathBuffer];
    }
    //otherwise
    // try via task's args ('KERN_PROCARGS2')
    else
    {
        //init mib
        // ->want system's size for max args
        mib[0] = CTL_KERN;
        mib[1] = KERN_ARGMAX;
        
        //set size
        size = sizeof(systemMaxArgs);
        
        //get system's size for max args
        if(-1 == sysctl(mib, 2, &systemMaxArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //alloc space for args
        taskArgs = malloc(systemMaxArgs);
        if(NULL == taskArgs)
        {
            //bail
            goto bail;
        }
        
        //init mib
        // ->want process args
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROCARGS2;
        mib[2] = pid;
        
        //set size
        size = (size_t)systemMaxArgs;
        
        //get process's args
        if(-1 == sysctl(mib, 3, taskArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //sanity check
        // ensure buffer is somewhat sane
        if(size <= sizeof(int))
        {
            //bail
            goto bail;
        }
        
        //extract number of args
        memcpy(&numberOfArgs, taskArgs, sizeof(numberOfArgs));
        
        //extract task's name
        // follows # of args (int) and is NULL-terminated
        processPath = [NSString stringWithUTF8String:taskArgs + sizeof(int)];
    }
    
bail:
    
    //free process args
    if(NULL != taskArgs)
    {
        //free
        free(taskArgs);
        
        //reset
        taskArgs = NULL;
    }
    
    return processPath;
}

//enumerate event taps
// activated keyboard taps
-(NSMutableDictionary*)enumerate
{
    //keyboard taps
    NSMutableDictionary* keyboardTaps = nil;
    
    //event taps
    uint32_t eventTapCount = 0;
    
    //taps
    CGEventTapInformation *taps = NULL;
    
    //current tap
    CGEventTapInformation tap = {0};
    
    //tapping process
    NSString* sourcePath = nil;
    
    //target process
    NSString* destinationPath = nil;
    
    //options (type)
    NSString* options = nil;
    
    //alloc
    keyboardTaps = [NSMutableDictionary dictionary];
    
    //get number of existing taps
    if( (kCGErrorSuccess != CGGetEventTapList(0, NULL, &eventTapCount)) ||
        (0 == eventTapCount) )
    {
        //bail
        goto bail;
    }
    
    //alloc
    taps = malloc(sizeof(CGEventTapInformation) * eventTapCount);
    if(NULL == taps)
    {
        //bail
        goto bail;
    }
    
    //get all taps
    if(kCGErrorSuccess != CGGetEventTapList(eventTapCount, taps, &eventTapCount))
    {
        //bail
        goto bail;
    }
    
    //iterate/process all taps
    for(int i=0; i<eventTapCount; i++)
    {
        //current tap
        tap = taps[i];
        
        //ignore disabled taps
        if(true != tap.enabled)
        {
            //skip
            continue;
        }
        
        //skip non-keyboard taps
        if( ((CGEventMaskBit(kCGEventKeyUp) & tap.eventsOfInterest) != CGEventMaskBit(kCGEventKeyUp)) &&
           ((CGEventMaskBit(kCGEventKeyDown) & tap.eventsOfInterest) != CGEventMaskBit(kCGEventKeyDown)) )
        {
            //skip
            continue;
        }
        
        //get path to tapping process
        sourcePath = getProcessPath(tap.tappingProcess);
        if(0 == sourcePath.length)
        {
            //default
            sourcePath = @"<unknown>";
        }
        
        NSLog(@"Process Found: %@\n", sourcePath);
        
        //        //when target is 0
        //        // means all/system-wide
        //        if(0 == tap.processBeingTapped)
        //        {
        //            //set
        //            destinationPath = GLOBAL_EVENT_TAP;
        //        }
        //        //specific target
        //        // get path for target process
        //        else
        //        {
        //            //get path to target process
        //            destinationPath = getProcessPath(tap.processBeingTapped);
        //            if(0 == destinationPath.length)
        //            {
        //                //default
        //                destinationPath = @"<unknown>";
        //            }
        //        }
        //
        //        //set option
        //        switch (tap.options)
        //        {
        //            //filter
        //            case kCGEventTapOptionDefault:
        //                options = @"Active filter";
        //                break;
        //
        //            //listener
        //            case kCGEventTapOptionListenOnly:
        //                options = @"Passive listener";
        //                break;
        //
        //            //unknown
        //            default:
        //                options = @"<unknown>";
        //                break;
        //        }
        //
        //        //add
        //keyboardTaps[@(tap.eventTapID)] = @{TAP_ID:@(tap.eventTapID), TAP_OPTIONS:options, TAP_SOURCE_PATH:sourcePath, TAP_SOURCE_PID:@(tap.tappingProcess), TAP_DESTINATION_PATH:destinationPath, TAP_DESTINATION_PID:@(tap.processBeingTapped)};
        //    }
    }
    
bail:
    
    //free taps
    if(NULL != taps)
    {
        //free
        free(taps);
        taps = NULL;
    }
    
    return keyboardTaps;
}

//listen for new taps
// note: method doesn't return!
-(void)observe:(TapCallbackBlock)callback;
{
    //token
    int notifyToken = NOTIFY_TOKEN_INVALID;
    
    //current taps
    // ...that include any news ones
    __block NSMutableDictionary* currentTaps = nil;
    
    //signing info
    __block NSMutableDictionary* signingInfo = nil;
    
    //grab existing taps
    self.previousTaps = [self enumerate];
    
    //register 'kCGNotifyEventTapAdded' notification
    notify_register_dispatch(kCGNotifyEventTapAdded, &notifyToken, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(int token) {
        
        //sync to assure thread safety
        @synchronized(self)
        {
            //grab current taps
            // ...should now include any new ones
            currentTaps = [self enumerate];
            
            //identify any new taps
            // invoke callback for those...
            for(NSNumber* tapID in currentTaps.allKeys)
            {
                //not new?
                if(nil != self.previousTaps[tapID])
                {
                    //skip
                    continue;
                }
                
                //dbg msg
                //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"kCGNotifyEventTapAdded fired (new tap: %@)", currentTaps[tapID]]);
                
                //ignore taps from vmware
                // it creates a temporary event tap while one interacts with a VM
//                if(YES == [[currentTaps[tapID][TAP_SOURCE_PATH] lastPathComponent] isEqualToString:@"vmware-vmx"])
//                {
//                    //generate signing info
//                    // and make sure its vmware
//                    signingInfo = extractSigningInfo([currentTaps[tapID][TAP_SOURCE_PID] intValue], nil, kSecCSDefaultFlags);
//                    if( (nil != signingInfo) &&
//                        (noErr == [signingInfo[KEY_SIGNATURE_STATUS] intValue]) &&
//                        (DevID == [signingInfo[KEY_SIGNATURE_SIGNER] intValue]) &&
//                        (YES == [signingInfo[KEY_SIGNATURE_IDENTIFIER] isEqualToString:@"com.vmware.vmware-vmx"]) )
//                    {
//                        //dbg msg
//                        logMsg(LOG_DEBUG, @"ingoring alert: 'com.vmware.vmware-vmx'");
//
//                        //skip
//                        continue;
//                    }
//                }

                //just nap a bit
                // some notifications seem temporary
//                else
//                {
//                    //wait a few seconds and recheck
//                    // some notifications seem temporary (i.e. vmware)
//                    [NSThread sleepForTimeInterval:1.0f];
//                }
                
                //(re)enumerate
                // ignore if the tap went away
                if(YES != [[[self enumerate] allKeys] containsObject:tapID])
                {
                    //dbg msg
                    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"tap %@, was temporary, so ignoring", currentTaps[tapID]]);
                    NSLog(@"tap %@, was temporary, so ignoring", currentTaps[tapID]);
                    //skip
                    continue;
                }
                
                //new
                // and not temporary...
                callback(currentTaps[tapID]);
            
            }//all taps
            
            //update taps
            self.previousTaps = currentTaps;
        
        } //sync
    
    });

    //run loop
    [[NSRunLoop currentRunLoop] run];
    
    return;
}

@end
