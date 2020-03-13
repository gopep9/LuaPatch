//
//  ApplePay.m
//  luaPatchDemo
//
//  Created by 黄钊 on 2019/8/23.
//  Copyright © 2019 hz. All rights reserved.
//

#import "ApplePay.h"

@implementation ApplePay

//必须要有init函数，否则SKPaymentQueue defaultQueue不能反射调用成功，原因可能是因为编译器在代码中没有找到SKPaymentQueue符号的话就不会把支付模块编译进去
-(instancetype)init{
    if(self = [super init]){
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        
//        Class cls = NSClassFromString(@"SKPaymentQueue");
//        NSInvocation *invocation;
//        NSMethodSignature *methodSignature = [cls methodSignatureForSelector:@selector(defaultQueue)];
//        invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
//        [invocation setSelector:@selector(defaultQueue)];
//        [invocation invoke];
        
        return self;
    }
    return nil;
}


- (void)paymentQueue:(nonnull SKPaymentQueue *)queue updatedTransactions:(nonnull NSArray<SKPaymentTransaction *> *)transactions {
    for(SKPaymentTransaction *transaction in transactions){
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                NSLog(@"paymentQueue SKPaymentTransactionStatePurchased");
                [[SKPaymentQueue defaultQueue]finishTransaction:transaction];
                break;
                
            case SKPaymentTransactionStateFailed:
                NSLog(@"paymentQueue SKPaymentTransactionStateFailed");
                [[SKPaymentQueue defaultQueue]finishTransaction:transaction];
                break;
            
            default:
                NSLog(@"paymentQueue default %li",(long)transaction.transactionState);
                break;
        }
    }
}

@end
