//
//  DTJSExporterTests.m
//  DTJavaScriptCore
//
//  Created by KH1128 on 03/12/16.
//  Copyright © 2016 kony. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Objc/runtime.h>
#import "DTJSExporter.h"
#import "DTJSContext.h"

@protocol JSExport <NSObject>


@end

@interface DTJSExporterTests : XCTestCase

@end

@implementation DTJSExporterTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testJsMethodStringWithSelectorUsingNSObjectMethods {
    
    unsigned int mtdCount = 0;
    Method *mtdList = class_copyMethodList([NSObject class], &mtdCount);
    for (int i = 0; i < 5; i++) {
        SEL sel = method_getName(mtdList[i]);
        NSString *jsName = [DTJSExporter propertyNameFromSelector:sel];
        NSLog(@"%d: %@\n", i, jsName);
        NSString *expectedJSName = nil;
        switch (i) {
            case 0:
                expectedJSName = @"className";
                break;
            case 1:
                expectedJSName = @"shouldUpdateFocusFromViewToViewHeading";
                break;
            case 2:
                expectedJSName = @"willUpdateFocusInContextWithAnimationCoordinator";
                break;
            case 3:
                expectedJSName = @"willUpdateFocusToView";
                break;
            case 4:
                expectedJSName = @"didUpdateFocusFromView";
                break;
            default:
                break;
        }
        XCTAssertEqualObjects(jsName, expectedJSName);
    }
}


- (void)testPropertyNameFromSelectorUsingHardcodedSelectors {
    
    SEL sel1 = @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:);
    SEL sel2 = @selector(URLSession:task:didReceiveChallenge:completionHandler:);
    SEL sel3 = @selector(URLSession:task:needNewBodyStream:);
    SEL sel4 = @selector(URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:);
    SEL sel5 = @selector(URLSession:task:didFinishCollectingMetrics:);
    SEL sel6 = @selector(URLSession:task:didCompleteWithError:);
    
    NSString *jsName1 = [DTJSExporter propertyNameFromSelector:sel1];
    XCTAssertEqualObjects(jsName1, @"URLSessionTaskWillPerformHTTPRedirectionNewRequestCompletionHandler");
    
    NSString *jsName2 = [DTJSExporter propertyNameFromSelector:sel2];
    XCTAssertEqualObjects(jsName2, @"URLSessionTaskDidReceiveChallengeCompletionHandler");
    
    NSString *jsName3 = [DTJSExporter propertyNameFromSelector:sel3];
    XCTAssertEqualObjects(jsName3, @"URLSessionTaskNeedNewBodyStream");
    
    NSString *jsName4 = [DTJSExporter propertyNameFromSelector:sel4];
    XCTAssertEqualObjects(jsName4, @"URLSessionTaskDidSendBodyDataTotalBytesSentTotalBytesExpectedToSend");
    
    NSString *jsName5 = [DTJSExporter propertyNameFromSelector:sel5];
    XCTAssertEqualObjects(jsName5, @"URLSessionTaskDidFinishCollectingMetrics");
    
    NSString *jsName6 = [DTJSExporter propertyNameFromSelector:sel6];
    XCTAssertEqualObjects(jsName6, @"URLSessionTaskDidCompleteWithError");
}

- (void)testExportClassToJSValueInContext{
    
    DTJSContext *context = [[DTJSContext alloc] init];
    Class cls = [NSArray class];
    context[NSStringFromClass(cls)] = cls;
    
    [context evaluateScript:@"var desc = \"A new NSArray Object will be created\";  \
                              print(desc); \
                              var nsarray = new NSArray(); \
                              var count = nsarray.count; \
                              print(\"created Object\" + nsarray); \
                              NSArray.arrayWithObject(); \
                              1;"];

}
@end
