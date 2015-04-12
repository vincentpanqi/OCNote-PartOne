//
//  ViewController.m
//  NSOperationCell图片下载
//
//  Created by iqeggandroid on 15/4/12.
//  Copyright (c) 2015年 bingoogolapple. All rights reserved.
//

#import "ViewController.h"
#import "BGAApp.h"
#import "BGADownloadOperation.h"

#define BGAImageFilePath(imgUrl) [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[imgUrl lastPathComponent]]

@interface ViewController ()<BGADownloadOperationDelegate>

@property (nonatomic, strong) NSMutableArray *apps;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) NSMutableDictionary *operations;
@property (nonatomic, strong) NSMutableDictionary *images;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // 移除所有的下载操作
    [self.queue cancelAllOperations];
    [self.operations removeAllObjects];
    // 移除所有的图片缓存
    [self.images removeAllObjects];
}

- (NSOperationQueue *)queue {
    if(!_queue) {
        _queue = [[NSOperationQueue alloc] init];
    }
    return _queue;
}

- (NSMutableArray *)apps {
    if(!_apps) {
        // 加载plist
        NSString *file = [[NSBundle mainBundle] pathForResource:@"apps" ofType:@"plist"];
        NSArray *dictArray = [NSArray arrayWithContentsOfFile:file];
        // 字典转模型
        NSMutableArray *appArray = [NSMutableArray array];
        for (NSDictionary *dict in dictArray) {
            BGAApp *app = [BGAApp appWithDict:dict];
            [appArray addObject:app];
        }
        _apps = appArray;
    }
    return _apps;
}

- (NSMutableDictionary *)operations {
    if(!_operations) {
        _operations = [[NSMutableDictionary alloc] init];
    }
    return _operations;
}

- (NSMutableDictionary *)images {
    if(!_images) {
        _images = [[NSMutableDictionary alloc] init];
    }
    return _images;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.apps.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *ID = @"app";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ID];
    if(!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ID];
        NSLog(@"创建cell");
    }
    BGAApp *app = self.apps[indexPath.row];
    cell.textLabel.text = app.name;
    cell.detailTextLabel.text = app.download;
    
    UIImage *image = self.images[app.icon];
    if(image) {
        // 图片已经下载成功过
        cell.imageView.image = image;
        NSLog(@"从缓存中取图片%d", indexPath.row);
    } else {
        // 图片并未缓存过
        NSData *data = [NSData dataWithContentsOfFile:BGAImageFilePath(app.icon)];
        if(data) {
            image = [UIImage imageWithData:data];
            cell.imageView.image = image;
            self.images[app.icon] = image;
            NSLog(@"从沙盒中取图片%d", indexPath.row);
        } else {
            NSLog(@"沙盒中没有图片%d", indexPath.row);
            cell.imageView.image = [UIImage imageNamed:@"placeholder"];
            [self downloadImg:app.icon indexPath:indexPath];
        }
    }
    return cell;
}

//- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
//    // 这里仅仅是block对self进行了引用，self对block没有任何引用
//    [UIView animateWithDuration:2.0 animations:^{
//        self.view.frame = CGRectMake(0, 0, 100, 100);
//    }];
//}

- (void)downloadImg:(NSString *)imgUrl indexPath:(NSIndexPath *)indexPath {
    BGADownloadOperation *opreation = self.operations[imgUrl];
    // 如果operation不为空，表示已经在下载了，直接返回
    if (opreation) return;
    
    opreation = [[BGADownloadOperation alloc] init];
    opreation.imgUrl = imgUrl;
    opreation.delegate = self;
    opreation.indexPath = indexPath;
    
    [self.queue addOperation:opreation];
    // 解决重复下载
    self.operations[imgUrl] = opreation;
}

- (void)downloadOperation:(BGADownloadOperation *)operation didFinishDownload:(UIImage *)image {
    if(image) {
        self.images[operation.imgUrl] = image;
        
        // 将图片存到沙盒中UIImage->NSData->File
        NSData *data = UIImagePNGRepresentation(image);
        NSString *filePath = BGAImageFilePath(operation.imgUrl);
        NSLog(@"%@", filePath);
        [data writeToFile:filePath atomically:YES];
    }
    // 从字典中移除下载操作（防止operations越来越大，保证下载失败后，能重新下载）
    [self.operations removeObjectForKey:operation.imgUrl];
    
    // 刷新表格
    [self.tableView reloadRowsAtIndexPaths:@[operation.indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

/**
 *  当用户开始拖拽表格时调用
 */
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    // 暂停下载
    [self.queue setSuspended:YES];
}

/**
 *  当用户停止拖拽表格时调用
 */
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    // 恢复下载
    [self.queue setSuspended:NO];
}

@end