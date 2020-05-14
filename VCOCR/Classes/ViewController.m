//
//  ViewController.m
//  VCOCR
//
//  Created by ivic-flm on 2020/5/12.
//  Copyright © 2020 ivic-flm. All rights reserved.
//

#import "ViewController.h"
#import "vcOcrView.h"
@interface ViewController ()
@property (nonatomic, strong)vcOcrView *ocrView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    _ocrView = [[vcOcrView alloc] init];
    _ocrView.imgRect = CGRectMake(0, 150 , self.view.frame.size.width , 200);
    _ocrView.pathRect = CGRectMake(self.view.frame.size.width * 0.1, 150 , self.view.frame.size.width * 0.8, 100);
    _ocrView.frame = self.view.frame;
    [_ocrView setup];
    [self.view addSubview:_ocrView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_ocrView foucePixel];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_ocrView foucePixelCancle];
}


@end
