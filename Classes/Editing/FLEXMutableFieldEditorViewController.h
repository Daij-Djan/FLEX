//
//  FLEXMutableFieldEditorViewController.h
//  FLEX
//
//  Created by Tanner on 11/22/18.
//  Copyright © 2018 Flipboard. All rights reserved.
//

#import <FLEX/FLEXFieldEditorViewController.h>

@interface FLEXMutableFieldEditorViewController : FLEXFieldEditorViewController

@property (nonatomic, readonly) UIBarButtonItem *getterButton;

- (void)getterButtonPressed:(id)sender;
- (NSString *)titleForGetterButton;

@end
