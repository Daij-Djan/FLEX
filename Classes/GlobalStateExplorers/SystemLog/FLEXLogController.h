//
//  FLEXLogController.h
//  FLEX
//
//  Created by Tanner on 3/17/19.
//  Copyright © 2019 Flipboard. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FLEXSystemLogMessage;

@protocol FLEXLogController <NSObject>

/// Guaranteed to call back on the main thread.
+ (instancetype)withUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *newMessages))newMessagesHandler;

- (BOOL)startMonitoring;

@end
