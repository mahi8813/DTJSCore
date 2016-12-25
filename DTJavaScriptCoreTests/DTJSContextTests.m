//
//  DTJSContextTests.m
//  DTJavaScriptCore
//
//  Created by KH1128 on 26/08/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "DTJavaScriptCore.h"


@interface DTJSContextTests : XCTestCase

@end

@implementation DTJSContextTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testEvaluateScript{
    
    DTJSContext *jsCtx = [[DTJSContext alloc] init];
    NSString *script = @"print(\"Hello World!\"); 5";
    DTJSValue *result = [jsCtx evaluateScript:script];
    XCTAssertEqual([result toDouble], 5);
}

- (void)testEvaluateScriptInFile{
    
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSString *filePath = [testBundle pathForResource:@"adder" ofType:@"js" inDirectory:@"JSSources"];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    DTJSContext *jsCtx = [[DTJSContext alloc] init];
    DTJSValue *result = [jsCtx evaluateScriptInFile:fileURL];
    XCTAssertEqual([result toDouble], 85);
}

- (void)testEvaluateScriptWithSourceURL{
    
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    NSString *filePath = [testBundle pathForResource:@"adder" ofType:@"js" inDirectory:@"JSSources"];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    DTJSContext *jsCtx = [[DTJSContext alloc] init];
    DTJSValue *result = [jsCtx evaluateScript:[NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:nil]
                                withSourceURL:fileURL];
    XCTAssertEqual([result toDouble], 85);
}



@end
