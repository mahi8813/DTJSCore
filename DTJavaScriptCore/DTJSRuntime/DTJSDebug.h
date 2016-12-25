//
//  DTJSDebug.h
//  DTJavaScriptCore
//
//  Created by KH1128 on 26/08/16.
//  Copyright © 2016 kony. All rights reserved.
//

#ifndef DTJSDebug_h
#define DTJSDebug_h

#if DEBUG
#define DTJSDebugLog(fmt, ...) NSLog((@"%s [line no: %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define DTJSDebugLog(...)
#endif

#endif /* DTJSDebug_h */
