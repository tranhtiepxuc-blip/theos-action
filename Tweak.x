#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>

@interface FMHandler : NSObject <PHPickerViewControllerDelegate>
@end

@implementation FMHandler

+ (instancetype)shared {
    static FMHandler *obj;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        obj = [FMHandler new];
    });

    return obj;
}

- (UIViewController *)topVC {

    UIWindow *window =
    UIApplication.sharedApplication.windows.firstObject;

    UIViewController *vc = window.rootViewController;

    while (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }

    return vc;
}

- (void)openPicker {

    PHPickerConfiguration *config =
    [[PHPickerConfiguration alloc] init];

    config.selectionLimit = 1;
    config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[
        PHPickerFilter.imagesFilter,
        PHPickerFilter.videosFilter
    ]];

    PHPickerViewController *picker =
    [[PHPickerViewController alloc]
     initWithConfiguration:config];

    picker.delegate = self;

    [[self topVC]
     presentViewController:picker
     animated:YES
     completion:nil];
}

- (void)picker:(PHPickerViewController *)picker
didFinishPicking:(NSArray<PHPickerResult *> *)results {

    [picker dismissViewControllerAnimated:YES completion:nil];

    if (results.count == 0) return;

    PHPickerResult *result = results.firstObject;

    NSLog(@"Selected media: %@", result);
}

@end

static UIButton *fmButton;

static void createFloatingButton() {

    UIWindow *window =
    UIApplication.sharedApplication.windows.firstObject;

    if (!window) return;

    fmButton =
    [UIButton buttonWithType:UIButtonTypeSystem];

    fmButton.frame = CGRectMake(40, 220, 65, 65);

    fmButton.backgroundColor =
    [UIColor systemBlueColor];

    fmButton.layer.cornerRadius = 32.5;

    [fmButton setTitle:@"📁"
              forState:UIControlStateNormal];

    fmButton.titleLabel.font =
    [UIFont systemFontOfSize:28];

    [fmButton addTarget:[FMHandler shared]
                 action:@selector(openPicker)
       forControlEvents:UIControlEventTouchUpInside];

    [window addSubview:fmButton];
}

__attribute__((constructor))
static void initFakeMedia() {

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 1 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{

        createFloatingButton();
    });
}
