//
//  DTJSContextInternal.h
//  DTJavaScriptCore
//
//  Created by KH1128 on 11/11/16.
//  Copyright © 2016 kony. All rights reserved.
//

#ifndef DTJSContextInternal_h
#define DTJSContextInternal_h

@interface DTJSContext (Internal)

//TODO: remove commented code
//+ (void)setContext:(DTJSContext *)context ofDukContext:(duk_context *)ctx;
//+ (DTJSContext *)contextOfDukContext:(duk_context *)ctx;
//- (DTJSValue *)thisObject;

- (void)notifyExecption:(DTJSValue *)exception;

@end

#endif /* DTJSContextInternal_h */
