//
//  vcOcrView.h
//  VCOCR
//
//  Created by ivic-flm on 2020/5/13.
//  Copyright © 2020 ivic-flm. All rights reserved.
//

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#endif
#ifdef __OBJC__
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>
#endif

NS_ASSUME_NONNULL_BEGIN
/*
 index
 0.扫描二维码
 1.确认
 */
typedef void(^ResultCallBack)(NSString *reuslt, NSInteger index);
@interface vcOcrView : UIView
@property (nonatomic, assign) BOOL capture;
@property (nonatomic, assign) CGRect imgRect;
@property (nonatomic, assign) CGRect pathRect;
- (void)setup;
- (void)start;
- (void)stop;
- (void)foucePixel;
- (void)foucePixelCancle;
@property(nonatomic, copy) ResultCallBack resultCB;
@end

NS_ASSUME_NONNULL_END
