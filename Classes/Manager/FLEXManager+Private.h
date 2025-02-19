//
//  FLEXManager+Private.h
//  PebbleApp
//
//  Created by Javier Soto on 7/26/14.
//  Copyright (c) 2014 Pebble Technology. All rights reserved.
//

#import <FLEX/FLEXManager.h>

@class FLEXGlobalsEntry;

@interface FLEXManager ()

/// An array of FLEXGlobalsEntry objects that have been registered by the user.
@property (nonatomic, readonly) NSArray<FLEXGlobalsEntry *> *userGlobalEntries;

@property (nonatomic, readonly) NSDictionary<NSString *, FLEXCustomContentViewerFuture> *customContentTypeViewers;

@end
