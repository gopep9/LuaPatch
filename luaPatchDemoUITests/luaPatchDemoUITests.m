//
//  luaPatchDemoUITests.m
//  luaPatchDemoUITests
//
//  Created by 黄钊 on 2019/9/27.
//  Copyright © 2019 hz. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface luaPatchDemoUITests : XCTestCase

@end

@implementation luaPatchDemoUITests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;

    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
    [[[XCUIApplication alloc] init] launch];

    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // Use recording to get started writing UI tests.
    
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app.buttons[@"请点击我"] tap];
    [app.buttons[@"跳转到新页面"] tap];
    [app.buttons[@"返回上一个页面"] tap];
    [app.buttons[@"请求简书并返回结果"] tap];
    [app.buttons[@"打开苹果支付"] tap];
    [app.buttons[@"测试是否能调用原实现"] tap];
    [app.buttons[@"测试是否能调用父类实现"] tap];
    [app.buttons[@"dispatch测试"] tap];
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

@end
