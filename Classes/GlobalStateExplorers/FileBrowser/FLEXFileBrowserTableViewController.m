//
//  FLEXFileBrowserTableViewController.m
//  Flipboard
//
//  Created by Ryan Olson on 6/9/14.
//
//

#import "FLEXFileBrowserTableViewController.h"
#import "FLEXFileBrowserSearchOperation.h"
#import "FLEXUtility.h"
#import "FLEXWebViewController.h"
#import "FLEXImagePreviewViewController.h"
#import "FLEXTableListViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXObjectExplorerViewController.h"

@interface FLEXFileBrowserTableViewCell : UITableViewCell
@end

@interface FLEXFileBrowserTableViewController () <FLEXFileBrowserSearchOperationDelegate>

@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSArray<NSString *> *childPaths;
@property (nonatomic) NSArray<NSString *> *searchPaths;
@property (nonatomic) NSNumber *recursiveSize;
@property (nonatomic) NSNumber *searchPathsSize;
@property (nonatomic) NSOperationQueue *operationQueue;
@property (nonatomic) UIDocumentInteractionController *documentController;

@end

@implementation FLEXFileBrowserTableViewController

- (id)init
{
    return [self initWithPath:NSHomeDirectory()];
}

- (id)initWithPath:(NSString *)path
{
    self = [super init];
    if (self) {
        self.path = path;
        self.title = [path lastPathComponent];
        self.operationQueue = [NSOperationQueue new];
        
        
        //computing path size
        FLEXFileBrowserTableViewController *__weak weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSFileManager *fileManager = NSFileManager.defaultManager;
            NSDictionary<NSString *, id> *attributes = [fileManager attributesOfItemAtPath:path error:NULL];
            uint64_t totalSize = [attributes fileSize];

            for (NSString *fileName in [fileManager enumeratorAtPath:path]) {
                attributes = [fileManager attributesOfItemAtPath:[path stringByAppendingPathComponent:fileName] error:NULL];
                totalSize += [attributes fileSize];

                // Bail if the interested view controller has gone away.
                if (!weakSelf) {
                    return;
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                FLEXFileBrowserTableViewController *__strong strongSelf = weakSelf;
                strongSelf.recursiveSize = @(totalSize);
                [strongSelf.tableView reloadData];
            });
        });

        [self reloadCurrentPath];
    }
    return self;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.showsSearchBar = YES;
    self.searchBarDebounceInterval = kFLEXDebounceForAsyncSearch;
}

#pragma mark - FLEXGlobalsEntry

+ (NSString *)globalsEntryTitle:(FLEXGlobalsRow)row {
    switch (row) {
        case FLEXGlobalsRowBrowseBundle: return @"📁  Browse Bundle Directory";
        case FLEXGlobalsRowBrowseContainer: return @"📁  Browse Container Directory";
        default: return nil;
    }
}

+ (UIViewController *)globalsEntryViewController:(FLEXGlobalsRow)row {
    switch (row) {
        case FLEXGlobalsRowBrowseBundle: return [[self alloc] initWithPath:NSBundle.mainBundle.bundlePath];
        case FLEXGlobalsRowBrowseContainer: return [[self alloc] initWithPath:NSHomeDirectory()];
        default: return [self new];
    }
}

#pragma mark - FLEXFileBrowserSearchOperationDelegate

- (void)fileBrowserSearchOperationResult:(NSArray<NSString *> *)searchResult size:(uint64_t)size
{
    self.searchPaths = searchResult;
    self.searchPathsSize = @(size);
    [self.tableView reloadData];
}

#pragma mark - Search bar

- (void)updateSearchResults:(NSString *)newText
{
    [self reloadDisplayedPaths];
}

#pragma mark UISearchControllerDelegate

- (void)willDismissSearchController:(UISearchController *)searchController
{
    [self.operationQueue cancelAllOperations];
    [self reloadCurrentPath];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.searchController.isActive ? self.searchPaths.count : self.childPaths.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    BOOL isSearchActive = self.searchController.isActive;
    NSNumber *currentSize = isSearchActive ? self.searchPathsSize : self.recursiveSize;
    NSArray<NSString *> *currentPaths = isSearchActive ? self.searchPaths : self.childPaths;

    NSString *sizeString = nil;
    if (!currentSize) {
        sizeString = @"Computing size…";
    } else {
        sizeString = [NSByteCountFormatter stringFromByteCount:[currentSize longLongValue] countStyle:NSByteCountFormatterCountStyleFile];
    }

    return [NSString stringWithFormat:@"%lu files (%@)", (unsigned long)currentPaths.count, sizeString];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *fullPath = [self filePathAtIndexPath:indexPath];
    NSDictionary<NSString *, id> *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:fullPath error:NULL];
    BOOL isDirectory = [attributes.fileType isEqual:NSFileTypeDirectory];
    NSString *subtitle = nil;
    if (isDirectory) {
        NSUInteger count = [NSFileManager.defaultManager contentsOfDirectoryAtPath:fullPath error:NULL].count;
        subtitle = [NSString stringWithFormat:@"%lu item%@", (unsigned long)count, (count == 1 ? @"" : @"s")];
    } else {
        NSString *sizeString = [NSByteCountFormatter stringFromByteCount:attributes.fileSize countStyle:NSByteCountFormatterCountStyleFile];
        subtitle = [NSString stringWithFormat:@"%@ - %@", sizeString, attributes.fileModificationDate ?: @"Never modified"];
    }

    static NSString *textCellIdentifier = @"textCell";
    static NSString *imageCellIdentifier = @"imageCell";
    UITableViewCell *cell = nil;

    // Separate image and text only cells because otherwise the separator lines get out-of-whack on image cells reused with text only.
    UIImage *image = [UIImage imageWithContentsOfFile:fullPath];
    NSString *cellIdentifier = image ? imageCellIdentifier : textCellIdentifier;

    if (!cell) {
        cell = [[FLEXFileBrowserTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.textLabel.font = [FLEXUtility defaultTableViewCellLabelFont];
        cell.detailTextLabel.font = [FLEXUtility defaultTableViewCellLabelFont];
        cell.detailTextLabel.textColor = UIColor.grayColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSString *cellTitle = [fullPath lastPathComponent];
    cell.textLabel.text = cellTitle;
    cell.detailTextLabel.text = subtitle;

    if (image) {
        cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
        cell.imageView.image = image;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSString *fullPath = [self filePathAtIndexPath:indexPath];
    NSString *subpath = fullPath.lastPathComponent;
    NSString *pathExtension = subpath.pathExtension;

    BOOL isDirectory = NO;
    BOOL stillExists = [NSFileManager.defaultManager fileExistsAtPath:fullPath isDirectory:&isDirectory];
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    UIImage *image = cell.imageView.image;

    if (!stillExists) {
        [FLEXAlert showAlert:@"File Not Found" message:@"The file at the specified path no longer exists." from:self];
        [self reloadDisplayedPaths];
        return;
    }

    UIViewController *drillInViewController = nil;
    if (isDirectory) {
        drillInViewController = [[[self class] alloc] initWithPath:fullPath];
    } else if (image) {
        drillInViewController = [[FLEXImagePreviewViewController alloc] initWithImage:image];
    } else {
        NSData *fileData = [NSData dataWithContentsOfFile:fullPath];
        if (!fileData.length) {
            [FLEXAlert showAlert:@"Empty File" message:@"No data returned from the file." from:self];
            return;
        }

        // Special case keyed archives, json, and plists to get more readable data.
        NSString *prettyString = nil;
        if ([pathExtension isEqualToString:@"json"]) {
            prettyString = [FLEXUtility prettyJSONStringFromData:fileData];
        } else {
            // Regardless of file extension...
            
            id object = nil;
            @try {
                // Try to decode an archived object regardless of file extension
                object = [NSKeyedUnarchiver unarchiveObjectWithData:fileData];
            } @catch (NSException *e) { }
            
            // Try to decode other things instead
            object = object
                        ?: [NSPropertyListSerialization propertyListWithData:fileData
                                                                     options:0
                                                                      format:NULL
                                                                       error:NULL]
                        ?: [NSDictionary dictionaryWithContentsOfFile:fullPath]
                        ?: [NSArray arrayWithContentsOfFile:fullPath];
            
            if (object) {
                drillInViewController = [FLEXObjectExplorerFactory explorerViewControllerForObject:object];
            }
        }

        if (prettyString.length) {
            drillInViewController = [[FLEXWebViewController alloc] initWithText:prettyString];
        } else if ([FLEXWebViewController supportsPathExtension:pathExtension]) {
            drillInViewController = [[FLEXWebViewController alloc] initWithURL:[NSURL fileURLWithPath:fullPath]];
        } else if ([FLEXTableListViewController supportsExtension:pathExtension]) {
            drillInViewController = [[FLEXTableListViewController alloc] initWithPath:fullPath];
        }
        else if (!drillInViewController) {
            NSString *fileString = [NSString stringWithUTF8String:fileData.bytes];
            if (fileString.length) {
                drillInViewController = [[FLEXWebViewController alloc] initWithText:fileString];
            }
        }
    }

    if (drillInViewController) {
        drillInViewController.title = subpath.lastPathComponent;
        [self.navigationController pushViewController:drillInViewController animated:YES];
    } else {
        // Share the file otherwise
        [self openFileController:fullPath];
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIMenuItem *rename = [[UIMenuItem alloc] initWithTitle:@"Rename" action:@selector(fileBrowserRename:)];
    UIMenuItem *delete = [[UIMenuItem alloc] initWithTitle:@"Delete" action:@selector(fileBrowserDelete:)];
    UIMenuItem *copyPath = [[UIMenuItem alloc] initWithTitle:@"Copy Path" action:@selector(fileBrowserCopyPath:)];
    UIMenuItem *share = [[UIMenuItem alloc] initWithTitle:@"Share" action:@selector(fileBrowserShare:)];

    UIMenuController.sharedMenuController.menuItems = @[rename, delete, copyPath, share];

    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    return action == @selector(fileBrowserDelete:)
        || action == @selector(fileBrowserRename:)
        || action == @selector(fileBrowserCopyPath:)
        || action == @selector(fileBrowserShare:);
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    // Empty, but has to exist for the menu to show
    // The table view only calls this method for actions in the UIResponderStandardEditActions informal protocol.
    // Since our actions are outside of that protocol, we need to manually handle the action forwarding from the cells.
}

#if FLEX_AT_LEAST_IOS13_SDK

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point __IOS_AVAILABLE(13.0)
{
    __weak typeof(self) weakSelf = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:NSUUID.UUID.UUIDString
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        UITableViewCell * const cell = [tableView cellForRowAtIndexPath:indexPath];
        UIAction *rename = [UIAction actionWithTitle:@"Rename"
                                               image:nil
                                          identifier:@"Rename"
                                             handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf fileBrowserRename:cell];
        }];
        UIAction *delete = [UIAction actionWithTitle:@"Delete"
                                               image:nil
                                          identifier:@"Delete"
                                             handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf fileBrowserDelete:cell];
        }];
        UIAction *copyPath = [UIAction actionWithTitle:@"Copy Path"
                                                 image:nil
                                            identifier:@"Copy Path"
                                               handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf fileBrowserCopyPath:cell];
        }];
        UIAction *share = [UIAction actionWithTitle:@"Share"
                                              image:nil
                                         identifier:@"Share"
                                            handler:^(__kindof UIAction * _Nonnull action) {
            [weakSelf fileBrowserShare:cell];
        }];
        return [UIMenu menuWithTitle:@"Manage File" image:nil identifier:@"Manage File" options:UIMenuOptionsDisplayInline children:@[rename, delete, copyPath, share]];
    }];
}

#endif

- (void)openFileController:(NSString *)fullPath
{
    UIDocumentInteractionController *controller = [UIDocumentInteractionController new];
    controller.URL = [NSURL fileURLWithPath:fullPath];

    [controller presentOptionsMenuFromRect:self.view.bounds inView:self.view animated:YES];
    self.documentController = controller;
}

- (void)fileBrowserRename:(UITableViewCell *)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    NSString *fullPath = [self filePathAtIndexPath:indexPath];

    BOOL stillExists = [NSFileManager.defaultManager fileExistsAtPath:self.path isDirectory:NULL];
    if (stillExists) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.title([NSString stringWithFormat:@"Rename %@?", fullPath.lastPathComponent]);
            make.configuredTextField(^(UITextField *textField) {
                textField.placeholder = @"New file name";
                textField.text = fullPath.lastPathComponent;
            });
            make.button(@"Rename").handler(^(NSArray<NSString *> *strings) {
                NSString *newFileName = strings.firstObject;
                NSString *newPath = [fullPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:newFileName];
                [NSFileManager.defaultManager moveItemAtPath:fullPath toPath:newPath error:NULL];
                [self reloadDisplayedPaths];
            });
            make.button(@"Cancel").cancelStyle();
        } showFrom:self];
    } else {
        [FLEXAlert showAlert:@"File Removed" message:@"The file at the specified path no longer exists." from:self];
    }
}

- (void)fileBrowserDelete:(UITableViewCell *)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    NSString *fullPath = [self filePathAtIndexPath:indexPath];

    BOOL isDirectory = NO;
    BOOL stillExists = [NSFileManager.defaultManager fileExistsAtPath:fullPath isDirectory:&isDirectory];
    if (stillExists) {
        [FLEXAlert makeAlert:^(FLEXAlert *make) {
            make.title(@"Confirm Deletion");
            make.message([NSString stringWithFormat:
                @"The %@ '%@' will be deleted. This operation cannot be undone",
                (isDirectory ? @"directory" : @"file"), fullPath.lastPathComponent
            ]);
            make.button(@"Delete").destructiveStyle().handler(^(NSArray<NSString *> *strings) {
                [NSFileManager.defaultManager removeItemAtPath:fullPath error:NULL];
                [self reloadDisplayedPaths];
            });
            make.button(@"Cancel").cancelStyle();
        } showFrom:self];
    } else {
        [FLEXAlert showAlert:@"File Removed" message:@"The file at the specified path no longer exists." from:self];
    }
}

- (void)fileBrowserCopyPath:(UITableViewCell *)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    NSString *fullPath = [self filePathAtIndexPath:indexPath];
    UIPasteboard.generalPasteboard.string = fullPath;
}

- (void)fileBrowserShare:(UITableViewCell *)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    NSString *pathString = [self filePathAtIndexPath:indexPath];
    NSURL *filePath = [NSURL fileURLWithPath:pathString];

    BOOL isDirectory = NO;
    [NSFileManager.defaultManager fileExistsAtPath:pathString isDirectory:&isDirectory];

    if (isDirectory) {
        // UIDocumentInteractionController for folders
        [self openFileController:pathString];
    } else {
        // Share sheet for files
        UIActivityViewController *shareSheet = [[UIActivityViewController alloc] initWithActivityItems:@[filePath] applicationActivities:nil];
        [self presentViewController:shareSheet animated:true completion:nil];
    }
}

- (void)reloadDisplayedPaths
{
    if (self.searchController.isActive) {
        [self updateSearchPaths];
    } else {
        [self reloadCurrentPath];
        [self.tableView reloadData];
    }
}

- (void)reloadCurrentPath
{
    NSMutableArray<NSString *> *childPaths = [NSMutableArray array];
    NSArray<NSString *> *subpaths = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.path error:NULL];
    for (NSString *subpath in subpaths) {
        [childPaths addObject:[self.path stringByAppendingPathComponent:subpath]];
    }
    self.childPaths = childPaths;
}

- (void)updateSearchPaths
{
    self.searchPaths = nil;
    self.searchPathsSize = nil;

    //clear pre search request and start a new one
    [self.operationQueue cancelAllOperations];
    FLEXFileBrowserSearchOperation *newOperation = [[FLEXFileBrowserSearchOperation alloc] initWithPath:self.path searchString:self.searchText];
    newOperation.delegate = self;
    [self.operationQueue addOperation:newOperation];
}

- (NSString *)filePathAtIndexPath:(NSIndexPath *)indexPath
{
    return self.searchController.isActive ? self.searchPaths[indexPath.row] : self.childPaths[indexPath.row];
}

@end


@implementation FLEXFileBrowserTableViewCell

- (void)forwardAction:(SEL)action withSender:(id)sender
{
    id target = [self.nextResponder targetForAction:action withSender:sender];
    [UIApplication.sharedApplication sendAction:action to:target from:self forEvent:nil];
}

- (void)fileBrowserRename:(UIMenuController *)sender
{
    [self forwardAction:_cmd withSender:sender];
}

- (void)fileBrowserDelete:(UIMenuController *)sender
{
    [self forwardAction:_cmd withSender:sender];
}

- (void)fileBrowserCopyPath:(UIMenuController *)sender
{
    [self forwardAction:_cmd withSender:sender];
}

- (void)fileBrowserShare:(UIMenuController *)sender
{
    [self forwardAction:_cmd withSender:sender];
}

@end
