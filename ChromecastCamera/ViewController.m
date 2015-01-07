//
//  ViewController.m
//  ChromecastCamera
//
//  Created by Chris Jungmann on 1/4/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import "ViewController.h"

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

// Camera Library
@property (strong, nonatomic) UIPopoverController *imagePickerPopover;

// Web Server
@property (strong, nonatomic) NSData *mediaData;
@property (strong, nonatomic) NSString *mediaType;

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
    
    // added CJ
    GCKFilterCriteria *filterCriteria = [[GCKFilterCriteria alloc] init];
    filterCriteria = [GCKFilterCriteria criteriaForAvailableApplicationWithID:@"898F3A9B"];
    self.deviceScanner.filterCriteria = filterCriteria;
    
    [self.deviceScanner addListener:self];
    [self.deviceScanner startScan];
    
    // configure image store
    self.mediaData = [[NSData alloc] init];
    // display the URL
    self.labelURL.text = [SharedWebServer.serverURL absoluteString];
    
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
    }
    // TODO: else handler
    
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
    
    //cast video
    [_mediaControlChannel loadMedia:mediaInformation autoplay:TRUE playPosition:0];
}

- (IBAction)buttonNewImage:(id)sender {
    
    
    
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

#pragma mark - Server Methods

- (void)webServerStart {
    
    NSLog(@"Starting Web Server");
    // Start server on port 8080
    [SharedWebServer startWithPort:80 bonjourName:nil];
    NSLog(@"Visit %@ in your web browser", SharedWebServer.serverURL);
    
    self.labelCast.text = @"Now Chromecasting";
    self.labelURL.text  = [SharedWebServer.serverURL absoluteString];
    
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
                                       
                                       NSLog(@"===> processBlock invoked");
                                       
                                       return [GCDWebServerDataResponse responseWithData:self.mediaData contentType:self.mediaType];
                                       
                                   }];
    
}

- (void)startChromeCasting {
    
    NSLog(@"Starting Chromecast");
    
    //Define Media metadata
    GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] init];
    
    [metadata setString:@"iOS Videos and Pictures" forKey:kGCKMetadataKeyTitle];
    
    [metadata setString:@"Chris tells the story of a ship sailing in a sea of mercury"
                 forKey:kGCKMetadataKeySubtitle];
    
    //    [metadata addImage:[[GCKImage alloc]
    //                        initWithURL:[[NSURL alloc] initWithString:@"http://commondatastorage.googleapis.com/"
    //                                     "gtv-videos-bucket/sample/images/BigBuckBunny.jpg"]
    //                        width:480
    //                        height:360]];
    
    [metadata addImage:[[GCKImage alloc]
                        initWithURL:[[NSURL alloc] initWithString:@"http://incaffeine.com/img/slides/slide-bg.jpg"]
                        width:480
                        height:360]];
    
    //define Media information
    //    GCKMediaInformation *mediaInformation =
    //    [[GCKMediaInformation alloc] initWithContentID:
    //     @"http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    //                                        streamType:GCKMediaStreamTypeNone
    //                                       contentType:@"video/mp4"
    //                                          metadata:metadata
    //                                    streamDuration:0
    //                                        customData:nil];
    
    GCKMediaInformation *mediaInformation =
    [[GCKMediaInformation alloc] initWithContentID:@"http://192.168.3.211/image1.jpg"
                                        streamType:GCKMediaStreamTypeNone
                                       contentType:@"image/jpeg"
                                          metadata:metadata
                                    streamDuration:0
                                        customData:nil];
    
    //cast video
    [_mediaControlChannel loadMedia:mediaInformation autoplay:TRUE playPosition:0];
    
}

- (void)updateChromeCasting {
    
    NSLog(@"Updating Chromecast");
    
    //Define Media metadata
    GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] init];
    
    [metadata setString:@"iOS Videos and Pictures" forKey:kGCKMetadataKeyTitle];
    
    [metadata setString:@"Chris tells the story of a ship sailing in a sea of mercury"
                 forKey:kGCKMetadataKeySubtitle];
    
    //    [metadata addImage:[[GCKImage alloc]
    //                        initWithURL:[[NSURL alloc] initWithString:@"http://commondatastorage.googleapis.com/"
    //                                     "gtv-videos-bucket/sample/images/BigBuckBunny.jpg"]
    //                        width:480
    //                        height:360]];
    
    [metadata addImage:[[GCKImage alloc]
                        initWithURL:[[NSURL alloc] initWithString:@"http://incaffeine.com/img/slides/slide-bg.jpg"]
                        width:480
                        height:360]];

    GCKMediaInformation *mediaInformation =
    [[GCKMediaInformation alloc] initWithContentID:@"http://192.168.3.211/image2.jpg"
                                        streamType:GCKMediaStreamTypeNone
                                       contentType:@"image/jpeg"
                                          metadata:metadata
                                    streamDuration:0
                                        customData:nil];
    
    //cast video
    [_mediaControlChannel loadMedia:mediaInformation autoplay:TRUE playPosition:0];
    
}


#pragma mark - Image Picker

// Your delegate object’s implementation of this method should pass the specified media on to any custom code that needs it, and should then dismiss the picker view.
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    // get image picked from image directory
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    
    NSLog(@"NSDictionary image info: %@", info);
    
    // process image based on type
    //    self.imageData = UIImagePNGRepresentation(image);
    self.imageViewIcon.image = image;
    
    self.mediaData = UIImageJPEGRepresentation(image, 0.2);
    self.mediaType = @"image/jpeg";
    
    // if server is already running, remove any previous handlers
    if (SharedWebServer.isRunning) {
        NSLog(@"-> TODO: Replace image");
        // Warning: Removing handlers while the server is running is not allowed
        //        [self webServerStop];
        //        [SharedWebServer removeAllHandlers];
        //        [self webServerAddHandlerForData:self.imageData type:@"image/jpeg"];
        //        [self webServerStart];
        
//        [_mediaControlChannel stop];
        // TODO: Replace with startChromCasting is it's not identical
        [self updateChromeCasting];
        
    } else {
        NSLog(@"-> Starting Web Server");
        [self webServerAddHandlerForData:self.mediaData type:@"image/jpeg"];
        [self webServerStart];
        
        [self startChromeCasting];
    }
    
    // now add handler for request
    //    [self webServerAddHandlerForData:self.imageData type:@"image/jpeg"];
    
    // blow away image picker
    //    [self dismissViewControllerAnimated:YES completion:nil];
    
    if (self.imagePickerPopover) {
        
        [self.imagePickerPopover dismissPopoverAnimated:YES];
        self.imagePickerPopover = nil;
        
    } else {
        
        [self dismissViewControllerAnimated:YES completion:nil];
        
    }
    
}



#pragma mark - Helper Methods

- (void)showError:(NSError *)error {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                    message:NSLocalizedString(error.description, nil)
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                          otherButtonTitles:nil];
    [alert show];
}


@end

// Try forcing an update by changing the image pseudoname
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

