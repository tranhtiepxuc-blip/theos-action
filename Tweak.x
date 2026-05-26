#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

// Khai báo cấu trúc Class quét được từ Ghidra của bạn
@interface ASDIManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)fakeCameraEnabled;
@end

// Khai báo các Protocol để gọi giao diện chọn ảnh của iOS
@interface CamFakePickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
+ (instancetype)sharedInstance;
@property (nonatomic, retain) NSString *selectedImagePath;
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

// Hàm xử lý sau khi Đức chọn 1 bức ảnh trong Album
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) {
        // Lưu bức ảnh bạn vừa chọn thành một file tạm trong máy
        NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *savePath = [docPath stringByAppendingPathComponent:@"cam_fake_selected.png"];
        [UIImagePNGRepresentation(image) writeToFile:savePath atomically:YES];
        
        // Lưu đường dẫn file ảnh này lại
        self.selectedImagePath = savePath;
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}
@end

// Biến quản lý Nút nổi
UIButton *btnFloatingMenu = nil;
static BOOL isFakeCamRunning = NO;

// =======================================================
// 1. HOOK TẠO NÚT NỔI CHO PHÉP CHẠM GIỮ ĐỂ CHỌN ẢNH
// =======================================================
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (!btnFloatingMenu) {
        btnFloatingMenu = [UIButton buttonWithType:UIButtonTypeCustom];
        btnFloatingMenu.frame = CGRectMake(50, 200, 65, 65);
        btnFloatingMenu.layer.cornerRadius = 32.5;
        
        // Giao diện ban đầu (Màu Đen - TẮT)
        btnFloatingMenu.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
        [btnFloatingMenu setTitle:@"Mở\nMenu" forState:UIControlStateNormal];
        btnFloatingMenu.titleLabel.numberOfLines = 2;
        btnFloatingMenu.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        btnFloatingMenu.titleLabel.textAlignment = NSTextAlignmentCenter;
        btnFloatingMenu.layer.borderWidth = 1.5;
        btnFloatingMenu.layer.borderColor = [UIColor whiteColor].CGColor;
        
        // Cử chỉ kéo thả nút nổi di chuyển khắp màn hình bản đồ FMS
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(floatingBtnMove:)];
        [btnFloatingMenu addGestureRecognizer:pan];
        
        // Nhấn giữ 1 giây ➔ Bung bảng chọn ảnh từ Album
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(openImagePickerMenu:)];
        longPress.minimumPressDuration = 0.8;
        [btnFloatingMenu addGestureRecognizer:longPress];
        
        // Chạm nhẹ 1 phát ➔ Bật / Tắt chế độ Fake camera
        [btnFloatingMenu addTarget:self action:@selector(clickToggleFakeCam) forControlEvents:UIControlEventTouchUpInside];
        
        [[UIApplication sharedApplication].keyWindow addSubview:btnFloatingMenu];
    }
}

%new
- (void)floatingBtnMove:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:btnFloatingMenu.superview];
    gesture.view.center = CGPointMake(gesture.view.center.x + translation.x, gesture.view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:btnFloatingMenu.superview];
}

%new
- (void)openImagePickerMenu:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        // Gọi trình chọn ảnh hệ thống của iPhone
        UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imagePicker.delegate = [CamFakePickerDelegate sharedInstance];
        [self presentViewController:imagePicker animated:YES completion:nil];
    }
}

%new
- (void)clickToggleFakeCam {
    isFakeCamRunning = !isFakeCamRunning;
    
    if (isFakeCamRunning) {
        btnFloatingMenu.backgroundColor = [UIColor systemGreenColor];
        [btnFloatingMenu setTitle:@"HACK\nON" forState:UIControlStateNormal];
    } else {
        btnFloatingMenu.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
        [btnFloatingMenu setTitle:@"HACK\nOFF" forState:UIControlStateNormal];
    }
}
%end

// =======================================================
// 2. HOOK ÉP LÕI MANAGER VÀ BỘ NHỚ ĐỆM TRỎ VỀ ẢNH ĐÃ CHỌN
// =======================================================
%hook ASDIManager
- (BOOL)fakeCameraEnabled {
    return isFakeCamRunning; // Trả về trạng thái Bật/Tắt theo nút bấm
}
%end

%hook NSUserDefaults
- (BOOL)boolForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"fake_camera"] || [defaultName isEqualToString:@"EnableFakeCamera"]) {
        return isFakeCamRunning;
    }
    return %orig;
}

- (id)objectForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"fake_video_path"] || [defaultName isEqualToString:@"selected_file_path"]) {
        // Nếu bạn đã chọn ảnh từ menu, ép dylib đọc ảnh đó. Nếu chưa chọn, tự động tìm file fake.png cũ
        NSString *customImg = [CamFakePickerDelegate sharedInstance].selectedImagePath;
        if (customImg && [[NSFileManager defaultManager] fileExistsAtPath:customImg]) {
            return customImg;
        }
        return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"fake.png"];
    }
    return %orig;
}
%end
