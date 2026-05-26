// tweak.x
// Floating Fake Image Picker
// Theos Logos

#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>

static UIImage *selectedFakeImage = nil;

@interface FakePickerManager : NSObject
<
PHPickerViewControllerDelegate
>
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

    UIWindow *window =
    UIApplication.sharedApplication.windows.firstObject;

    UIViewController *vc =
    window.rootViewController;

    while (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }

    return vc;
}

- (void)openGallery {

    PHPickerConfiguration *config =
    [[PHPickerConfiguration alloc] init];

    config.selectionLimit = 1;

    config.filter =
    [PHPickerFilter imagesFilter];

    PHPickerViewController *picker =
    [[PHPickerViewController alloc]
     initWithConfiguration:config];

    picker.delegate = self;

    [[self topController]
     presentViewController:picker
     animated:YES
     completion:nil];
}

#pragma mark - Picker Result

- (void)picker:(PHPickerViewController *)picker
didFinishPicking:(NSArray<PHPickerResult *> *)results {

    [picker dismissViewControllerAnimated:YES
                               completion:nil];

    if (results.count == 0) return;

    PHPickerResult *result =
    results.firstObject;

    NSItemProvider *provider =
    result.itemProvider;

    if ([provider canLoadObjectOfClass:[UIImage class]]) {

        [provider loadObjectOfClass:[UIImage class]
                  completionHandler:
        ^(UIImage *image, NSError *error) {

            if (!image) return;

            selectedFakeImage = image;

            NSLog(@"[FakePicker] Image Selected");
        }];
    }
}

@end

#pragma mark - Floating Button

static UIButton *floatingButton;

static void createFloatingButton() {

    UIWindow *window =
    UIApplication.sharedApplication.windows.firstObject;

    if (!window) return;

    floatingButton =
    [UIButton buttonWithType:UIButtonTypeSystem];

    floatingButton.frame =
    CGRectMake(30, 250, 65, 65);

    floatingButton.backgroundColor =
    UIColor.systemBlueColor;

    floatingButton.layer.cornerRadius = 32.5;

    floatingButton.clipsToBounds = YES;

    [floatingButton setTitle:@"📷"
                    forState:UIControlStateNormal];

    floatingButton.titleLabel.font =
    [UIFont systemFontOfSize:28];

    [floatingButton addTarget:
     [FakePickerManager shared]
                          action:
     @selector(openGallery)
                forControlEvents:
     UIControlEventTouchUpInside];

    [window addSubview:floatingButton];
}

#pragma mark - Init

__attribute__((constructor))
static void initFakePicker() {

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 1 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{

        createFloatingButton();
    });
}
