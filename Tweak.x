#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>

@interface FakePickerManager : NSObject <PHPickerViewControllerDelegate, UINavigationControllerDelegate>
+ (instancetype)shared;
- (void)openGallery;
@property (nonatomic, retain) NSString *savedFakePath;
@end

@implementation FakePickerManager

+ (instancetype)shared {
    static FakePickerManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [FakePickerManager new];
    });
    return manager;
}

- (UIViewController *)topController {
    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }
    return vc;
}

- (void)openGallery {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = 1;
    config.filter = [PHPickerFilter imagesFilter];

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;

    [[self topController] presentViewController:picker animated:YES completion:nil];
}

// XỬ LÝ LƯU ẢNH CHUẨN ĐỂ ÉP ĐỒNG BỘ VỚI LÕI CAMERA CŨ
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    PHPickerResult *result = results.firstObject;
    NSItemProvider *provider = result.itemProvider;

    if ([provider canLoadObjectOfClass:[UIImage class]]) {
        [provider loadObjectOfClass:[UIImage class] completionHandler:^(UIImage *image, NSError *error) {
            if (image) {
                // Lưu bức ảnh được chọn thành file png cố định để luồng tweak cũ dễ dàng đọc dữ liệu
                NSString *tmpDir = NSTemporaryDirectory();
                NSString *savePath = [tmpDir stringByAppendingPathComponent:@"duc_selected_fake.png"];
                [UIImagePNGRepresentation(image) writeToFile:savePath atomically:YES];
                
                self.savedFakePath = savePath;
                NSLog(@"[FakePicker] Saved image to: %@", savePath);
            }
        }];
    }
}
@end

// HOOK CHÈN NÚT NỔI VÀO KEYWINDOW Ở MỨC ƯU TIÊN CAO NHẤT
static UIButton *floatingButton = nil;

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    
    // Đảm bảo nút luôn được chèn vào cửa sổ chính đang hiển thị của app FMS
    if (self.windowLevel == UIWindowLevelNormal && !floatingButton) {
        floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingButton.frame = CGRectMake(30, 250, 65, 65);
        floatingButton.backgroundColor = [UIColor systemBlueColor];
        floatingButton.layer.cornerRadius = 32.5;
        floatingButton.clipsToBounds = YES;
        floatingButton.layer.borderWidth = 1.5;
        floatingButton.layer.borderColor = [UIColor whiteColor].CGColor;
        
        [floatingButton setTitle:@"📷" forState:UIControlStateNormal];
        floatingButton.titleLabel.font = [UIFont systemFontOfSize:28];
        
        // Thêm kéo thả để Đức dễ di chuyển nút trên bản đồ
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleBtnPan:)];
        [floatingButton addGestureRecognizer:pan];
        
        [floatingButton addTarget:[FakePickerManager shared] action:@selector(openGallery) forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:floatingButton];
        [self bringSubviewToFront:floatingButton];
    }
}

%new
- (void)handleBtnPan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:floatingButton.superview];
    floatingButton.center = CGPointMake(floatingButton.center.x + translation.x, floatingButton.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:floatingButton.superview];
}
%end

// HOOK GỘP ÉP LÕI MANAGER VÀ CONFIG CỦA CẬU LUÔN NHẬN ẢNH NÀY
%hook NSUserDefaults
- (BOOL)boolForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"fake_camera"] || [defaultName isEqualToString:@"EnableFakeCamera"]) {
        return YES; // Luôn mở hack camera ngầm
    }
    return %orig;
}

- (id)objectForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"selected_file_path"] || [defaultName isEqualToString:@"fake_video_path"]) {
        NSString *customImg = [FakePickerManager shared].savedFakePath;
        if (customImg && [[NSFileManager defaultManager] fileExistsAtPath:customImg]) {
            return customImg;
        }
        return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"fake.png"];
    }
    return %orig;
}
%end
