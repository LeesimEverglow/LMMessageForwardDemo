# LMMessageForwardDemo

[原理详细讲解地址](https://www.jianshu.com/p/fdd8f5225f0c)

# 写这篇文章的起因：
从一个对象收到一个它无法响应的方法到崩溃之间发生了什么？
这是J_Knight在最近在博客里面问到的一个问题。其实本质上是在问iOS的消息转发机制。类似的原理文章有很多，但大多数都是在单纯的讲原理，并没有讲解实际的用处。本文先对iOS的消息转发机制进行一个全面的原理讲解，并且在后面起一个引子告诉大家一些通过这个原理可以用来实现的功能，通过这些用途，可以更深刻的理解消息转发机制的本质，让我们能对费了很长时间理解的知识点的价值得更全面的认识。因为东西搞懂了是来用的，单纯的知道原理并不会对自身的提升太高的价值。

# 分析问题：
下面我会配合一个DEMO来做讲解

[LMMessageForwardDemo Demo GitHub地址](https://github.com/LeesimEverglow/LMMessageForwardDemo)

我们在开发过程中，经常会遇到这样的报错
当我们调用一个对象不存在的方法的时候
```
@property (nonatomic,strong) TestMessage* test;
[self.test performSelector:@selector(testFunction)];
```
系统报错 提示如下错误
```
[TestMessage testFunction]: unrecognized selector sent to instance 0x1c4015330
```
类似的报错都是iOS的消息转发机制在无法响应方法之后抛出的问题，我们下面就看一下消息转发机制

# 原理：
我们先看一下下面这个结构图，先对整个消息处理机制有一个初步的认识，很多讲解的过程中也都有类似的结构图，纯粹通过结构图来理解是不够的。
![iOS消息转发机制.jpeg](https://upload-images.jianshu.io/upload_images/1197929-2de08be6100cd895.jpeg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

从全局来看，消息转发机制共分为3大步骤：
1.Method resolution 方法解析处理阶段
2.Fast forwarding 快速转发阶段
3.Normal forwarding 常规转发阶段

那么如果想要不抛出unrecognized selector 的报错，也就需要从这3步里面来做补救了，我们一步一步来看如何在这3个阶段来进行补救。

### 第一步：Method resolution 方法解析处理阶段
如果调用了对象方法首先会进行+(BOOL)resolveInstanceMethod:(SEL)sel判断
如果调用了类方法 首先会进行 +(BOOL)resolveClassMethod:(SEL)sel判断
两个方法都为类方法，如果YES则能接受消息 NO不能接受消息 进入第二步

我们先调用一下对象方法
```
[self.test performSelector:@selector(testFunction)];
```

然后在resolveInstanceMethod进行补救，这里用到了我封装的一个Runtime工具类，这里暂时不做展开讲解，会在后续其他文章里面展开讲解，功能是对一个类添加一个方法。
```
+(BOOL)resolveInstanceMethod:(SEL)sel{
//判断是否为外部调用的方法
if ([NSStringFromSelector(sel) isEqualToString:@"testFunction"]) {
/**
对类进行对象方法 需要把方法添加进入类内
*/
[LMRuntimeTool addMethodWithClass:[self class] withMethodSel:sel withImpMethodSel:@selector(addDynamicMethod)];
return YES;
}
return [super resolveInstanceMethod:sel];
}
```

下面我们再来调用一下TestMessage的类方法
```
[[TestMessage class] performSelector:@selector(testClassFunction)];
```
如果调用类方法需要在resolveClassMethod 进行补救判断
```
+(BOOL)resolveClassMethod:(SEL)sel{
if ([NSStringFromSelector(sel) isEqualToString:@"testClassFunction"]) {
/**
对类进行添加类方法 需要讲方法添加进入元类内
*/
[LMRuntimeTool addMethodWithClass:[LMRuntimeTool getMetaClassWithChildClass:[self class]] withMethodSel:sel withImpMethodSel:@selector(addClassDynamicMethod)];
return YES;
}
return [super resolveClassMethod:sel];
}
```
这里有一个需要特别注意的地方，类方法需要添加到元类里面，OC中所有的类本质上来说都是对象，对象的isa指向本类，类的isa指向元类，元类的isa指向根元类，根元类的isa指向自己，这样的话就形成了一个闭环。
[LMRuntimeTool getMetaClassWithChildClass:[self class]]  这个方法是用来获取本类的元类，对元类添加需要添加的方法。

经过上面两种类型的补救，果然对象方法和类方法都不在抛出异常了，并且打印了数据
```
2018-08-06 15:25:25.667572+0800 MessageForwardDemo[3599:949889] 动态添加类方法
2018-08-06 15:25:25.667612+0800 MessageForwardDemo[3599:949889] 动态添加方法
```

### 第二步:Fast forwarding 快速转发阶段  （后面阶段都针对对象来处理，不考虑类方法）
如果在上一步的2个方法内返回的为YES则能接受消息 NO不能接受消息 进入第二步，我们先把上面方法内的处理方案注释掉，让消息转发进入第二步。
我们新创建一个BackupTestMessage类，里面声明和实现testFunction方法，用来当作备用响应者。
```
-(id)forwardingTargetForSelector:(SEL)aSelector{
if ([NSStringFromSelector(aSelector) isEqualToString:@"testFunction"]) {
return [BackupTestMessage new];
}
return [super forwardingTargetForSelector:aSelector];
}
```
因为一个对象内部可能还有其他可能响应的对象，所以这个方法是转发SEL去对象内部的其他可以响应该方法的对象。
这里创建的一个BackupTestMessage的实例内定义的有testFunction方法，所以返回这个实例之后，果然不再报错了，并且根据打印也能看得出来走了BackupTestMessage这个类的实例方法
```
2018-08-06 15:27:43.234733+0800 MessageForwardDemo[3629:951288] 备用类的对象方法testFunction
```
已经让备用的对象去响应了TestMessage本身无法响应的一个SEL

### 第三部：Normal forwarding 常规转发阶段
如果第2步返回self或者nil,则说明没有可以响应的目标 则进入第三步。
第三步的消息转发机制本质上跟第二步是一样的都是切换接受消息的对象，但是第三步切换响应目标更复杂一些，第二步里面只需返回一个可以响应的对象就可以了，第三步还需要手动将响应方法切换给备用响应对象。
第三步有2个步骤：
```
(1)-(NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
```
在第(1)步中，返回SEL方法的签名，返回的签名是根据方法的参数来封装的。
1.手动创建签名 但是尽量少使用 因为容易创建错误 可以按照这个规则来创建
https://blog.csdn.net/ssirreplaceable/article/details/53376915
根据OBJC的编码类别进行编写后面的char （但是容易写错误，所以建议使用下面的方法）
NSMethodSignature *sign = [NSMethodSignature signatureWithObjCTypes:"v@:"];
//写法例子
//例子"v@:@"
//v@:@ v:返回值类型void;@ id类型,执行sel的对象;：SEL;@参数
//例子"@@:"
//@:返回值类型id;@id类型,执行sel的对象;：SEL
2.自动创建签名
BackupTestMessage * backUp = [BackupTestMessage new];
NSMethodSignature * sign = [backUp methodSignatureForSelector:aSelector];
使用对象本身的methodSignatureForSelector自动获取该SEL对应类别的签名
```
-(NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector{
//如果返回为nil则进行手动创建签名
if ([super methodSignatureForSelector:aSelector]==nil) {
NSMethodSignature * sign = [NSMethodSignature signatureWithObjCTypes:"v@:"];
return sign;
}
return [super methodSignatureForSelector:aSelector];
}
```
```
(2)-(void)forwardInvocation:(NSInvocation *)anInvocation
```
上方的第(1)步中如果调用返回有签名 则进入消息转发最后一步
```
-(void)forwardInvocation:(NSInvocation *)anInvocation{
//创建备用对象
BackupTestMessage * backUp = [BackupTestMessage new];
SEL sel = anInvocation.selector;
//判断备用对象是否可以响应传递进来等待响应的SEL
if ([backUp respondsToSelector:sel]) {
[anInvocation invokeWithTarget:backUp];
}else{
// 如果备用对象不能响应 则抛出异常
[self doesNotRecognizeSelector:sel];
}
}
```

在三个步骤的每一步，消息接受者都还有机会去处理消息。同时，越往后面处理代价越高，最好的情况是在第一步就处理消息，这样runtime会在处理完后缓存结果，下回再发送同样消息的时候，可以提高处理效率。第二步转移消息的接受者也比进入转发流程的代价要小，如果到最后一步forwardInvocation的话，就需要处理完整的NSInvocation对象了。

###实际用途：
1.JSPatch --iOS动态化更新方案<br /> 

具体实现bang神已经在下面两篇博客内进行了详细的讲解，非常精妙的使用了，消息转发机制来进行JS和OC的交互，从而实现iOS的热更新。虽然去年苹果大力整改热更新让JSPatch的审核通过率在有一段时间里面无法过审，但是后面bang神对源码进行代码混淆之后，基本上是可以过审了。不论如何，这个动态化方案都是技术的一次进步，不过目前是被苹果爸爸打压的。不过如果在bang神的平台上用正规混淆版本别自己乱来，通过率还是可以的。有兴趣的同学可以看看这两篇原理文章，这里只摘出来用到消息转发的部分。

[http://blog.cnbang.net/tech/2808/](http://blog.cnbang.net/tech/2808/)
[http://blog.cnbang.net/tech/2855/](http://blog.cnbang.net/tech/2855/)

![bang神博客相关消息转发内容.png](https://upload-images.jianshu.io/upload_images/1197929-ac9cad96a998099b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

具体的实现原理可以去bang神的博客查看。

2.为 @dynamic 实现方法<br /> 

使用 @synthesize 可以为 @property 自动生成 getter 和 setter 方法（现 Xcode 版本中，会自动生成），而 @dynamic 则是告诉编译器，不用生成 getter 和 setter 方法。当使用 @dynamic 时，我们可以使用消息转发机制，来动态添加 getter 和 setter 方法。当然你也用其他的方法来实现。

3.实现多重代理<br /> 

利用消息转发机制可以无代码侵入的实现多重代理，让不同对象可以同时代理同个回调，然后在各自负责的区域进行相应的处理，降低了代码的耦合程度。

[https://blog.csdn.net/kingjxust/article/details/49559091](https://blog.csdn.net/kingjxust/article/details/49559091)

4.间接实现多继承<br /> 

Objective-C本身不支持多继承，这是因为消息机制名称查找发生在运行时而非编译时，很难解决多个基类可能导致的二义性问题，但是可以通过消息转发机制在内部创建多个功能的对象，把不能实现的功能给转发到其他对象上去，这样就做出来一种多继承的假象。转发和继承相似，可用于为OC编程添加一些多继承的效果，一个对象把消息转发出去，就好像他把另一个对象中放法接过来或者“继承”一样。消息转发弥补了objc不支持多继承的性质，也避免了因为多继承导致单个类变得臃肿复杂。


