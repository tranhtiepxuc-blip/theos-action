#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

// Khai báo các biến toàn cục quản lý trạng thái
static BOOL isFakeImageMode = NO;
UIButton *floatingActionButton = nil;

// Khai báo lại Class và Phương thức từ dylib cũ để gọi khi cần
@interface ASDFakeCameraController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isFakeCamera;
- (void)setFakeCamera:(BOOL)value;
- (NSString *)selectedVideoPath;
@end

// =======================================================
// 1. TẠO HOOK ĐỂ CHÈN NÚT NỔI VÀO MÀN HÌNH ỨNG DỤNG
// =======================================================
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    // Chỉ tạo nút nếu chưa tồn tại trên cửa sổ chính (UIWindow)
    if (!floatingActionButton) {
        floatingActionButton = [UIButton buttonWithType:UIButtonTypeCustom];
        // Đặt vị trí ban đầu (X: 30, Y: 250, Rộng: 60, Cao: 60)
        floatingActionButton.frame = CGRectMake(30, 250, 60, 60);
        floatingActionButton.layer.cornerRadius = 30;
        
        // Thiết kế giao diện cho nút nổi (Mặc định là TẮT)
        floatingActionButton.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
        [floatingActionButton setTitle:@"CAM
OFF" forState:UIControlStateNormal];
        floatingActionButton.titleLabel.numberOfLines = 2;
        floatingActionButton.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        floatingActionButton.titleLabel.textAlignment = NSTextAlignmentCenter;
        
        // Tạo viền trắng và đổ bóng đổ để nút nổi bật
        floatingActionButton.layer.borderWidth = 1.5;
        floatingActionButton.layer.borderColor = [UIColor whiteColor].CGColor;
        floatingActionButton.layer.shadowColor = [UIColor blackColor].CGColor;
        floatingActionButton.layer.shadowOffset = CGSizeMake(0, 3);
        floatingActionButton.layer.shadowOpacity = 0.5;
        
        // Thêm cử chỉ Pan Gesture để có thể kéo thả di chuyển nút tự do trên màn hình
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleFloatingButtonPan:)];
        [floatingActionButton addGestureRecognizer:panGesture];
        
        // Thêm sự kiện khi chạm (Tap) vào nút nổi để Bật/Tắt chế độ fake ảnh
        [floatingActionButton addTarget:self action:@selector(handleFloatingButtonTap) forControlEvents:UIControlEventTouchUpInside];
        
        // Đưa nút nổi lên lớp trên cùng của màn hình thiết bị
        [[UIApplication sharedApplication].keyWindow addSubview:floatingActionButton];
    }
}

// Phương thức xử lý kéo thả di chuyển nút nổi
%new
- (void)handleFloatingButtonPan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:floatingActionButton.superview];
    gesture.view.center = CGPointMake(gesture.view.center.x + translation.x, gesture.view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:floatingActionButton.superview];
}

// Phương thức xử lý sự kiện Bật/Tắt khi bấm nút nổi
%new
- (void)handleFloatingButtonTap {
    isFakeImageMode = !isFakeImageMode;
    
    if (isFakeImageMode) {
        // Trạng thái BẬT -> Đổi nút sang màu xanh lá
        floatingActionButton.backgroundColor = [UIColor systemGreenColor];
        [floatingActionButton setTitle:@"IMG
FAKE" forState:UIControlStateNormal];
        
        // Đồng bộ trạng thái sang bộ điều khiển gốc nếu có
        if (%c(ASDFakeCameraController)) {
            [[%c(ASDFakeCameraController) sharedInstance] setFakeCamera:YES];
        }
        NSLog(@"[CamMod] Đã kích hoạt chế độ Fake ảnh tĩnh thông qua nút nổi.");
    } else {
        // Trạng thái TẮT -> Trả về màu xám đen gốc
        floatingActionButton.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
        [floatingActionButton setTitle:@"CAM
OFF" forState:UIControlStateNormal];
        
        if (%c(ASDFakeCameraController)) {
            [[%c(ASDFakeCameraController) sharedInstance] setFakeCamera:NO];
        }
        NSLog(@"[CamMod] Đã tắt chế độ Fake ảnh, dùng camera thực.");
    }
}
%end

// =======================================================
// 2. HOOK VÀO CLASS CỦA DYLIB CŨ ĐỂ ÉP ĐỒNG BỘ THEO NÚT NỔI
// =======================================================
%hook ASDFakeCameraController

- (BOOL)isFakeCamera {
    // Trả về trạng thái bật/tắt trực tiếp dựa theo nút nổi
    return isFakeImageMode;
}

- (void)setFakeCamera:(BOOL)value {
    isFakeImageMode = value;
    %orig(value);
}

- (NSString *)selectedVideoPath {
    // Nếu đang bật chế độ fake, ép hệ thống tìm đến tệp ảnh fake.png nằm trong thư mục gốc của App
    if (isFakeImageMode) {
        return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"fake.png"];
    }
    return %orig;
}

%end


// =======================================================
// 3. CAN THIỆP LUỒNG LẤY MẪU HÌNH ẢNH (AVCAPTURE) NẾU CẦN ÉP ẢNH TĨNH
// =======================================================
%hook AVCaptureVideoDataOutput

- (void)setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)sampleBufferDelegate queue:(dispatch_queue_t)sampleBufferQueue {
    // Vẫn gọi hàm gốc để duy trì kết nối hệ thống
    %orig(sampleBufferDelegate, sampleBufferQueue);
}

%end
