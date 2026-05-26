#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

// Khai báo cấu trúc Class quét từ Ghidra của bạn
@interface ASDIManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)fakeCameraEnabled;
@end

// Trình quản lý chọn ảnh từ Album hệ thống
@interface CamFakePickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
+ (instancetype)sharedInstance;
@property (nonatomic, retain) NSString *customImagePath;
@end

@implementation CamFakePickerDelegate
+ (instancetype)sharedInstance {
    static CamFakePickerDelegate *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) {
        NSString *tmpDir = NSTemporaryDirectory();
        NSString *savePath = [tmpDir stringByAppendingPathComponent:@"duc_fake_camera.png"];
        [UIImagePNGRepresentation(image) writeToFile:savePath atomically:YES];
        self.customImagePath = savePath;
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}
@end

// Biến quản lý Nút nổi trực tiếp
UIButton *btnFloatingMenu = nil;
static BOOL isHackCameraOn = NO;

// =======================================================
// CƠ CHẾ MỚI: CHÈN THẲNG NÚT VÀO LỚP HIỂN THỊ CHÍNH CỦA APP
// =======================================================
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    // Kiểm tra nếu view của Controller hiện tại hợp lệ và chưa có nút nổi
    if (self.view && !btnFloatingMenu) {
        
        // Khởi tạo nút bấm trực tiếp
        btnFloatingMenu = [UIButton buttonWithType:UIButtonTypeCustom];
        btnFloatingMenu.frame = CGRectMake(40, 250, 65, 65);
        btnFloatingMenu.layer.cornerRadius = 32.5;
        
        // Giao diện mặc định (Màu Đen - TẮT)
        btnFloatingMenu.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.9];
        [btnFloatingMenu setTitle:@"Mở\nMenu" forState:UIControlStateNormal];
        btnFloatingMenu.titleLabel.numberOfLines = 2;
        btnFloatingMenu.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        btnFloatingMenu.titleLabel.textAlignment = NSTextAlignmentCenter;
        btnFloatingMenu.layer.borderWidth = 1.5;
        btnFloatingMenu.layer.borderColor = [UIColor whiteColor].CGColor;
        
        // Thêm cử chỉ kéo thả di chuyển nút trên màn hình bản đồ
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(ducMoveFloatingBtn:)];
        [btnFloatingMenu addGestureRecognizer:pan];
        
        // NHẤN GIỮ 1 GIÂY ➔ MỞ ALBUM ẢNH
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(ducOpenAlbumMenu:)];
        longPress.minimumPressDuration = 0.8;
        [btnFloatingMenu addGestureRecognizer:longPress];
        
        // CHẠM NHẸ 1 PHÁT ➔ BẬT/TẮT CAMERA GIẢ LẬP
        [btnFloatingMenu addTarget:self action:@selector(ducToggleHackState) forControlEvents:UIControlEventTouchUpInside];
        
        // ÉP BUỘC CHÈN NÚT NỔI NẰM TRÊN CÙNG CỦA VIEW HIỆN TẠI
        [self.view addSubview:btnFloatingMenu];
        [self.view bringSubviewToFront:btnFloatingMenu];
    }
}

%new
- (void)ducMoveFloatingBtn:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:btnFloatingMenu.superview];
    btnFloatingMenu.center = CGPointMake(btnFloatingMenu.center.x + translation.x, btnFloatingMenu.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:btnFloatingMenu.superview];
}

%new
- (void)ducOpenAlbumMenu:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.delegate = [CamFakePickerDelegate sharedInstance];
        [self presentViewController:picker animated:YES completion:nil];
    }
}

%new
- (void)ducToggleHackState {
    isHackCameraOn = !isHackCameraOn;
    
    if (isHackCameraOn) {
        btnFloatingMenu.backgroundColor = [UIColor systemGreenColor]; // BẬT -> Màu Xanh Lá
        [btnFloatingMenu setTitle:@"HACK\nON" forState:UIControlStateNormal];
    } else {
        btnFloatingMenu.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.9]; // TẮT -> Màu Đen
        [btnFloatingMenu setTitle:@"HACK\nOFF" forState:UIControlStateNormal];
    }
}
%end

// =======================================================
// GỘP LÕI HACK ĐỒNG BỘ THEO DỮ LIỆU GHIDRA CỦA BẠN
// =======================================================
%hook ASDIManager
- (BOOL)fakeCameraEnabled {
    return isHackCameraOn;
}
%end

%hook NSUserDefaults
- (BOOL)boolForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"EnableFakeCamera"] || [defaultName isEqualToString:@"fake_camera"]) {
        return isHackCameraOn;
    }
    return %orig;
}

- (NSInteger)integerForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"fake_camera_mode"]) {
        return 0; // Khóa cứng chế độ chạy bằng hình ảnh tĩnh
    }
    return %orig;
}

- (id)objectForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"selected_file_path"] || [defaultName isEqualToString:@"fake_video_path"]) {
        NSString *chosenPath = [CamFakePickerDelegate sharedInstance].customImagePath;
        if (chosenPath && [[NSFileManager defaultManager] fileExistsAtPath:chosenPath]) {
            return chosenPath;
        }
        return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"fake.png"];
    }
    return %orig;
}
%end
