//
//  FLEXHierarchyTableViewController.h
//  Flipboard
//
//  Created by Ryan Olson on 2014-05-01.
//  Copyright (c) 2014 Flipboard. All rights reserved.
//

#import <FLEX/FLEXTableViewController.h>

@protocol FLEXHierarchyTableViewControllerDelegate;

@interface FLEXHierarchyTableViewController : FLEXTableViewController

- (instancetype)initWithViews:(NSArray<UIView *> *)allViews viewsAtTap:(NSArray<UIView *> *)viewsAtTap selectedView:(UIView *)selectedView depths:(NSDictionary<NSValue *, NSNumber *> *)depthsForViews;

@property (nonatomic, weak) id <FLEXHierarchyTableViewControllerDelegate> delegate;

@end

@protocol FLEXHierarchyTableViewControllerDelegate <NSObject>

- (void)hierarchyViewController:(FLEXHierarchyTableViewController *)hierarchyViewController didFinishWithSelectedView:(UIView *)selectedView;

@end
