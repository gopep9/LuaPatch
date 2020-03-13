//
//  ApplePay.h
//  luaPatchDemo
//
//  Created by 黄钊 on 2019/8/23.
//  Copyright © 2019 hz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/SKProductsRequest.h>
#import <StoreKit/SKPayment.h>
#import <StoreKit/SKPaymentQueue.h>
#import <StoreKit/SKPaymentTransaction.h>


NS_ASSUME_NONNULL_BEGIN

@interface ApplePay : NSObject<SKPaymentTransactionObserver>

@end

NS_ASSUME_NONNULL_END
