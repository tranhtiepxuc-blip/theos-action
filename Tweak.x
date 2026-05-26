#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

// Ép hệ thống luôn luôn ở trạng thái kích hoạt giả lập ngầm
static BOOL isFakeImageMode = YES;

@interface ASDFakeCameraController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isFakeCamera;
- (void)setFakeCamera:(BOOL)value;
- (NSString *)selectedVideoPath;
@end

// =======================================================
// HOOK ĐỒNG BỘ HOÀN TOÀN LUỒNG XỬ LÝ CỦA DYLIB GỐC
// =======================================================
%hook ASDFakeCameraController

- (BOOL)isFakeCamera {
    // Luôn luôn trả về giá trị YES để kích hoạt lõi xử lý
    return YES;
}

- (void)setFakeCamera:(BOOL)value {
    // Bỏ qua các lệnh thay đổi trạng thái, giữ nguyên chế độ hoạt động
    %orig(YES);
}

- (NSString *)selectedVideoPath {
    // Trỏ thẳng luồng dữ liệu hình ảnh về tệp tin fake.png trong thư mục ứng dụng
    return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"fake.png"];
}

%end

// =======================================================
// HOOK ĐẢM BẢO LUỒNG ĐẦU RA HÌNH ẢNH HOẠT ĐỘNG
// =======================================================
%hook AVCaptureVideoDataOutput

- (void)setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)sampleBufferDelegate queue:(dispatch_queue_t)sampleBufferQueue {
    %orig(sampleBufferDelegate, sampleBufferQueue);
}

%end
