//
//  vcOcrView.m
//  VCOCR
//
//  Created by ivic-flm on 2020/5/13.
//  Copyright © 2020 ivic-flm. All rights reserved.
//

#import "vcOcrView.h"
#import <AVFoundation/AVFoundation.h>
#import "Utility.h"
#import "Pipeline.h"
//屏幕的宽、高
#define kScreenWidth  [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height
@interface vcOcrView()<AVCaptureVideoDataOutputSampleBufferDelegate>{
    AVCaptureSession *_session;
    AVCaptureDeviceInput *_captureInput;
    AVCaptureVideoPreviewLayer *_preview;
    AVCaptureDevice *_device;
    
    NSTimer *_timer; //定时器
    BOOL _on; //闪光灯状态
    BOOL _isFoucePixel;//是否相位对焦
    BOOL _isScan;//是否扫描
    int _count;//每几帧识别
    CGFloat _isLensChanged;//镜头位置
    UIButton *rightBtn;//右边按钮
    UIButton *leftBtn;//左边按钮
    UIButton *codeBtn;//左边按钮
    UIButton *lightBtn;//左边按钮
    UILabel *codeLabel;
    UILabel *lightLabel;
    /*相位聚焦下镜头位置 镜头晃动 值不停的改变 */
    CGFloat _isIOS8AndFoucePixelLensPosition;
    
    /*
     控制识别速度，最小值为1！数值越大识别越慢。
     相机初始化时，设置默认值为1（不要改动），判断设备若为相位对焦时，设置此值为2（可以修改，最小为1，越大越慢）
     此值的功能是为了减小相位对焦下，因识别速度过快
     此值在相机初始化中设置，在相机代理中使用，用户若无特殊需求不用修改。
     */
    int _MaxFR;
    
    cv::Mat source_image;
}
@property (assign, nonatomic) BOOL adjustingFocus;
@property (nonatomic, retain) CALayer *customLayer;
@property (nonatomic,assign) BOOL isProcessingImage;

@property (nonatomic, strong) UIImage* image;
@property (nonatomic, strong) UIImage* cImage;
@property (nonatomic, strong) UIImageView *showImageView;
@property (nonatomic, strong) UILabel *resultLabel;
@property (nonatomic, strong) NSString *resulttext;
@end

@implementation vcOcrView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
//        [self setup];
    }
    return self;
}

- (void)setup {
    //初始化相机
    [self initialize];
    //创建相机界面控件
    [self createCameraView];
}

//初始化相机
- (void)initialize {
    _isScan = YES;
    //判断摄像头授权
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied){
        [self showInfo];
        return;
    }
    
//    _MaxFR = 1;
    //1.创建会话层
    _session = [[AVCaptureSession alloc] init];
    [_session setSessionPreset:AVCaptureSessionPreset1920x1080];
    
    //2.创建、配置输入设备
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *inputError = nil;
    _captureInput = [AVCaptureDeviceInput deviceInputWithDevice:_device error:&inputError];
    [_session addInput:_captureInput];
    
    //2.创建视频流输出
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    dispatch_queue_t queue;
    queue = dispatch_queue_create("cameraQueue", NULL);
    [captureOutput setSampleBufferDelegate:self queue:queue];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    
    [_session addOutput:captureOutput];
    //3.预览图层
    _preview = [AVCaptureVideoPreviewLayer layerWithSession: _session];
    _preview.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    _preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer addSublayer:_preview];
    self.backgroundColor = [UIColor blueColor];
    //判断是否相位对焦
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
        AVCaptureDeviceFormat *deviceFormat = _device.activeFormat;
        if (deviceFormat.autoFocusSystem == AVCaptureAutoFocusSystemPhaseDetection){
            _isFoucePixel = YES;
            _MaxFR = 2;
        }
    }
}

- (void)createCameraView
{
    // 创建一个全屏大的path
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:self.bounds];
    // 创建一个矩形path
    UIBezierPath *circlePath = [UIBezierPath bezierPathWithRect:_pathRect];
    
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    
    [path appendPath:circlePath];
    [path setUsesEvenOddFillRule:YES];
    shapeLayer.path = path.CGPath;
    shapeLayer.fillRule = kCAFillRuleEvenOdd;
    shapeLayer.fillColor = [UIColor blackColor].CGColor;
    shapeLayer.opacity = 0.3;
    
    [self.layer addSublayer:shapeLayer];
    
    /* 相机按钮 适配了iPhone和ipad 不同需求自行修改界面*/
    //返回、闪光灯按钮
    CGFloat backWidth = 35;
    if (kScreenHeight>=1024) {
        backWidth = 50;
    }
    CGFloat s = 80;
    CGFloat s1 = 0;
    if (kScreenHeight==480) {
        s = 60;
        s1 = 10;
    }
    
    UIView *shadowView = [[UIView alloc] init];
    shadowView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    shadowView.frame = CGRectMake(0, kScreenHeight-153, kScreenWidth, 153);
    [self addSubview:shadowView];
    leftBtn = [[UIButton alloc]initWithFrame:CGRectMake((kScreenWidth-100-112)/2,49, 56, 56)];
    [leftBtn addTarget:self action:@selector(backAction) forControlEvents:UIControlEventTouchUpInside];
    [leftBtn setImage:[UIImage imageNamed:@"ic_car_camera_capture_photo2"] forState:UIControlStateNormal];
    [leftBtn setImageEdgeInsets:UIEdgeInsetsMake(15, 15, 15, 15)];
    leftBtn.titleLabel.textAlignment = NSTextAlignmentLeft;
    [leftBtn setTintColor:[UIColor blackColor]];
    [leftBtn setBackgroundColor:[UIColor whiteColor]];
    leftBtn.layer.cornerRadius = 28;
    [shadowView addSubview:leftBtn];
    leftBtn.hidden = YES;
    rightBtn = [[UIButton alloc]initWithFrame:CGRectMake(leftBtn.frame.origin.x+156,49, 56, 56)];
    [rightBtn setImage:[UIImage imageNamed:@"ic_car_camera_capture_photo_ok"] forState:UIControlStateNormal];
    [rightBtn addTarget:self action:@selector(rightClick) forControlEvents:UIControlEventTouchUpInside];
    [rightBtn setTintColor:[UIColor blackColor]];
    [rightBtn setImageEdgeInsets:UIEdgeInsetsMake(15, 15, 15, 15)];
    [shadowView addSubview:rightBtn];
    [rightBtn setBackgroundColor:[UIColor whiteColor]];
    rightBtn.layer.cornerRadius = 28;
    rightBtn.hidden = YES;
    _showImageView = [[UIImageView alloc] init];
    _showImageView.frame = CGRectMake(kScreenWidth * 0.2, 160 , kScreenWidth * 0.6, 80);
    [self addSubview:_showImageView];
    _showImageView.hidden = YES;
    
    //二维码
    codeBtn = [[UIButton alloc]initWithFrame:CGRectMake((kScreenWidth-100-112)/2,35, 56, 56)];
    [codeBtn addTarget:self action:@selector(codeAction) forControlEvents:UIControlEventTouchUpInside];
    [codeBtn setImage:[UIImage imageNamed:@"ocrscan"] forState:UIControlStateNormal];
    [shadowView addSubview:codeBtn];
    codeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 20)];
    codeLabel.center = CGPointMake(codeBtn.center.x, codeBtn.center.y+45);
    codeLabel.text = @"扫描二维码";
    codeLabel.textColor = [UIColor whiteColor];
    codeLabel.font = [UIFont systemFontOfSize:13];
    codeLabel.textAlignment = NSTextAlignmentCenter;
    [shadowView addSubview:codeLabel];
    
    //手电筒
    lightBtn = [[UIButton alloc]initWithFrame:CGRectMake(codeBtn.frame.origin.x+156,35, 56, 56)];
    [lightBtn setImage:[UIImage imageNamed:@"vcsdt"] forState:UIControlStateNormal];
    [lightBtn addTarget:self action:@selector(lightClick) forControlEvents:UIControlEventTouchUpInside];
    [shadowView addSubview:lightBtn];
    lightLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 20)];
    lightLabel.center = CGPointMake(lightBtn.center.x, lightBtn.center.y+45);
    lightLabel.text = @"打开手电筒";
    lightLabel.textColor = [UIColor whiteColor];
    lightLabel.font = [UIFont systemFontOfSize:13];
    lightLabel.textAlignment = NSTextAlignmentCenter;
    [shadowView addSubview:lightLabel];
    
    _resultLabel = [[UILabel alloc] initWithFrame:CGRectMake((kScreenWidth-100)/2, 255, 100, 20)];
    _resultLabel.textColor = [UIColor whiteColor];
    _resultLabel.textAlignment = NSTextAlignmentCenter;
    _resultLabel.font = [UIFont boldSystemFontOfSize:18];
    _resultLabel.hidden = YES;
    _resultLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    [self addSubview:_resultLabel];
}

- (void)codeAction {
    if (self.resultCB) {
        self.resultCB(@"", 0);
    }
}

- (void)lightClick {
    if (![_device hasTorch]) {
        //NSLog(@"no torch");
    } else {
        [_device lockForConfiguration:nil];
        if (!_on) {
            [_device setTorchMode: AVCaptureTorchModeOn];
            _on = YES;
        }else{
            [_device setTorchMode: AVCaptureTorchModeOff];
            _on = NO;
        }
        [_device unlockForConfiguration];
    }
}

- (void)hiddenChild:(BOOL)hidden {
    _showImageView.hidden = hidden;
    _resultLabel.hidden = hidden;
    leftBtn.hidden = hidden;
    rightBtn.hidden = hidden;
    codeBtn.hidden = !hidden;
    lightBtn.hidden = !hidden;
    codeLabel.hidden = !hidden;
    lightLabel.hidden = !hidden;
}

- (void)backAction {
    [self hiddenChild:YES];
    _isScan = YES;
}

- (void)rightClick {
    if (self.resultCB) {
        self.resultCB(_resulttext, 1);
    }
}

- (void)start {
    [_session startRunning];
}

- (void)stop {
    [_session stopRunning];
}

- (void)foucePixel {
    _capture = NO;
    [self performSelector:@selector(changeCapture) withObject:nil afterDelay:0.4];
    //不支持相位对焦情况下(iPhone6以后的手机支持相位对焦) 设置定时器 开启连续对焦
    if (!_isFoucePixel) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.3 target:self selector:@selector(fouceMode) userInfo:nil repeats:YES];
    }

    AVCaptureDevice*camDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    int flags = NSKeyValueObservingOptionNew;
    //注册通知
    [camDevice addObserver:self forKeyPath:@"adjustingFocus" options:flags context:nil];
    if (_isFoucePixel) {
        [camDevice addObserver:self forKeyPath:@"lensPosition" options:flags context:nil];
    }
    [self start];
}

- (void)foucePixelCancle {
    if (!_isFoucePixel) {
        [_timer invalidate];
        _timer = nil;
    }
    AVCaptureDevice*camDevice =[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [camDevice removeObserver:self forKeyPath:@"adjustingFocus"];
    if (_isFoucePixel) {
        [camDevice removeObserver:self forKeyPath:@"lensPosition"];
    }
    [_session stopRunning];
    _capture = NO;
}

- (void)changeCapture {
    _capture = YES;
}

- (void)showInfo {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未获得授权使用摄像头" message:@"请在'设置-隐私-相机'打开" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

//对焦
- (void)fouceMode
{
    NSError *error;
    AVCaptureDevice *device = [self cameraWithPosition:AVCaptureDevicePositionBack];
    if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
    {
        if ([device lockForConfiguration:&error]) {
            CGPoint cameraPoint = [_preview captureDevicePointOfInterestForPoint:self.center];
            [device setFocusPointOfInterest:cameraPoint];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            [device unlockForConfiguration];
        } else {
            //NSLog(@"Error: %@", error);
        }
    }
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position
{
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    return device;
}

- (NSString *)getPath:(NSString*)fileName
{
    NSString *bundlePath = [NSBundle mainBundle].bundlePath;
    NSString *path = [bundlePath stringByAppendingPathComponent:fileName];
    return path;
}

- (NSString *)simpleRecognition:(cv::Mat&)src
{
    NSString *path_1 = [self getPath:@"cascade.xml"];
    NSString *path_2 = [self getPath:@"HorizonalFinemapping.prototxt"];
    NSString *path_3 = [self getPath:@"HorizonalFinemapping.caffemodel"];
    NSString *path_4 = [self getPath:@"Segmentation.prototxt"];
    NSString *path_5 = [self getPath:@"Segmentation.caffemodel"];
    NSString *path_6 = [self getPath:@"CharacterRecognization.prototxt"];
    NSString *path_7 = [self getPath:@"CharacterRecognization.caffemodel"];
    
    std::string *cpath_1 = new std::string([path_1 UTF8String]);
    std::string *cpath_2 = new std::string([path_2 UTF8String]);
    std::string *cpath_3 = new std::string([path_3 UTF8String]);
    std::string *cpath_4 = new std::string([path_4 UTF8String]);
    std::string *cpath_5 = new std::string([path_5 UTF8String]);
    std::string *cpath_6 = new std::string([path_6 UTF8String]);
    std::string *cpath_7 = new std::string([path_7 UTF8String]);
    
    
    pr::PipelinePR pr2 = pr::PipelinePR(*cpath_1, *cpath_2, *cpath_3, *cpath_4, *cpath_5, *cpath_6, *cpath_7);
    
    std::vector<pr::PlateInfo> list_res = pr2.RunPiplineAsImage(src);
    std::string concat_results = "";
    for(auto one:list_res) {
        if(one.confidence>0.7) {
            concat_results += one.getPlateName()+",";
           _cImage = [self UIImageFromCVMat:one.getPlateImage()];
        }
    }
    
    NSString *str = [NSString stringWithCString:concat_results.c_str() encoding:NSUTF8StringEncoding];
    if (str.length > 0) {
        str = [str substringToIndex:str.length-1];
        str = [NSString stringWithFormat:@"%@",str];
    } else {
        str = [NSString stringWithFormat:@"未识别成功"];
    }
    NSLog(@"===> 识别结果 = %@", str);
    
    return str;
}

//从摄像头缓冲区获取图像
#pragma mark - AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    if (!_isScan) {
        return;
    }
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    /*We unlock the  image buffer*/
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    /*Create a CGImageRef from the CVImageBufferRef*/
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    
    /*We release some components*/
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    /*We display the result on the image view (We need to change the orientation of the image so that the video is displayed correctly)*/
    self.image = [UIImage imageWithCGImage:newImage scale:1.0 orientation:UIImageOrientationUp];
    /*We relase the CGImageRef*/
    CGImageRelease(newImage);
    
    //检边识别
    if (_capture == YES) { //导航栏动画完成
        if (self.isProcessingImage==NO) {  //点击拍照后 不去识别
            if (!self.adjustingFocus) {  //反差对焦下 非正在对焦状态（相位对焦下self.adjustingFocus此值不会改变）
                if (_isLensChanged == _isIOS8AndFoucePixelLensPosition) {
                    _count++;
                    if (_count >= _MaxFR) {
                        
                        //识别
                        UIImage *temp_image = [Utility scaleAndRotateImageBackCamera:self.image rect:_imgRect];
                        source_image = [Utility cvMatFromUIImage:temp_image];
                        NSString* text = [self simpleRecognition:source_image];
                        
                        if ([Utility validateCarNo:text]) {
                            _count = 0;
                            // 停止取景
//                            [_session stopRunning];//
                            _isScan = NO;
                            //设置震动
                            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                            _resulttext = text;
                            [self performSelectorOnMainThread:@selector(readyToGetImage:) withObject:nil waitUntilDone:NO];
                        }
                    }
                } else {
                    _isLensChanged = _isIOS8AndFoucePixelLensPosition;
                    _count = 0;
                }
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}

//找边成功开始拍照
- (void)readyToGetImage:(NSDictionary *)resultDict
{
    _showImageView.image = _cImage;
    [self hiddenChild:NO];
    _resultLabel.text = _resulttext;
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    
    /*反差对焦 监听反差对焦此*/
    if([keyPath isEqualToString:@"adjustingFocus"]){
        self.adjustingFocus =[[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1]];
    }
    /*监听相位对焦此*/
    if([keyPath isEqualToString:@"lensPosition"]){
        _isIOS8AndFoucePixelLensPosition =[[change objectForKey:NSKeyValueChangeNewKey] floatValue];
        //NSLog(@"监听_isIOS8AndFoucePixelLensPosition == %f",_isIOS8AndFoucePixelLensPosition);
    }
}

- (UIImage *)UIImageFromCVMat:(cv::Mat)cvMat {
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    CGBitmapInfo bitmapInfo;
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
        bitmapInfo = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    }else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        bitmapInfo = kCGBitmapByteOrder32Little | (cvMat.elemSize() == 3? kCGImageAlphaNone : kCGImageAlphaNoneSkipFirst);
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGImageRef imageRef = CGImageCreate(cvMat.cols,cvMat.rows,8,8 * cvMat.elemSize(),cvMat.step[0],colorSpace,bitmapInfo,provider,NULL,false,kCGRenderingIntentDefault);
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return finalImage;
}


@end
