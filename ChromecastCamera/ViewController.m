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

@property GCKMediaControlChannel *mediaControlChannel;
@property GCKApplicationMetadata *applicationMetadata;
@property GCKDevice *selectedDevice;
@property(nonatomic, strong) GCKDeviceScanner *deviceScanner;
@property(nonatomic, strong) UIButton *chromecastButton;
@property(nonatomic, strong) GCKDeviceManager *deviceManager;
@property(nonatomic, readonly) GCKMediaInformation *mediaInformation;

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
    
    //Define Media metadata
    GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] init];
    
    [metadata setString:@"Big Buck Bunny (2008)" forKey:kGCKMetadataKeyTitle];
    
    [metadata setString:@"Big Buck Bunny tells the story of a giant rabbit with a heart bigger than "
     "himself. When one sunny day three rodents rudely harass him, something "
     "snaps... and the rabbit ain't no bunny anymore! In the typical cartoon "
     "tradition he prepares the nasty rodents a comical revenge."
                 forKey:kGCKMetadataKeySubtitle];
    
    [metadata addImage:[[GCKImage alloc]
                        initWithURL:[[NSURL alloc] initWithString:@"http://commondatastorage.googleapis.com/"
                                     "gtv-videos-bucket/sample/images/BigBuckBunny.jpg"]
                        width:480
                        height:360]];
    
    //define Media information
    GCKMediaInformation *mediaInformation =
    [[GCKMediaInformation alloc] initWithContentID:
     @"http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
                                        streamType:GCKMediaStreamTypeNone
                                       contentType:@"video/mp4"
                                          metadata:metadata
                                    streamDuration:0
                                        customData:nil];
    
    //cast video
    [_mediaControlChannel loadMedia:mediaInformation autoplay:TRUE playPosition:0];
    
    
    // streaming local files:
    // http://stackoverflow.com/questions/21631673/how-to-stream-a-local-file-to-the-chromecast
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
