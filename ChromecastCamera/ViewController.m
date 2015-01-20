//
//  ViewController.m
//  ChromecastCamera
//
//  Created by Chris Jungmann on 1/4/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import "ViewController.h"
#import "CCJImageEngine.h"

//static NSString * kReceiverAppID;
static NSString *const kReceiverAppID = @"898F3A9B";

@interface ViewController () {
    
    UIImage *_btnImage;
    UIImage *_btnImageSelected;
}

// Chromecast
@property GCKMediaControlChannel *mediaControlChannel;
@property GCKApplicationMetadata *applicationMetadata;
@property GCKDevice *selectedDevice;
@property(nonatomic, strong) GCKDeviceScanner *deviceScanner;
@property(nonatomic, strong) UIButton *chromecastButton;
@property(nonatomic, strong) GCKDeviceManager *deviceManager;
@property(nonatomic, readonly) GCKMediaInformation *mediaInformation;

// Camera
@property (strong, nonatomic) UIPopoverController *imagePickerPopover;
@property (nonatomic, strong) NSString *videoFilePath;

// Web Server
@property (strong, nonatomic) NSData *mediaData;
@property (strong, nonatomic) NSString *mediaType;

// Image Picker
@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, strong) WSAssetPickerController *pickerController;
@property (nonatomic, strong) NSArray *mediaArray;

// Used by NSTimer
@property (nonatomic, strong) NSTimer *timerForShow;
@property (nonatomic, assign) NSUInteger mediaIndex;
@property (nonatomic, strong) NSString *mediaURL;

// Used to randomize image order
@property (nonatomic, strong) NSArray *randomNumbersArray;

// User preferences
@property BOOL isOnSwitchSpeed;
@property BOOL isOnSwitchRandomize;
@property BOOL isOnSwitchRepeat;

// iAd
@property (strong, nonatomic) ADBannerView *adBanner;

@end

@implementation ViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    NSLog(@"viewDidLoad");
    
    //You can add your own app id here that you get by registering with the Google Cast SDK Developer Console https://cast.google.com/publish
//    kReceiverAppID=kGCKMediaDefaultReceiverApplicationID;
    
    //Create chromecast button
    _btnImage = [UIImage imageNamed:@"icon-cast-identified.png"];
    _btnImageSelected = [UIImage imageNamed:@"icon-cast-connected.png"];
    
    _chromecastButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_chromecastButton addTarget:self
                          action:@selector(chooseDevice:)
                forControlEvents:UIControlEventTouchDown];
    _chromecastButton.frame = CGRectMake(0, 0, _btnImage.size.width, _btnImage.size.height);
    [_chromecastButton setImage:nil forState:UIControlStateNormal];
    _chromecastButton.hidden = YES;
    
    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithCustomView:_chromecastButton];
    
    //Initialize device scanner
    self.deviceScanner = [[GCKDeviceScanner alloc] init];
    
    // prepare to Chromecast
    GCKFilterCriteria *filterCriteria = [[GCKFilterCriteria alloc] init];
    filterCriteria = [GCKFilterCriteria criteriaForAvailableApplicationWithID:@"898F3A9B"];
    self.deviceScanner.filterCriteria = filterCriteria;
    [self.deviceScanner addListener:self];
    [self.deviceScanner startScan];
    
    // configure image store
    self.mediaData = [[NSData alloc] init];
    // display the URL
//    self.labelURL.text = [SharedWebServer.serverURL absoluteString];
    // configure array used to store images in WSAssetPickerController delegate
//    self.mediaArray = [[NSArray alloc] init];         // no longer used
    
    // allocate the randomizing array
    self.randomNumbersArray = [[NSArray alloc] init];
    
    // TODO: May wish to start the server right before chromcast gets started
    // start web server if not running (start with default image)
    UIImage *image = [UIImage imageNamed:@"movie-icon.jpg"];
    self.imageViewIcon.image = image;
    self.mediaData = UIImagePNGRepresentation(image);
    self.mediaType = @"image/jpeg";
    if (!SharedWebServer.isRunning) {
        NSLog(@"-> Starting Web Server");
        [self webServerAddHandlerForData:self.mediaData type:self.mediaType];
        [self webServerStart];
    }
    
    // configure asset library and picker controller
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    self.assetsLibrary = library;
    self.pickerController = [[WSAssetPickerController alloc] initWithAssetsLibrary:library];
    self.pickerController.delegate = self;
    
    // set switch defaults
    // TODO: load switch settings from user model
    self.switchSpeed.on = NO;
    self.switchRandomize.on = NO;
    self.switchRepeat.on = NO;
    
    // add switch listeners
    [self.switchSpeed addTarget:self action:@selector(selectorForSwitchSpeed:) forControlEvents:UIControlEventValueChanged];
    [self.switchRandomize addTarget:self action:@selector(selectorForSwitchRandomize:) forControlEvents:UIControlEventValueChanged];
    [self.switchRepeat addTarget:self action:@selector(selectorForSwitchRepeat:) forControlEvents:UIControlEventValueChanged];
    
    // iAd
    // implement global iAd process.
    self.adBanner = [[ADBannerView alloc] init];
    self.adBanner.delegate = self;
    [self addADBannerViewToBottom];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - GCKDeviceScannerListener Device Listeners

// CJ Added
- (void)deviceDidComeOnline:(GCKDevice *)device {
    NSLog(@"device found!!! %@", device.friendlyName);
    [self updateButtonStates];
}

- (void)deviceDidGoOffline:(GCKDevice *)device {
    NSLog(@"device did go offline!!!");
    [self updateButtonStates];
}

#pragma mark UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (self.selectedDevice == nil) {
        if (buttonIndex < self.deviceScanner.devices.count) {
            self.selectedDevice = self.deviceScanner.devices[buttonIndex];
            NSLog(@"Selecting device:%@", self.selectedDevice.friendlyName);
            [self connectToDevice];
        }
    } else {
        if (buttonIndex == 1) {  //Disconnect button
            NSLog(@"Disconnecting device:%@", self.selectedDevice.friendlyName);
            // New way of doing things: We're not going to stop the applicaton. We're just going
            // to leave it.
            [self.deviceManager leaveApplication];
            // If you want to force application to stop, uncomment below
            //[self.deviceManager stopApplicationWithSessionID:self.applicationMetadata.sessionID];
            [self.deviceManager disconnect];
            
            [self deviceDisconnected];
            [self updateButtonStates];
        } else if (buttonIndex == 0) {
            // Join the existing session.
            
        }
    }
}

#pragma mark - Chromecast Methods

- (void)chooseDevice:(id)sender {
    
    NSLog(@"chooseDevice:");
    //Choose device
    if (self.selectedDevice == nil) {
        //Choose device
        UIActionSheet *sheet =
        [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Connect to Device", nil)
                                    delegate:self
                           cancelButtonTitle:nil
                      destructiveButtonTitle:nil
                           otherButtonTitles:nil];
        
        for (GCKDevice *device in self.deviceScanner.devices) {
            [sheet addButtonWithTitle:device.friendlyName];
        }
        
        [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        sheet.cancelButtonIndex = sheet.numberOfButtons - 1;
        
        //show device selection
        [sheet showInView:_chromecastButton];
    } else {
        // Gather stats from device.
        [self updateStatsFromDevice];
        
        NSString *friendlyName = [NSString stringWithFormat:NSLocalizedString(@"Casting to %@", nil),
                                  self.selectedDevice.friendlyName];
        NSString *mediaTitle = [self.mediaInformation.metadata stringForKey:kGCKMetadataKeyTitle];
        
        UIActionSheet *sheet = [[UIActionSheet alloc] init];
        sheet.title = friendlyName;
        sheet.delegate = self;
        if (mediaTitle != nil) {
            [sheet addButtonWithTitle:mediaTitle];
        }
        
        //Offer disconnect option
        [sheet addButtonWithTitle:@"Disconnect"];
        [sheet addButtonWithTitle:@"Cancel"];
        sheet.destructiveButtonIndex = (mediaTitle != nil ? 1 : 0);
        sheet.cancelButtonIndex = (mediaTitle != nil ? 2 : 1);
        
        [sheet showInView:_chromecastButton];
    }
}

- (void)updateStatsFromDevice {
    
    NSLog(@"updateStatsFromDevice");

    
    if (self.mediaControlChannel && self.isConnected) {
        _mediaInformation = self.mediaControlChannel.mediaStatus.mediaInformation;
    }
}

- (BOOL)isConnected {
    NSLog(@"isConnected");

    return self.deviceManager.isConnected;
}

- (void)connectToDevice {
    NSLog(@"connectToDevice");

    if (self.selectedDevice == nil)
        return;
    
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    self.deviceManager =
    [[GCKDeviceManager alloc] initWithDevice:self.selectedDevice
                           clientPackageName:[info objectForKey:@"CFBundleIdentifier"]];
    self.deviceManager.delegate = self;
    [self.deviceManager connect];
    
}

- (void)deviceDisconnected {
    NSLog(@"deviceDisconnected");

    self.mediaControlChannel = nil;
    self.deviceManager = nil;
    self.selectedDevice = nil;
}

- (void)updateButtonStates {
    NSLog(@"updateButtonStates");

    if (self.deviceScanner.devices.count == 0) {
        NSLog(@"No devices");
        //Hide the cast button
        _chromecastButton.hidden = YES;
    } else {
        //Show cast button
        NSLog(@"Device found");
        [_chromecastButton setImage:_btnImage forState:UIControlStateNormal];
        _chromecastButton.hidden = NO;
        
        if (self.deviceManager && self.deviceManager.isConnected) {
            //Show cast button in enabled state
            [_chromecastButton setTintColor:[UIColor blueColor]];
        } else {
            //Show cast button in disabled state
            [_chromecastButton setTintColor:[UIColor grayColor]];
            
        }
    }
    
}

#pragma mark - Button & Selector Methods

- (IBAction)buttonShowLibrary:(id)sender {
    
    [self presentViewController:self.pickerController animated:YES completion:NULL];    
}

- (IBAction)buttonCast:(id)sender {
    NSLog(@"Casting Video");
    
    //Show alert if not connected
    if (!self.deviceManager || !self.deviceManager.isConnected) {
        UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Not Connected", nil)
                                   message:NSLocalizedString(@"Please connect to Cast device", nil)
                                  delegate:nil
                         cancelButtonTitle:NSLocalizedString(@"OK", nil)
                         otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // avoid crash
    if ([self.imagePickerPopover isPopoverVisible]) {
        
        // if already there get rid of it
        [self.imagePickerPopover dismissPopoverAnimated:YES];
        self.imagePickerPopover = nil;
        return;
    }
    
    // page 217
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    
    //    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
    //
    //        imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    //
    //    } else {
    //
    //        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    //    }
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imagePicker.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie, nil];
        
    } else {
        // TODO: a better else handler
        NSLog(@"Error catch: No Photo or Video Library");
    }
    
    imagePicker.delegate = self;
    //    [self presentViewController:imagePicker animated:YES completion:nil];
    
    // present popover controller for iPad
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        self.imagePickerPopover = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
        self.imagePickerPopover.delegate = self;
        
        [self.imagePickerPopover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        
    } else {
        
        [self presentViewController:imagePicker animated:YES completion:nil];
    }
    
    // prior location of init chromecast code, refactored as startChromeCasting
//    [self startChromeCasting];

    // streaming local files:
    // http://stackoverflow.com/questions/21631673/how-to-stream-a-local-file-to-the-chromecast
}

- (IBAction)buttonBunny:(id)sender {
    
    NSLog(@"Updating Chromecast with Bunny");
    
    //Define Media metadata
    GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] init];
    
    [metadata setString:@"Crazy Bunny" forKey:kGCKMetadataKeyTitle];
    
    [metadata setString:@"Big Buck Bunny is Sweet"
                 forKey:kGCKMetadataKeySubtitle];
    
    [metadata addImage:[[GCKImage alloc]
                         initWithURL:[[NSURL alloc] initWithString:@"http://commondatastorage.googleapis.com/"
                                      "gtv-videos-bucket/sample/images/BigBuckBunny.jpg"]
                         width:480
                         height:360]];
    
    // define Media information
    GCKMediaInformation *mediaInformation =
    [[GCKMediaInformation alloc] initWithContentID:@"http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
                                        streamType:GCKMediaStreamTypeNone
                                       contentType:@"video/mp4"
                                          metadata:metadata
                                    streamDuration:0
                                        customData:nil];
    
    //cast video
    [_mediaControlChannel loadMedia:mediaInformation autoplay:TRUE playPosition:0];
    
}

- (IBAction)buttonWebsite:(id)sender {
    
    NSLog(@"Updating Chromecast with Web Image");
    
    //Define Media metadata
    GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] init];
    
    [metadata setString:@"iOS Videos and Pictures" forKey:kGCKMetadataKeyTitle];
    
    [metadata setString:@"Chris tells the story of a ship sailing in a sea of mercury"
                 forKey:kGCKMetadataKeySubtitle];
    
    [metadata addImage:[[GCKImage alloc]
                        initWithURL:[[NSURL alloc] initWithString:@"http://incaffeine.com/img/slides/slide-bg.jpg"]
                        width:480
                        height:360]];
    
    GCKMediaInformation *mediaInformation =
    [[GCKMediaInformation alloc] initWithContentID:@"http://incaffeine.com/img/slides/slide-bg.jpg"
                                        streamType:GCKMediaStreamTypeNone
                                       contentType:@"image/jpeg"
                                          metadata:metadata
                                    streamDuration:0
                                        customData:nil];
    
//    GCKMediaInformation *mediaInformation =
//    [[GCKMediaInformation alloc] initWithContentID:@"http://tympanus.net/Tutorials/FullscreenSlideshowAudio/"
//                                        streamType:GCKMediaStreamTypeNone
//                                       contentType:@"image/jpeg"
//                                          metadata:metadata
//                                    streamDuration:0
//                                        customData:nil];
    
    //cast video
    [_mediaControlChannel loadMedia:mediaInformation autoplay:TRUE playPosition:0];
}

// Invoke Social Share features
- (IBAction)buttonSocial:(id)sender {
    
    [self showSharingActivityView];
}

// switches
- (void)selectorForSwitchSpeed:(id)sender {
    
    if ([sender isOn]) {
        NSLog(@"switch selector ON");
        self.isOnSwitchSpeed = YES;
    } else {
        NSLog(@"switch selector OFF");
        self.isOnSwitchSpeed = NO;
    }
    
    if ([self.timerForShow isValid]) {
        NSLog(@"... timer was running, invalidate then restart");
        [self.timerForShow invalidate];
        // restart timer with new speed
        self.timerForShow = [NSTimer
                             scheduledTimerWithTimeInterval:(self.isOnSwitchSpeed ? 3.0 : 6.0)
                             target:self
                             selector:@selector(selectorForDisplayImagesTimer:)
                             userInfo:self.mediaArray
                             repeats:YES];
    }
}

- (void)selectorForSwitchRandomize:(id)sender {
    
    if ([sender isOn]) {
        self.isOnSwitchRandomize = YES;
    } else {
        self.isOnSwitchRandomize = NO;
    }
}

- (void)selectorForSwitchRepeat:(id)sender {
    
    if ([sender isOn]) {
        self.isOnSwitchRepeat = YES;
    } else {
        self.isOnSwitchRepeat = NO;
    }
}


#pragma mark - GCKDeviceManagerDelegate

- (void)deviceManagerDidConnect:(GCKDeviceManager *)deviceManager {
    NSLog(@"connected!!");
    
    [self updateButtonStates];
    [self.deviceManager launchApplication:kReceiverAppID];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
didConnectToCastApplication:(GCKApplicationMetadata *)applicationMetadata
            sessionID:(NSString *)sessionID
  launchedApplication:(BOOL)launchedApplication {
    
    NSLog(@"application has launched");
    self.mediaControlChannel = [[GCKMediaControlChannel alloc] init];
    self.mediaControlChannel.delegate = self;
    [self.deviceManager addChannel:self.mediaControlChannel];
    [self.mediaControlChannel requestStatus];
    
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
didFailToConnectToApplicationWithError:(NSError *)error {
    
    NSLog(@"failed to connect to app");

    [self showError:error];
    
    [self deviceDisconnected];
    [self updateButtonStates];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
didFailToConnectWithError:(GCKError *)error {
    
    NSLog(@"failed to connect");

    [self showError:error];
    
    [self deviceDisconnected];
    [self updateButtonStates];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager didDisconnectWithError:(GCKError *)error {
    
    NSLog(@"Received notification that device disconnected");
    
    if (error != nil) {
        [self showError:error];
    }
    
    [self deviceDisconnected];
    [self updateButtonStates];
    
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
didReceiveStatusForApplication:(GCKApplicationMetadata *)applicationMetadata {
    
    NSLog(@"didReceiveStatusForApplication");

    self.applicationMetadata = applicationMetadata;
}

#pragma mark - GCKMediaControlChannelDelegate

- (void)mediaControlChannelDidUpdateMetadata:(GCKMediaControlChannel *)mediaControlChannel {
    NSLog(@"mediaControlChannelDidUpdateMetadata");
    
}

- (void)mediaControlChannelDidUpdateStatus:(GCKMediaControlChannel *)mediaControlChannel {
    NSLog(@"mediaControlChannelDidUpdateStatus:");
    
}

#pragma mark - GCDWebServer Methods

- (void)webServerStart {
    
    NSLog(@"Starting Web Server");
    // Start server on port 8080
    [SharedWebServer startWithPort:80 bonjourName:nil];
    NSLog(@"Visit %@ in your web browser", SharedWebServer.serverURL);
    
//    self.labelCast.text = @"Now Chromecasting";
//    self.labelURL.text  = [SharedWebServer.serverURL absoluteString];
    
}

// no need to start-stop web server with each new image
- (void)webServerStop {
    
    [SharedWebServer removeAllHandlers];
    [SharedWebServer stop];
    
}

// This sets the response to the client's HTTP 'GET'
- (void)webServerAddHandlerForData:(NSData *)data type:(NSString *)contentType {
    
    // Add a handler to respond to GET requests on any URL
    [SharedWebServer addDefaultHandlerForMethod:@"GET"
                                   requestClass:[GCDWebServerRequest class]
                                   processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
                                       
                                       return [GCDWebServerDataResponse responseWithData:self.mediaData contentType:self.mediaType];
                                       
                                   }];
    
}

//- (void)startChromeCasting {
//    
//    NSLog(@"Starting Chromecast");
//    
//    //Define Media metadata
//    GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] init];
//    
//    [metadata setString:@"iOS Videos and Pictures" forKey:kGCKMetadataKeyTitle];
//    
//    [metadata setString:@"Chris tells the story of a ship sailing in a sea of mercury"
//                 forKey:kGCKMetadataKeySubtitle];
//    
//    //    [metadata addImage:[[GCKImage alloc]
//    //                        initWithURL:[[NSURL alloc] initWithString:@"http://commondatastorage.googleapis.com/"
//    //                                     "gtv-videos-bucket/sample/images/BigBuckBunny.jpg"]
//    //                        width:480
//    //                        height:360]];
//    
//    [metadata addImage:[[GCKImage alloc]
//                        initWithURL:[[NSURL alloc] initWithString:@"http://incaffeine.com/img/slides/slide-bg.jpg"]
//                        width:480
//                        height:360]];
//    
//    //define Media information
//    //    GCKMediaInformation *mediaInformation =
//    //    [[GCKMediaInformation alloc] initWithContentID:
//    //     @"http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
//    //                                        streamType:GCKMediaStreamTypeNone
//    //                                       contentType:@"video/mp4"
//    //                                          metadata:metadata
//    //                                    streamDuration:0
//    //                                        customData:nil];
//    
//    GCKMediaInformation *mediaInformation =
//    [[GCKMediaInformation alloc] initWithContentID:@"http://192.168.3.211/image1.jpg"
//                                        streamType:GCKMediaStreamTypeNone
//                                       contentType:@"image/jpeg"
//                                          metadata:metadata
//                                    streamDuration:0
//                                        customData:nil];
//    
//    //cast video
//    [_mediaControlChannel loadMedia:mediaInformation autoplay:TRUE playPosition:0];
//    
//}


// customized method
- (void)updateChromecastWithTitle:(NSString *)title subTitle:(NSString *)subTitle imageURL:(NSString *)imageURL mediaURL:(NSString *)mediaURL contentType:(NSString *)type {
   
    NSLog(@"Updating Chromecast with parameters");
    
    //Define Media metadata
    GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] init];
    
    [metadata setString:title forKey:kGCKMetadataKeyTitle];
    [metadata setString:subTitle forKey:kGCKMetadataKeySubtitle];
    
    [metadata addImage:[[GCKImage alloc]
                        initWithURL:[[NSURL alloc] initWithString:imageURL]
                        width:480
                        height:360]];
    
    GCKMediaInformation *mediaInformation =
    [[GCKMediaInformation alloc] initWithContentID:mediaURL
                                        streamType:GCKMediaStreamTypeNone
                                       contentType:type
                                          metadata:metadata
                                    streamDuration:0
                                        customData:nil];
    
    //cast video
    [_mediaControlChannel loadMedia:mediaInformation autoplay:TRUE playPosition:0];
}

#pragma mark - WSAssetPickerController Delegates

- (void)assetPickerControllerDidCancel:(WSAssetPickerController *)sender
{
    NSLog(@"assetPickerControllerDidCancel");
    // Dismiss the WSAssetPickerController.
    [self dismissViewControllerAnimated:YES completion:NULL];
}

// WSAssetPicker delegate
- (void)assetPickerController:(WSAssetPickerController *)sender didFinishPickingMediaWithAssets:(NSArray *)assets
{
    NSLog(@"didFinishPickingMediaWithAssets");
    // Dismiss the WSAssetPickerController.
    [self dismissViewControllerAnimated:YES completion:^{
        // Do something with the assets here.
        NSLog(@"dismissViewControllerAnimated: completion block");
        NSLog(@"assets: %@", assets);
        
        //
//        ALAssetRepresentation *arep = [[ALAssetRepresentation alloc] init];
        NSMutableArray *mediaArrayMutable = [[NSMutableArray alloc] init];
        
        for (ALAsset *asset in assets) {
            
            UIImage *imageA = [[UIImage alloc] initWithCGImage:asset.defaultRepresentation.fullScreenImage];
            
            [mediaArrayMutable addObject:imageA];
            
        }
        NSLog(@"%lu", (unsigned long)mediaArrayMutable.count);
        self.mediaArray = [mediaArrayMutable copy];
        
        // make the call to method that will iterate and cast entire array
        [self displayImagesFromArray:[mediaArrayMutable copy]];
        
    }];
}


#pragma mark - iOS Default Image Picker

// Your delegate object’s implementation of this method should pass the specified media on to any custom code that needs it, and should then dismiss the picker view.
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    NSLog(@"didFinishPickingMediaWithInfo:");

    // set the URL's media index to avoid getting a cached image
    NSMutableString *mediaURL = [[NSMutableString alloc] init];
    if (SharedWebServer.serverURL) {
        [mediaURL appendString:[SharedWebServer.serverURL absoluteString]];
    } else {
        NSLog(@"Error catch: SharedWebServer.serverURL nil");
        // dismiss picker
        if (self.imagePickerPopover) {
            [self.imagePickerPopover dismissPopoverAnimated:YES];
            self.imagePickerPopover = nil;
            
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        return;
    }
    
    // adding 1-7-15
    // check if photo or video (Uses <MobileCoreServices/UTCoreTypes.h>)
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    
    // check media type
    if ([mediaType isEqualToString:(NSString *)kUTTypeImage]) {
        
        // a photo was taken or selected
        NSLog(@"a photo was chosen");
        
        // get image picked from image directory
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        //    self.imageData = UIImagePNGRepresentation(image);
//        self.imageViewIcon.image = image;
        
        self.mediaData = UIImageJPEGRepresentation(image, 0.2);
        self.mediaType = @"image/jpeg";
        
        [mediaURL appendString:@"image"];
        [mediaURL appendString:[NSString stringWithFormat:@"%d",(int)CFAbsoluteTimeGetCurrent()]];
        [mediaURL appendString:@".jpg"];
        
    } else if ([mediaType isEqualToString:(NSString *)kUTTypeVideo] || [mediaType isEqualToString:(NSString *)kUTTypeMovie]) {
        
        // a video was taken
        NSLog(@"a video or movie was chosen");
        
        self.imageViewIcon.image = [UIImage imageNamed:@"movie-icon.jpg"];
        
        // save video to NSData mediaData
            // movie != video
        NSURL *videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
        NSLog(@"mediaURL %@", videoURL);
        self.mediaData  = [NSData dataWithContentsOfURL:videoURL];
        self.mediaType  = @"video/mp4";
        
        [mediaURL appendString:@"video"];
        [mediaURL appendString:[NSString stringWithFormat:@"%d",(int)CFAbsoluteTimeGetCurrent()]];
        [mediaURL appendString:@".mp4"];

    } else {
        
        NSLog(@"media type unknown");
    }
    
//    NSLog(@"NSDictionary image info: %@", info);
    // process image based on type
    
    NSLog(@"==> mutable URL %@", mediaURL);
    
    // update it if already casting
    [self updateChromecastWithTitle:@"Image"
                           subTitle:@"from iPhone"
                           imageURL:@"http://incaffeine.com/img/slides/slide-bg.jpg"
                           mediaURL:[mediaURL copy]
                        contentType:self.mediaType];
    
    // dismiss picker
    if (self.imagePickerPopover) {
        [self.imagePickerPopover dismissPopoverAnimated:YES];
        self.imagePickerPopover = nil;
        
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
}

#pragma mark - Main Methods

- (void)displayImagesFromArray:(NSArray *)imageArray {
    
    NSLog(@"displayImagesFromArray:count: %lu", [imageArray count]);
    
    // create random array in case it's needed in NSTimer selector later
    self.randomNumbersArray = [self createRandomArray:[imageArray count]];
    
    NSLog(@"self.randomNumbersArray:count: %lu", [self.randomNumbersArray count]);
    
    if ([imageArray count] > 0) {
        
        // setup image counter incremented by NSTimer
        self.mediaIndex = 0;
        
        // check if timer already running and invalidate if it is
        if ([self.timerForShow isValid]) {
            NSLog(@"timer already running, kill first");
            [self.timerForShow invalidate];
        }
        
        // start timer to walk through all array items
        self.timerForShow = [NSTimer
                             scheduledTimerWithTimeInterval:(self.isOnSwitchSpeed ? 3.0 : 6.0)
                             target:self
                             selector:@selector(selectorForDisplayImagesTimer:)
                             userInfo:imageArray
                             repeats:YES];
        
    } else {
        // do nothing
        NSLog(@"Oops!  No image selected, don't invoke NSTimer");
    }
}

// Selector method called by NSTimer
- (void)selectorForDisplayImagesTimer:(NSTimer *)timer {

    NSLog(@"selectorForDisplayImagesTimer");
    NSLog(@"... counter: %lu", (unsigned long)self.mediaIndex);
    
    // EXTRACT USERINFO
    
    // extract the info sent by timer & check it
    NSArray *itemArray = [timer userInfo];
    if (!itemArray) {
        [timer invalidate];
        return;
    }
    
    // CHECK WEB SERVER & GET URL
    
    // build image info from scratch, checking the server URL each time
    NSMutableString *mediaURL = [[NSMutableString alloc] init];
    if (SharedWebServer.serverURL) {
        [mediaURL appendString:[SharedWebServer.serverURL absoluteString]];
        
    } else {
        NSLog(@"Error catch: SharedWebServer.serverURL nil");
        return;
    }
    
    // WORK ON THE IMAGE & UPDATE CHROMECAST WITH IT
    
    // check media type
    if (self.mediaIndex < [itemArray count]) {
        
        // a photo was taken or selected
        NSLog(@"... All good, a photo was chosen");
        
        // get image picked from image directory
        UIImage *image = [[UIImage alloc] init];
        // are we to randomize and ... can we?
        if ((self.isOnSwitchRandomize) && ([self.randomNumbersArray count] == [itemArray count])) {
            NSLog(@"... use random index");
            // in order to randomize we intermediate the index
//            NSNumber *randomNum = self.randomNumbersArray[self.mediaIndex];
//            int randomInt = [randomNum intValue];
//            NSLog(@"... random int: %d", randomInt);
//            image = itemArray[randomInt];
            // or ...
            image = itemArray[[self.randomNumbersArray[self.mediaIndex] intValue]];
            
        } else {
            // use straight index
            NSLog(@"... use straight index");
            image = itemArray[self.mediaIndex];
        }
        
        // check if landscape for image fit
        if (image.size.width > image.size.height) {
            NSLog(@"landscape");
            // scale to fill
            // TODO: set CGSize dynamically, not hard coded
            CGSize newSize = CGSizeMake(1280, 720);
            // TODO: optimize 'scaleImage' process
            image = [CCJImageEngine scaleImage:image toSize:newSize];
        } else {
            NSLog(@"portrait");
        }

        // TODO: reduce compression before testing
        self.mediaData = UIImageJPEGRepresentation(image, 0.2);
        self.mediaType = @"image/jpeg";
        
        // start building the image name
        [mediaURL appendString:@"image"];
        // check if the URL needs to be unique
        if (self.isOnSwitchRepeat) {
            // URLs can be cacheable
            if ((self.isOnSwitchRandomize) && ([self.randomNumbersArray count] == [itemArray count])) {
                
                // TODO: Check if randomizing the URL is really necessary - probably not!
                // we're repeating random images, so we use the random increment
                [mediaURL appendString:[NSString stringWithFormat:@"%d",[self.randomNumbersArray[self.mediaIndex] intValue]]];
            
            } else {
                // we're repeating non-random images, so use simple increment
                [mediaURL appendString:[NSString stringWithFormat:@"%lu",self.mediaIndex]];
            }
            
        } else {
            // set the URL's media index uniquely to avoid getting a cached image
            [mediaURL appendString:[NSString stringWithFormat:@"%d",(int)CFAbsoluteTimeGetCurrent()]];
        }

        [mediaURL appendString:@".jpg"];
        NSLog(@"==> mutable URL %@", mediaURL);
        
        
        // UPDATE CHROMECAST
        
        // update cast
        [self updateChromecastWithTitle:@"Image"
                               subTitle:@"from iPhone"
                               imageURL:@"http://incaffeine.com/img/slides/slide-bg.jpg"
                               mediaURL:[mediaURL copy]
                            contentType:self.mediaType];
        
    } else {
        NSLog(@"Oop! Something's being naughty: no mediaData");
    }
    
    // CHECK IF SHOULD TERMINATE
    
    // increment image index
    self.mediaIndex = self.mediaIndex + 1;
    
    // check where we're at
    if (self.mediaIndex >= [itemArray count]) {
        
        // are we supposed to repeat?
        if (self.isOnSwitchRepeat) {
            // keep streaming, starting back at first image.
            NSLog(@"==> Restart streaming");
            // re-shuffle image order
            self.randomNumbersArray = [self createRandomArray:[itemArray count]];
            self.mediaIndex = 0;
        } else {
            // let's stop the timer and do not come back here if we're done
            NSLog(@"==> Done streaming");
            [timer invalidate];
        }
    }
}

// new method that does the image processing during the NSTimer delay
- (void)selectorForDisplayImagesTimerDuringWait:(NSTimer *)timer {
    
    NSLog(@"selectorForDisplayImagesTimerDuringWait");
    NSLog(@"... counter: %lu", (unsigned long)self.mediaIndex);
    
    // EXTRACT USERINFO
    
    // extract the info sent by timer & check it
    NSArray *itemArray = [timer userInfo];
    if (!itemArray) {
        [timer invalidate];
        return;
    }
    
    // CHECK WEB SERVER & GET URL
    
    // build image info from scratch, checking the server URL each time
    NSMutableString *mediaURL = [[NSMutableString alloc] init];
    if (SharedWebServer.serverURL) {
        [mediaURL appendString:[SharedWebServer.serverURL absoluteString]];
        
    } else {
        NSLog(@"Error catch: SharedWebServer.serverURL nil");
        return;
    }
    
    // UPDATE CHROMECAST IF AN IMAGE IS READY
    
    // update cast
    if ([self.mediaType length] > 0) {
        [self updateChromecastWithTitle:@"Image"
                               subTitle:@"from iPhone"
                               imageURL:@"http://incaffeine.com/img/slides/slide-bg.jpg"
                               mediaURL:[mediaURL copy]
                            contentType:self.mediaType];
    }
    
    // WORK ON THE IMAGE & UPDATE CHROMECAST WITH IT
    
    // check media type
    if (self.mediaIndex < [itemArray count]) {
        
        // a photo was taken or selected
        NSLog(@"... All good, a photo was chosen");
        
        // get image picked from image directory
        UIImage *image = [[UIImage alloc] init];
        // are we to randomize and ... can we?
        if ((self.isOnSwitchRandomize) && ([self.randomNumbersArray count] == [itemArray count])) {
            NSLog(@"... use random index");
            // in order to randomize we intermediate the index
            //            NSNumber *randomNum = self.randomNumbersArray[self.mediaIndex];
            //            int randomInt = [randomNum intValue];
            //            NSLog(@"... random int: %d", randomInt);
            //            image = itemArray[randomInt];
            // or ...
            image = itemArray[[self.randomNumbersArray[self.mediaIndex] intValue]];
            
        } else {
            // use straight index
            NSLog(@"... use straight index");
            image = itemArray[self.mediaIndex];
        }
        
        // check if landscape for image fit
        if (image.size.width > image.size.height) {
            NSLog(@"landscape");
            // scale to fill
            // TODO: set CGSize dynamically, not hard coded
            CGSize newSize = CGSizeMake(1280, 720);
            // TODO: optimize 'scaleImage' process
            image = [CCJImageEngine scaleImage:image toSize:newSize];
        } else {
            NSLog(@"portrait");
        }
        
        // TODO: reduce compression before testing
        self.mediaData = UIImageJPEGRepresentation(image, 0.2);
        self.mediaType = @"image/jpeg";
        
        // start building the image name
        [mediaURL appendString:@"image"];
        // check if the URL needs to be unique
        if (self.isOnSwitchRepeat) {
            // URLs can be cacheable
            if ((self.isOnSwitchRandomize) && ([self.randomNumbersArray count] == [itemArray count])) {
                
                // TODO: Check if randomizing the URL is really necessary - probably not!
                // we're repeating random images, so we use the random increment
                [mediaURL appendString:[NSString stringWithFormat:@"%d",[self.randomNumbersArray[self.mediaIndex] intValue]]];
                
            } else {
                // we're repeating non-random images, so use simple increment
                [mediaURL appendString:[NSString stringWithFormat:@"%lu",self.mediaIndex]];
            }
            
        } else {
            // set the URL's media index uniquely to avoid getting a cached image
            [mediaURL appendString:[NSString stringWithFormat:@"%d",(int)CFAbsoluteTimeGetCurrent()]];
        }
        
        [mediaURL appendString:@".jpg"];
        NSLog(@"==> mutable URL %@", mediaURL);
        
        
        // UPDATE CHROMECAST
        
        // update cast
        [self updateChromecastWithTitle:@"Image"
                               subTitle:@"from iPhone"
                               imageURL:@"http://incaffeine.com/img/slides/slide-bg.jpg"
                               mediaURL:[mediaURL copy]
                            contentType:self.mediaType];
        
    } else {
        NSLog(@"Oop! Something's being naughty: no mediaData");
    }
    
    // CHECK IF SHOULD TERMINATE
    
    // increment image index
    self.mediaIndex = self.mediaIndex + 1;
    
    // check where we're at
    if (self.mediaIndex >= [itemArray count]) {
        
        // are we supposed to repeat?
        if (self.isOnSwitchRepeat) {
            // keep streaming, starting back at first image.
            NSLog(@"==> Restart streaming");
            // re-shuffle image order
            self.randomNumbersArray = [self createRandomArray:[itemArray count]];
            self.mediaIndex = 0;
        } else {
            // let's stop the timer and do not come back here if we're done
            NSLog(@"==> Done streaming");
            [timer invalidate];
        }
    }
}



#pragma mark - Helper Methods

// returns a non duplicate value array of random numbers
- (NSArray *)createRandomArray:(NSInteger)arraySize {
    
    NSMutableArray *randomNumbers = [[NSMutableArray alloc] initWithCapacity:arraySize];
    if (arraySize > 0) {
        // add random items to the array until we have number added matches desired array size
        for (int i = 0; randomNumbers.count < arraySize; i++) {
            
            int temp = arc4random_uniform((uint32_t)arraySize);
            NSNumber *randomNum = [NSNumber numberWithInt:temp];
            
            // check if the randomNum already in array before adding
            if (![randomNumbers containsObject:randomNum]) {
                [randomNumbers addObject:randomNum];
            }
            // check that we are not caught in an infinite loop (not likely as long as arc4random is working properly)
            if (i > 9999) {
                return [randomNumbers copy];
            }
        }
        // convert NSMutable array to NSArray and return
        return [randomNumbers copy];
    }
    return NULL;
}

// image utilities


// error alert view
- (void)showError:(NSError *)error {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                    message:NSLocalizedString(error.description, nil)
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Social Sharing Methods

//- (IBAction)shareButton:(UIBarButtonItem *)sender
- (void)showSharingActivityView {
    
    NSString *textToShare = @"Chromecast slideshow app #ChromeCamera";
    UIImage *imageToShare = [UIImage imageNamed:@"Icon-76.png"];
    NSURL *myWebsite = [NSURL URLWithString:@"https://itunes.apple.com/us/artist/chris-jungmann/id870848514"];
    
    //    NSArray *objectsToShare = @[textToShare, myWebsite];
    NSArray *objectsToShare = [NSArray arrayWithObjects:textToShare, imageToShare, myWebsite, nil];
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:objectsToShare applicationActivities:nil];
    
    NSArray *excludeActivities = @[UIActivityTypeAirDrop,
                                   UIActivityTypePrint,
                                   UIActivityTypeAssignToContact,
                                   UIActivityTypeSaveToCameraRoll,
                                   UIActivityTypeAddToReadingList,
                                   UIActivityTypePostToFlickr,
                                   UIActivityTypeCopyToPasteboard,
                                   UIActivityTypePostToVimeo];
    
    activityVC.excludedActivityTypes = excludeActivities;
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - ADBanner delegates

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error {
    
    [self.adBanner setHidden:YES];
    //    NSLog(@"AboutVC: didFailToReceiveAdWithError");
    
    //    // show my own add image when add is hidden
    //    // NOT USING DUE TO PLACEMENT ISSUE
    //    UIImage *image = [UIImage imageNamed:@"incaffeine.jpg"];
    //    self.localAdView = [[UIImageView alloc] initWithImage:image];
    //    self.localAdView.frame = CGRectMake(0, self.view.bounds.size.height, 0, 0);
    //
    //    //Height will be automatically set, raise the view by its own height
    //    self.localAdView.frame = CGRectOffset(self.adBanner.frame, 0, -self.adBanner.frame.size.height);
    //
    //    [self.view addSubview:self.localAdView];
    
}

- (void)bannerViewActionDidFinish:(ADBannerView *)banner {
    //    NSLog(@"---> MainVC: bannerViewActionDidFinish");
}


- (void)bannerViewDidLoadAd:(ADBannerView *)banner {
    
    [self.adBanner setHidden:NO];
    //    NSLog(@"---> MainVC: bannerViewDidLoadAd");
    
}

//This method adds shared adbannerview to the current view and sets its location to bottom of screen
//Should work on all devices

-(void) addADBannerViewToBottom
{
    //    NSLog(@"---> MainVC: addBannerViewToBottom");
    
    self.adBanner.delegate = self;
    //Position banner just below the screen
    self.adBanner.frame = CGRectMake(0, self.view.bounds.size.height, 0, 0);
    //Height will be automatically set, raise the view by its own height
    self.adBanner.frame = CGRectOffset(self.adBanner.frame, 0, -self.adBanner.frame.size.height -self.tabBarController.tabBar.frame.size.height);
    [self.view addSubview:self.adBanner];
    
}

-(void) addADBannerViewToTop
{
    //    NSLog(@"---> MainVC: addBannerViewToTop");
    
    self.adBanner.delegate = self;
    //Position banner just below the top status bar
    self.adBanner.frame = CGRectMake(0, 0, 0, 0);
    //Height will be automatically set, lower the view by its own height
    self.adBanner.frame = CGRectOffset(self.adBanner.frame, 0, +self.adBanner.frame.size.height/2.8);
    [self.view addSubview:self.adBanner];
    
}


-(void) removeADBannerView
{
    //    NSLog(@"---> MainVC: removeADBanner");
    self.adBanner.delegate = nil;
    [self.adBanner removeFromSuperview];
}


@end

// todo - Test during extended runtime using instruments to watch for memory leaks
// feature - Allow 'select all' in media picker if feasable
// todo - Use Instruments to pinpoint CPU consumption
// todo - Look to buffer the image for the next display cycle, one ahead. (3:30 - 4:30) +
// todo - Noticed difference in load speeds of landscape VS portrait images due to aspect fill routine slowing landscape.
// 01-20-15 - Set User Preferences for switch settings in ViewController (0.5 hours)
// 01-20-15 - Finished wiring up CCJUserModel in AppDelegate to save user preferences
// 01-20-15 - Running Instruments to determine cause of slowdown (12:20 - 1::00)
// 01-20-15 - Restart NSTimer after switchSpeed turned off and former timer invalidated. (0.25 hours)
// 01-20-15 - Check for 'timer was running' condition always being true on switchSpeed change (0.25 hours)
// 01-17-15 - Add iAd framework and instantiate (0.75 hours)
// 01-17-15 - Add Social Sharing with placeholder for icon style button (0.25 hours)
// 01-17-15 - Check image landscape or portrait and properly set CGSize (0.1 hours)
// 01-17-15 - Trying different methods to change the aspect ratio of the image for fill screen landscape fit (1.0h : 11:00 start - 12:00)  Now works for landscape images
// 01-15-15 - Created CCJImageEngine to process image for better screen fitting.  Read about Chromecast window & view width and height (3:30 Start ... 5:30)
// 01-15-15 - Added CCJUserModel to project and customized with switch persistence (0.5 hours)
// 01-15-15 - Set up private repository on GitHub CastCamera
// 01-15-15 - Tested that I can change random & repeat modes mid-flight.
// 01-15-15 - Add repeat loop logic and wire to switch.  Challenge:  Take advantage of cache instead of using image time stamps as part of URL. (1.0 hours - 1:30 pm done)
// 01-15-15 - Add image order randomizer and wire to switch.  Copied 'createRandomArray' from At 420. (1.5 hours - 11:00 am start, 12:30 done)
// 01-15-15 - What happened to the Chromecast icon?  My UIImage covered it. Duh!
// 01-14-15 - Wire speed switch to timer.  Wow Ringo by Joris Voorn is insane perfect!  (4:45 pm - Completed control for switchSpeed.  Took 1:15)
// 01-14-15 - Loop array of UIImages with a timer.  http://stackoverflow.com/questions/1449035/how-do-i-use-nstimer Got it woking with NSTime (Done at 3:15 using 0.75 hours)
// 01-14-15 - Cast first image from new picker array 2:29 pm while in the groove with Rachel Row - Follow The Step (Justin Martin Remix) - Deep House!  (2.5 hours to this point)
// 01-14-15 - Wire up array of image URLs being select and convert them to array of UIImage (2 hours - as of 14:15)
// Todo In WSAssetTableViewController.h will need to replace rightBarButtonItem 'Done' with Chromecast icon
// 01-14-15 - Working at Flying Star on JT after Yoga.  1:00 pm - Added WSAssetPickerController and wired it up (1 hour)
// Adding UIImagePicker to UIView: http://stackoverflow.com/questions/1371446/how-to-add-uiimagepickercontroller-in-uiview
// Check the Google Cast design checklist:  https://developers.google.com/cast/docs/design_checklist#sender-control-end
// Not done: Create HTML5 tagged video page using filename to serve video
// Not done: Save video to local file with filepath
// Checking media type: http://stackoverflow.com/questions/6276351/how-to-capture-video-in-iphone
// Internet Media types: http://en.wikipedia.org/wiki/Internet_media_type
// Adding video handler.  First step setup capability: http://iphonedevsdk.com/forum/iphone-sdk-development/52628-kuttypeimage-undeclared-helpp.html
// Changed incrementing image identifier to Andrew's time based folder naming system
// Setting an update by changing the image pseudoname
// Noticed that the last image from local device is persistent.  Appears to be cached.
// Added buttons to force changes from video to image, locally and remotely
// 01-06-15 Had to create complete URL for image to load in Chromecast http://192.168.3.211/image.jpg
// Need to figure out how to load chromecast from image without extension
// Changed location of init chromecast code, refactored as startChromeCasting in delegate for picker controller (from button)
// Created new project to combine GCDWebServer with Chromecast code
// Removing handlers while the server is running is not allowed: http://cocoadocs.org/docsets/GCDWebServer/2.4/Classes/GCDWebServer.html
// Created custom methods to handle changes to media without restarting web server
// Not getting imagePicker (loading camera only)
// Corrected image/jpeg (from image/jpg) and now image loads correctly in target window
// W3 MIME Types: http://www.w3.org/Protocols/rfc1341/4_Content-Type.html
// PNG was rendering too slowly.  Converted to JPG and got it fast, but loaded in new browser window.  Checking MIME-Types for contentType flag.
// Changed server response to responseWithData from responseWithHTML (PNG)
// Converting uiimage to NSData: http://stackoverflow.com/questions/6476929/convert-uiimage-to-nsdata
// Added camera picker controller
// Moved server config and start code from AppDelegate to ViewController
// added GCDWebServer to project root (copied entire subfolder per instruction)
// Stream a local file to Chromecast: http://stackoverflow.com/questions/21631673/how-to-stream-a-local-file-to-the-chromecast

