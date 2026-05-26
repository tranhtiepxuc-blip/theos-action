#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

// ---------------------------------------------------------
// 1. ĐỊNH NGHĨA TRÌNH CHỌN ẢNH TỪ ALBUM HỆ THỐNG
// ---------------------------------------------------------
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
        // Lưu ảnh bạn chọn vào thư mục tạm của thiết bị
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

// ---------------------------------------------------------
// 2. CẤU HÌNH GIAO DIỆN NÚT NỔI ƯU TIÊN CAO (WINDOW LEVEL)
// ---------------------------------------------------------
UIWindow *floatingWindow = nil;
UIButton *btnFloating = nil;
static BOOL isHackCameraOn = NO;

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (!floatingWindow) {
        // Tạo cửa sổ độc lập đè lên trên lớp bản đồ FMS Bình Thuận
        floatingWindow = [[UIWindow alloc] initWithFrame:CGRectMake(30, 250, 65, 65)];
        floatingWindow.windowLevel = UIWindowLevelStatusBar + 100; // Ép lên trên cùng hệ thống
        floatingWindow.backgroundColor = [UIColor clearColor];
        [floatingWindow setHidden:NO];
        
        btnFloating = [UIButton buttonWithType:UIButtonTypeCustom];
        btnFloating.frame = CGRectMake(0, 0, 65, 65);
        btnFloating.layer.cornerRadius = 32.5;
        
        // Mặc định ban đầu: Màu Đen (TẮT)
        btnFloating.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.85];
        [btnFloating setTitle:@"Mở\nMenu" forState:UIControlStateNormal];
        btnFloating.titleLabel.numberOfLines = 2;
        btnFloating.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        btnFloating.titleLabel.textAlignment = NSTextAlignmentCenter;
        btnFloatingMenu.layer.borderWidth = 1.2;
        btnFloatingMenu.layer.borderColor = [UIColor whiteColor].CGColor;
        
        // Cử chỉ kéo thả di chuyển nút nổi trên màn hình
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(ducMoveFloatingBtn:)];
        [btnFloating addGestureRecognizer:pan];
        
        // NHẤN GIỮ 1 GIÂY ➔ MỞ KHU VỰC CHỌN ẢNH TỪ ALBUM
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(ducOpenAlbumMenu:)];
        longPress.minimumPressDuration = 0.8;
        [btnFloating addGestureRecognizer:longPress];
        
        // CHẠM NHẸ 1 PHÁT ➔ BẬT/TẮT GIẢ LẬP CAMERA
        [btnFloating addTarget:self action:@selector(ducToggleHackState) forControlEvents:UIControlEventTouchUpInside];
        
        [floatingWindow addSubview:btnFloating];
    }
}

%new
- (void)ducMoveFloatingBtn:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:floatingWindow.superview];
    floatingWindow.center = CGPointMake(floatingWindow.center.x + translation.x, floatingWindow.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:floatingWindow.superview];
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
        btnFloating.backgroundColor = [UIColor systemGreenColor]; // Đổi sang màu Xanh Lá
        [btnFloating setTitle:@"HACK\nON" forState:UIControlStateNormal];
    } else {
        btnFloating.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.85]; // Về màu Đen
        [btnFloating setTitle:@"HACK\nOFF" forState:UIControlStateNormal];
    }
}
%end

// ---------------------------------------------------------
// 3. GỘP LÕI HACK CŨ - ÉP BIẾN HỆ THỐNG PHẢI ĐỌC FILE ẢNH ĐÃ CHỌN
// ---------------------------------------------------------
%hook NSUserDefaults

- (BOOL)boolForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"EnableFakeCamera"] || [defaultName isEqualToString:@"fake_camera"]) {
        return isHackCameraOn; // Ép lõi hack bật/tắt đồng bộ theo nút bấm nổi
    }
    return %orig;
}

- (NSInteger)integerForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"fake_camera_mode"]) {
        return 0; // Khóa cứng chế độ = 0 (Chế độ giả lập bằng Hình Ảnh tĩnh)
    }
    return %orig;
}

- (id)objectForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"selected_file_path"] || [defaultName isEqualToString:@"fake_video_path"]) {
        // Trỏ luồng đọc camera gốc về tệp ảnh Đức vừa chọn trong Album
        NSString *chosenPath = [CamFakePickerDelegate sharedInstance].customImagePath;
        if (chosenPath && [[NSFileManager defaultManager] fileExistsAtPath:chosenPath]) {
            return chosenPath;
        }
        // Trường hợp chưa chọn ảnh trong Album, tự động tìm file fake.png dự phòng trong app
        return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"fake.png"];
    }
    return %orig;
}

%end
