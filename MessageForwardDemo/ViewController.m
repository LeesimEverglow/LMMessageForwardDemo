//
//  ViewController.m
//  MessageForwardDemo
//
//  Created by Leesim on 2018/8/5.
//  Copyright © 2018年 LiMing. All rights reserved.
//


#import "ViewController.h"
#import "TestMessage.h"
#import <objc/runtime.h>

@interface ViewController ()

@property (nonatomic,strong) TestMessage* test;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    /******类方法调用******/
    [[TestMessage class] performSelector:@selector(testClassFunction)];
    
    //类方法触发resolveClassMethod方法来判断是否能响应SEL
    
    /******对象方法调用******/
    [self.test performSelector:@selector(testFunction)];
    
    //对象方法触发resolveInstanceMethod方法来判断是否能响应SEL
   
    
    
    
}


-(TestMessage *)test{
    if (!_test) {
        _test = [[TestMessage alloc]init];
    }
    return _test;
}

@end
