// LDCameraViewController — mirrors LocketCameraBeta/MainHomeScreen:
// live preview, front/back switch, flash, photo shutter, video record, library pick.
#import "LDCameraViewController.h"
#import "LDPreviewViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface LDCameraViewController () <AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) UIView *previewView;
@property (nonatomic, strong) UIButton *shutterButton;
@property (nonatomic, strong) UIButton *flipButton;
@property (nonatomic, strong) UIButton *flashButton;
@property (nonatomic, strong) UIButton *libraryButton;
@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, assign) BOOL useFront;
@property (nonatomic, assign) BOOL flashOn;
@property (nonatomic, assign) BOOL recording;
@end

@implementation LDCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Camera";
    self.view.backgroundColor = [UIColor blackColor];
    self.useFront = YES;

    self.previewView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.previewView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.previewView];

    // Top bar
    UIView *top = [[UIView alloc] init];
    top.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    top.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:top];
    UILabel *t = [[UILabel alloc] init];
    t.text = @"📸 Locket Legacy";
    t.textColor = [UIColor whiteColor];
    t.font = [UIFont boldSystemFontOfSize:16];
    t.translatesAutoresizingMaskIntoConstraints = NO;
    [top addSubview:t];

    self.flipButton = [self circleButton:@"⇄"];
    [self.flipButton addTarget:self action:@selector(onFlip) forControlEvents:UIControlEventTouchUpInside];
    self.flashButton = [self circleButton:@"⚡"];
    [self.flashButton addTarget:self action:@selector(onFlash) forControlEvents:UIControlEventTouchUpInside];
    self.libraryButton = [self circleButton:@"🖼"];
    [self.libraryButton addTarget:self action:@selector(onLibrary) forControlEvents:UIControlEventTouchUpInside];

    // Bottom controls
    UIView *bottom = [[UIView alloc] init];
    bottom.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
    bottom.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:bottom];

    self.shutterButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.shutterButton.backgroundColor = [UIColor whiteColor];
    self.shutterButton.layer.cornerRadius = 34;
    self.shutterButton.layer.borderWidth = 4;
    self.shutterButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.6].CGColor;
    [self.shutterButton addTarget:self action:@selector(onShutter) forControlEvents:UIControlEventTouchUpInside];
    self.shutterButton.translatesAutoresizingMaskIntoConstraints = NO;
    [bottom addSubview:self.shutterButton];

    self.recordButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.recordButton setTitle:@"● REC" forState:UIControlStateNormal];
    [self.recordButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    self.recordButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.recordButton addTarget:self action:@selector(onRecord) forControlEvents:UIControlEventTouchUpInside];
    self.recordButton.translatesAutoresizingMaskIntoConstraints = NO;
    [bottom addSubview:self.recordButton];

    [self.view addSubview:self.flipButton];
    [self.view addSubview:self.flashButton];
    [self.view addSubview:self.libraryButton];

    [NSLayoutConstraint activateConstraints:@[
        [top.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [top.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [top.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [top.heightAnchor constraintEqualToConstant:44],
        [t.centerXAnchor constraintEqualToAnchor:top.centerXAnchor],
        [t.centerYAnchor constraintEqualToAnchor:top.centerYAnchor],
        [bottom.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [bottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bottom.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bottom.heightAnchor constraintEqualToConstant:130],
        [self.shutterButton.centerXAnchor constraintEqualToAnchor:bottom.centerXAnchor],
        [self.shutterButton.centerYAnchor constraintEqualToAnchor:bottom.centerYAnchor],
        [self.shutterButton.widthAnchor constraintEqualToConstant:68],
        [self.shutterButton.heightAnchor constraintEqualToConstant:68],
        [self.recordButton.leadingAnchor constraintEqualToAnchor:self.shutterButton.trailingAnchor constant:28],
        [self.recordButton.centerYAnchor constraintEqualToAnchor:self.shutterButton.centerYAnchor],
        [self.flipButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.flipButton.topAnchor constraintEqualToAnchor:top.bottomAnchor constant:16],
        [self.flipButton.widthAnchor constraintEqualToConstant:44],
        [self.flipButton.heightAnchor constraintEqualToConstant:44],
        [self.flashButton.trailingAnchor constraintEqualToAnchor:self.flipButton.trailingAnchor],
        [self.flashButton.topAnchor constraintEqualToAnchor:self.flipButton.bottomAnchor constant:12],
        [self.flashButton.widthAnchor constraintEqualToConstant:44],
        [self.flashButton.heightAnchor constraintEqualToConstant:44],
        [self.libraryButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.libraryButton.topAnchor constraintEqualToAnchor:top.bottomAnchor constant:16],
        [self.libraryButton.widthAnchor constraintEqualToConstant:44],
        [self.libraryButton.heightAnchor constraintEqualToConstant:44],
    ]];

    [self checkPermissionsAndStart];
}

- (UIButton *)circleButton:(NSString *)title {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:20];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
    b.layer.cornerRadius = 22;
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

- (void)checkPermissionsAndStart {
    AVAuthorizationStatus s = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (s == AVAuthorizationStatusAuthorized) { [self setupSession]; }
    else if (s == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL g) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (g) [self setupSession]; });
        }];
    } else {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Camera needed" message:@"Enable camera in Settings to capture moments." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}

- (AVCaptureDevice *)cameraWithFront:(BOOL)front {
    NSArray *types = @[AVCaptureDeviceTypeBuiltInWideAngleCamera];
    AVCaptureDeviceDiscoverySession *ds = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:types mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
    for (AVCaptureDevice *d in ds.devices) {
        if (front && d.position == AVCaptureDevicePositionFront) return d;
        if (!front && d.position == AVCaptureDevicePositionBack) return d;
    }
    return [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

- (void)setupSession {
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetHigh;
    [self configureInputs];
    self.photoOutput = [[AVCapturePhotoOutput alloc] init];
    if ([self.session canAddOutput:self.photoOutput]) [self.session addOutput:self.photoOutput];
    self.movieOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ([self.session canAddOutput:self.movieOutput]) [self.session addOutput:self.movieOutput];
    AVCaptureDevice *mic = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    if (mic) {
        NSError *e = nil;
        AVCaptureDeviceInput *mi = [AVCaptureDeviceInput deviceInputWithDevice:mic error:&e];
        if (mi && [self.session canAddInput:mi]) [self.session addInput:mi];
    }
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.previewView.bounds;
    [self.previewView.layer addSublayer:self.previewLayer];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.session startRunning];
    });
}

- (void)configureInputs {
    NSError *e = nil;
    AVCaptureDevice *cam = [self cameraWithFront:self.useFront];
    AVCaptureDeviceInput *in = [AVCaptureDeviceInput deviceInputWithDevice:cam error:&e];
    if (!in) return;
    [self.session beginConfiguration];
    if (self.videoInput) [self.session removeInput:self.videoInput];
    if ([self.session canAddInput:in]) { [self.session addInput:in]; self.videoInput = in; }
    [self.session commitConfiguration];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.previewLayer.frame = self.previewView.bounds;
}

- (void)onFlip { self.useFront = !self.useFront; [self configureInputs]; }
- (void)onFlash {
    self.flashOn = !self.flashOn;
    [self.flashButton setTitle:self.flashOn ? @"⚡on" : @"⚡" forState:UIControlStateNormal];
}

- (void)onShutter {
    AVCapturePhotoSettings *s = [AVCapturePhotoSettings photoSettings];
    if (self.flashOn) s.flashMode = AVCaptureFlashModeOn; else s.flashMode = AVCaptureFlashModeOff;
    [self.photoOutput capturePhotoWithSettings:s delegate:self];
}

- (void)onRecord {
    if (self.recording) {
        [self.movieOutput stopRecording];
        self.recording = NO;
        [self.recordButton setTitle:@"● REC" forState:UIControlStateNormal];
        return;
    }
    NSString *p = [NSTemporaryDirectory() stringByAppendingPathComponent:@"clip.mov"];
    [[NSFileManager defaultManager] removeItemAtPath:p error:nil];
    AVCaptureConnection *c = [self.movieOutput connectionWithMediaType:AVMediaTypeVideo];
    if (c.isVideoOrientationSupported) c.videoOrientation = AVCaptureVideoOrientationPortrait;
    [self.movieOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:p] recordingDelegate:self];
    self.recording = YES;
    [self.recordButton setTitle:@"■ STOP" forState:UIControlStateNormal];
}

- (void)onLibrary {
    UIImagePickerController *pk = [[UIImagePickerController alloc] init];
    pk.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    pk.mediaTypes = @[(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie];
    pk.delegate = self;
    [self presentViewController:pk animated:YES completion:nil];
}

#pragma mark - Photo
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    if (error) return;
    NSData *d = [photo fileDataRepresentation];
    if (!d) return;
    UIImage *img = [UIImage imageWithData:d];
    if (!img) return;
    // Square crop (mirrors web CropImageStudio)
    UIImage *sq = [self squareCrop:img];
    LDPreviewViewController *pv = [[LDPreviewViewController alloc] initWithImage:sq videoURL:nil];
    [self.navigationController pushViewController:pv animated:YES];
}

- (UIImage *)normalizedImage:(UIImage *)img {
    // CGImage pixel buffers are stored unrotated; img.size is the ORIENTED size.
    // Cropping the raw buffer with oriented coords picks the wrong region and
    // re-attaching the orientation flag double-rotates. Render through the
    // orientation first so downstream math is in plain Up pixels.
    if (!img || img.imageOrientation == UIImageOrientationUp) return img;
    UIGraphicsBeginImageContextWithOptions(img.size, NO, img.scale);
    [img drawInRect:CGRectMake(0, 0, img.size.width, img.size.height)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return out ?: img;
}

- (UIImage *)squareCrop:(UIImage *)img {
    UIImage *norm = [self normalizedImage:img];
    if (!norm.CGImage) return img;
    CGFloat scale = norm.scale;
    CGFloat side = MIN(norm.size.width, norm.size.height);
    CGRect r = CGRectMake((norm.size.width - side) / 2.0, (norm.size.height - side) / 2.0, side, side);
    CGRect px = CGRectMake(r.origin.x * scale, r.origin.y * scale, side * scale, side * scale);
    // Clamp to the buffer — fractional rounding must never escape it.
    CGFloat w = (CGFloat)CGImageGetWidth(norm.CGImage);
    CGFloat h = (CGFloat)CGImageGetHeight(norm.CGImage);
    px = CGRectIntersection(px, CGRectMake(0, 0, w, h));
    if (CGRectIsNull(px) || px.size.width < 1 || px.size.height < 1) return norm;
    CGImageRef cg = CGImageCreateWithImageInRect(norm.CGImage, px);
    if (!cg) return norm;
    UIImage *out = [UIImage imageWithCGImage:cg scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(cg);
    return out;
}

#pragma mark - Video
- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)url fromConnections:(NSArray *)conns error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.recording = NO;
        [self.recordButton setTitle:@"● REC" forState:UIControlStateNormal];
        if (error && !url) return;
        LDPreviewViewController *pv = [[LDPreviewViewController alloc] initWithImage:nil videoURL:url];
        [self.navigationController pushViewController:pv animated:YES];
    });
}

#pragma mark - Picker
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    NSString *type = info[UIImagePickerControllerMediaType];
    [picker dismissViewControllerAnimated:YES completion:nil];
    if ([type isEqualToString:(NSString *)kUTTypeImage]) {
        UIImage *img = info[UIImagePickerControllerOriginalImage];
        LDPreviewViewController *pv = [[LDPreviewViewController alloc] initWithImage:[self squareCrop:img] videoURL:nil];
        [self.navigationController pushViewController:pv animated:YES];
    } else {
        NSURL *u = info[UIImagePickerControllerMediaURL];
        LDPreviewViewController *pv = [[LDPreviewViewController alloc] initWithImage:nil videoURL:u];
        [self.navigationController pushViewController:pv animated:YES];
    }
}

@end
