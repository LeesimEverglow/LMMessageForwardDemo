//
//  LMRuntimeTool.h
//  MessageForwardDemo
//
//  Created by Leesim on 2018/8/6.
//  Copyright © 2018年 LiMing. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LMRuntimeTool : NSObject

/**
 获取类的元类

 @param childClass 目标类别
 @return 返回元类
 */
+(Class)getMetaClassWithChildClass:(Class)childClass;

/**
 对一个类添加对象方法

 @param class 目标类
 @param methodSel 获取方法名的SEL
 @param impMethodSel 实现方法的SEL用于获取实现方法的IMP
 */
+(void)addMethodWithClass:(Class)class withMethodSel:(SEL)methodSel withImpMethodSel:(SEL)impMethodSel;

@end
