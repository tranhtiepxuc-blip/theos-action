#import <UIKit/UIKit.h>

// Hook trực tiếp vào Class và Hàm chuẩn xác quét từ Ghidra của bạn
%hook ASDIManager

- (BOOL)fakeCameraEnabled {
    // Luôn luôn kích hoạt chế độ Camera giả lập ngầm
    return YES;
}

%end

// Hook bổ trợ vào bộ nhớ cấu hình để dylib gốc tự tin đọc file ảnh
%hook NSUserDefaults

- (BOOL)boolForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"fake_camera"] || [defaultName isEqualToString:@"EnableFakeCamera"]) {
        return YES; // Ép công tắc ngầm luôn BẬT
    }
    return %orig;
}

- (id)objectForKey:(NSString *)defaultName {
    // Ép dylib gốc trỏ đường dẫn tìm ảnh về file fake.png nằm trong ruột App
    if ([defaultName isEqualToString:@"fake_video_path"] || [defaultName isEqualToString:@"selected_file_path"]) {
        return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"fake.png"];
    }
    return %orig;
}

%end
