//
//  FLEXPropertyEditorViewController.h
//  Flipboard
//
//  Created by Ryan Olson on 5/20/14.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//

#import <FLEX/FLEXMutableFieldEditorViewController.h>
#import <objc/runtime.h>

@interface FLEXPropertyEditorViewController : FLEXMutableFieldEditorViewController

- (id)initWithTarget:(id)target property:(objc_property_t)property;

+ (BOOL)canEditProperty:(objc_property_t)property onObject:(id)object currentValue:(id)value;

@end
