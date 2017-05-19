//
//  ViewController.m
//  decodeH264
//
//  Created by wutaotao on 2017/5/19.
//  Copyright © 2017年 wutaotao. All rights reserved.
//

#import "ViewController.h"
#import "LYOpenGLView.h"
#import <VideoToolbox/VideoToolbox.h>


@interface ViewController ()

@property (nonatomic,strong) LYOpenGLView *mopenGLView;
@property (nonatomic,strong) UILabel *mlabel;
@property (nonatomic,strong) UIButton *mButton;
@property (nonatomic,strong) CADisplayLink *mDisplayLink;

@end

const uint8_t lyStartCode[4] = {0,0,0,1};

@implementation ViewController{
    
    dispatch_queue_t mDecodeQueue;
    VTDecompressionSessionRef mDecodeSession;
    CMFormatDescriptionRef mFormatDescription;
    uint8_t *mSPS;
    long mSPSSize;
    uint8_t *mPPS;
    long mPPSSize;
    
    //输入
    NSInputStream *inputStream;
    uint8_t * packetBuffer;
    long packetSize;
    uint8_t * inputBuffer;
    long inputSize;
    long inputMaxSize;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mopenGLView = (LYOpenGLView *)self.view;
    [self.mopenGLView setupGL];
    
    mDecodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    self.mlabel = [[UILabel alloc]initWithFrame:CGRectMake(20, 20, 200, 100)];
    self.mlabel.textColor = [UIColor redColor];
    [self.view addSubview:self.mlabel];
    self.mlabel.text = @"测试H264硬解码";
    
    UIButton *button = [[UIButton alloc]initWithFrame:CGRectMake(200, 20, 100, 100)];
    [button setTitle:@"play" forState:UIControlStateNormal];
    
    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:button];
    [button addTarget:self action:@selector(onClick:) forControlEvents:UIControlEventTouchUpInside];
    self.mButton = button;
    
    self.mDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
    self.mDisplayLink.frameInterval = 2;
    [self.mDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.mDisplayLink setPaused:YES];
    
}

-(void)onClick:(UIButton *)button {
    button.hidden = YES;
    [self startDecode];
}
-(void)onInputStart{
    inputStream = [[NSInputStream alloc]initWithFileAtPath:[[NSBundle mainBundle] pathForResource:@"abc" ofType:@"h264"]];
    [inputStream open];
    inputSize = 0;
    inputMaxSize = 640 * 480 *3 *4;
    inputBuffer = malloc(inputMaxSize);
}

-(void)onInputEnd {
    [inputStream close];
    inputStream = nil;
    if (inputBuffer) {
        free(inputBuffer);
        inputBuffer = NULL;
    }
    
    [self.mDisplayLink setPaused:YES];
    self.mButton.hidden = NO;
}

-(void)readPacket{
    
    if (packetSize && packetBuffer) {
        packetSize = 0;
        free(packetBuffer);
        packetBuffer = NULL;
    }
    
    if (inputSize < inputMaxSize && inputStream.hasBytesAvailable) {
        inputSize += [inputStream read:inputBuffer + inputSize maxLength:inputMaxSize - inputSize];
    }
    
    if (memcmp(inputBuffer, lyStartCode, 4) == 0) {
        if (inputSize > 4) {
            uint8_t *pStart = inputBuffer + 4;
            uint8_t *pEnd = inputBuffer + inputSize;
            while (pStart != pEnd) {
                
                if (memcmp(pStart - 3, lyStartCode, 4) == 0) {
                    packetSize = pStart - inputBuffer - 3;
                    
                    if (packetBuffer) {
                        free(packetBuffer);
                        packetBuffer = NULL;
                    }
                    packetBuffer = malloc(packetSize);
                    memcpy(packetBuffer, inputBuffer, packetSize);
                    memmove(inputBuffer, inputBuffer + packetSize, inputSize - packetSize);
                    inputSize -= packetSize;
                    break;
                }else{
                    ++pStart;
                }
 
            }
 
        }
 
    }

}

void didDecompress(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
}

-(void)startDecode{
    [self onInputStart];
    [self.mDisplayLink setPaused:NO];
}

-(void)updateFrame{
    if (inputStream) {
        dispatch_sync(mDecodeQueue, ^{
            [self readPacket];
            
            if (packetBuffer == NULL || packetSize == 0) {
                [self onInputEnd];
                return ;
            }
            
            uint32_t nalSize = (uint32_t)(packetSize - 4);
            uint32_t *pNalSize = (uint32_t *)packetBuffer;
            *pNalSize = CFSwapInt32HostToBig(nalSize);
            
            CVPixelBufferRef pixelbuffer = NULL;
            int naltype = packetBuffer[4] & 0x1F;
            switch (naltype) {
                case 0x05:
                    [self initVideoToolBox];
                    pixelbuffer = [self decode];
                    break;
                case 0x07:
                    mSPSSize = packetSize - 4;
                    mSPS = malloc(mSPSSize);
                    memcpy(mSPS, packetBuffer + 4, mSPSSize);
                    
                    break;
                case 0x08:
                    NSLog(@"Nal type is PPS");
                    mPPSSize = packetSize - 4;
                    mPPS = malloc(mPPSSize);
                    memcpy(mPPS, packetBuffer + 4, mPPSSize);
                    
                    break;
                    
                default:
                    NSLog(@"Nal type is B/P frame");
                    pixelbuffer = [self decode];
                    break;
            }
            
            if (pixelbuffer) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.mopenGLView displayPixelBuffer:pixelbuffer];
                    CVPixelBufferRelease(pixelbuffer);
                });
            }
            NSLog(@"read Nalu size %ld", packetSize);
            
        });
 
    }
  
}

-(CVPixelBufferRef)decode{
    CVPixelBufferRef outputPixelBuffer = NULL;
    if (mDecodeSession) {
        CMBlockBufferRef blockBuffer = NULL;
        
        OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, (void *)packetBuffer, packetSize, kCFAllocatorNull, NULL, 0, packetSize, 0, &blockBuffer);
        if (status == kCMBlockBufferNoErr) {
            CMSampleBufferRef samplebuffer = NULL;
            const size_t sampleSizeArray[] = {packetSize};
            status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, mFormatDescription, 1, 0, NULL, 1, sampleSizeArray, &samplebuffer);
            
            if (status == kCMBlockBufferNoErr && samplebuffer) {
                VTDecodeFrameFlags flags = 0;
                VTDecodeInfoFlags flagout = 0;
                
                OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(mDecodeSession, samplebuffer, flags, &outputPixelBuffer, &flagout);
                
                if (decodeStatus == kVTInvalidSessionErr) {
                    NSLog(@"IOS8VT : Invalid ");
                }else if (decodeStatus == kVTVideoDecoderBadDataErr){
                      NSLog(@"IOS8VT: decode failed status=%d(Bad data)", decodeStatus);
                }else if (decodeStatus != noErr){
                     NSLog(@"IOS8VT: decode failed status=%d", decodeStatus);
                }
                
                CFRelease(samplebuffer);
            }
            
            CFRelease(blockBuffer);
            
        }
  
    }
    
    return outputPixelBuffer;
}

-(void)initVideoToolBox{
    
    if (!mDecodeSession) {
        const uint8_t * parameterSetPointers[2] = {mSPS , mPPS};
        const size_t parameterSetSizes[2] = {mSPSSize,mPPSSize};
        
        OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &mFormatDescription);
        
        if (status == noErr) {
            CFDictionaryRef attrs = NULL;
            const void *keys[] = {kCVPixelBufferPixelFormatTypeKey};
            uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
            const void *values[] = {CFNumberCreate(NULL, kCFNumberSInt32Type, &v)};
            attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
            VTDecompressionOutputCallbackRecord callBackRecord;
            callBackRecord.decompressionOutputCallback = didDecompress;
            callBackRecord.decompressionOutputRefCon = NULL;
            status = VTDecompressionSessionCreate(kCFAllocatorDefault, mFormatDescription, NULL, attrs, &callBackRecord, &mDecodeSession);
            CFRelease(attrs);
            
            
        }else{
            NSLog(@"IOS8VT : reset decoder session failed status=%d",status);
        }
  
    }
   
}

-(void)EndVideoToolBox{
    
    if (mDecodeSession) {
        VTDecompressionSessionInvalidate(mDecodeSession);
        CFRelease(mDecodeSession);
        mDecodeSession = NULL;
    }
    
    if (mFormatDescription) {
        CFRelease(mFormatDescription);
        mFormatDescription = NULL;
    }
    
    free(mSPS);
    free(mPPS);
    mSPSSize = mPPSSize = 0;
}



@end






























