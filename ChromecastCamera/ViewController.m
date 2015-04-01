//
//  ViewController.m
//  ChromecastCamera
//
//  Created by Chris Jungmann on 1/4/15.
//  Copyright (c) 2015 Chris Jungmann. All rights reserved.
//

#import "ViewController.h"
#import "CCJImageEngine.h"
#import "CCJUserModel.h"

#import "HMSegmentedControl.h"

// changed to _kReceiverAppID
static NSString *const kReceiverAppID = @"898F3A9B";
//static NSString *const kReceiverAppID = @"F5A38776";

@interface ViewController () {
    
    UIImage *_btnImage;
    UIImage *_btnImageSelected;
}

// Chromecast
//@property NSString *kReceiverAppID;
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
@property (nonatomic, assign) NSUInteger pickerCounter;

// Used by NSTimer & Manual Mode
@property (nonatomic, strong) NSTimer *timerForShow;
@property (nonatomic, assign) NSUInteger mediaIndex;
@property (nonatomic, strong) NSString *mediaURL;
@property BOOL isOnModeForward;
@property BOOL isOnPlayActive;
@property BOOL isOnWaitingForChromecastStart;

// Used to randomize image order
@property (nonatomic, strong) NSArray *randomNumbersArray;

// User preferences
@property double timerSpeed;
@property BOOL isOnSwitchRandomize;
@property BOOL isOnSwitchRepeat;
@property BOOL isOnSwitchLandscape;

// iAd
@property (strong, nonatomic) ADBannerView *adBanner;

@end

@implementation ViewController

#pragma mark - Constants

// NSTimer based slideshow speeds in seconds
#define kTimerSlow      8.0
#define kTimerMedium    5.0
#define kTimerFast      3.0

// Background alpha changes
#define kBackgroundAnimationSpeed   1.0
#define kBackgroundSubtleAlpha      0.4
#define kBackgroundStrongAlpha      1.0

// Button alpha changes
#define kButtonAnimationSpeed       0.3
#define kButtonSubtleAlpha          0.3
#define kButtonStrongAlpha          1.0

// Chromecast screen size - hard-coding this but seems to be the default
#define kScreenWidth    1280
#define kScreenHeight   720

#pragma mark - View Methods

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
//    self.kReceiverAppID=kGCKMediaDefaultReceiverApplicationID;
    
    // set the status bar appearance
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
    
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
    
    // TODO: Debug
    /* So what the f?  When I change from Styled to Custom below I no longer see the device in my app on launch.  I moved the index.html file to dropbox and checked its properties.  */
    
    // prepare to Chromecast (Using Styled Media Receiver: 898F3A9B)
    // prepare to Chromecast (Using Custom Receiver: F5A38776)
    self.deviceScanner.filterCriteria = [GCKFilterCriteria criteriaForAvailableApplicationWithID:@"F5A38776"];
    
    // prepare to Chromecast (Using namespace 'castcam')
//    NSArray *nameSpaces = [[NSArray alloc] initWithObjects:@"castcam", nil];
//    self.deviceScanner.filterCriteria = [GCKFilterCriteria criteriaForRunningApplicationWithSupportedNamespaces:nameSpaces];
    
    [self.deviceScanner addListener:self];
    [self.deviceScanner startScan];
    
    // configure image store
    self.mediaData = [[NSData alloc] init];

    // configure array used to store processed data for each image
    self.mediaArray = [[NSArray alloc] init];
    
    // display the URL
//    self.labelURL.text = [SharedWebServer.serverURL absoluteString];
    
    // allocate the randomizing array
    self.randomNumbersArray = [[NSArray alloc] init];
    
    // set default image)
    UIImage *image = [UIImage imageNamed:@"chrome-cool.png"];
    self.imageViewShow.image = image;
    self.mediaData = UIImagePNGRepresentation(image);
    self.mediaType = @"image/jpeg";
    
    // consider moving this code to invoke web server only when Chromecast is being activated
    if (!SharedWebServer.isRunning) {
        [self webServerAddHandlerForData:self.mediaData type:self.mediaType];
        [self webServerStart];
    }
    
    // configure asset library and picker controller
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    self.assetsLibrary = library;
    self.pickerController = [[WSAssetPickerController alloc] initWithAssetsLibrary:library];
    self.pickerController.delegate = self;
    
    // set switch defaults
    self.timerSpeed = kTimerMedium;
    
    // set mode trackers to be used later
    self.isOnModeForward = YES;
    self.isOnPlayActive  = NO;
    self.isOnWaitingForChromecastStart = NO;
    
    // load switch settings from user model if able
//    [self restorePropertiesFromSharedUserModel];
    
    // iAd
    // implement global iAd process.
//    self.adBanner = [[ADBannerView alloc] init];
//    self.adBanner.delegate = self;
//    [self addADBannerViewToBottom];
    
    // used to keep track of picker controller
    self.pickerCounter = 0;
    
    // disble media control buttons until image picker had been selected
    [self disableMediaControlButtons];
    
    // set HMSegmentedControl
    [self configureSegmentedControls];
    
    // set image background alpha, will animate into view when running
    self.imageViewBackground.alpha = kBackgroundSubtleAlpha;
    
    // set GCDWebServer loggin to warnings and above only
    [GCDWebServer setLogLevel:3];
    
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
//    [self saveSharedUserModelUsingProperties];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    NSLog(@"MEMORY WARNING!");
    [self.timerForShow invalidate];
    self.timerForShow   = nil;
    
    // clear app's selections
    self.isOnPlayActive = NO;
    self.assetsLibrary  = nil;
    
    // update app UI
    [self updateMediaControlButtons];
    self.imageViewBackground.alpha = kBackgroundSubtleAlpha;
    
    // Chromecast app to stop
    [self.deviceManager leaveApplication];
    [self.deviceManager disconnect];
    [self updateButtonStates];
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
    // TODO: Handle this by stopping slideshow
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
            
            // Show play & forward buttons thick
//            UIImage *buttonPlay = [UIImage imageNamed:@"icon-play-highlight"];
//            [self.buttonStartStop setImage:buttonPlay forState:UIControlStateNormal];
//            
//            UIImage *buttonNext = [UIImage imageNamed:@"icon-next-highlight"];
//            [self.buttonNext setImage:buttonNext forState:UIControlStateNormal];
            
            [self configureContolButtonsAsThickIcons];
            
            
        } else {
            //Show cast button in disabled state
            [_chromecastButton setTintColor:[UIColor grayColor]];
            
//            UIImage *buttonPlay = [UIImage imageNamed:@"icon-play"];
//            [self.buttonStartStop setImage:buttonPlay forState:UIControlStateNormal];
//            
//            UIImage *buttonNext = [UIImage imageNamed:@"icon-next"];
//            [self.buttonNext setImage:buttonNext forState:UIControlStateNormal];
            
            [self configureControlButtonsAsThinIcons];
            
        }
    }
}

#pragma mark - Button & Selector Methods

- (void)configureSegmentedControls {
    
    // speed control
    
    self.hmsSegmentSpeed.sectionTitles = @[@"Slow", @"Mid", @"Fast"];
    self.hmsSegmentSpeed.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
    self.hmsSegmentSpeed.selectionIndicatorLocation = HMSegmentedControlSelectionIndicatorLocationDown;
    self.hmsSegmentSpeed.verticalDividerEnabled = YES;
    self.hmsSegmentSpeed.verticalDividerColor = [UIColor blackColor];
    self.hmsSegmentSpeed.verticalDividerWidth = 1.0f;
    self.hmsSegmentSpeed.backgroundColor = [UIColor clearColor];
    // set default speed position
    self.hmsSegmentSpeed.selectedSegmentIndex = 1;
    
    // randomize control
    
    self.hmsSegmentedRandom.sectionTitles = @[@"Straight", @"Random"];
    self.hmsSegmentedRandom.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
    self.hmsSegmentedRandom.selectionIndicatorLocation = HMSegmentedControlSelectionIndicatorLocationDown;
    self.hmsSegmentedRandom.verticalDividerEnabled = YES;
    self.hmsSegmentedRandom.verticalDividerColor = [UIColor blackColor];
    self.hmsSegmentedRandom.verticalDividerWidth = 1.0f;
    self.hmsSegmentedRandom.backgroundColor = [UIColor clearColor];
    
    // repeat control
    
    self.hmsSegmentedRepeat.sectionTitles = @[@"Once", @"Repeat"];
    self.hmsSegmentedRepeat.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
    self.hmsSegmentedRepeat.selectionIndicatorLocation = HMSegmentedControlSelectionIndicatorLocationDown;
    self.hmsSegmentedRepeat.verticalDividerEnabled = YES;
    self.hmsSegmentedRepeat.verticalDividerColor = [UIColor blackColor];
    self.hmsSegmentedRepeat.verticalDividerWidth = 1.0f;
    self.hmsSegmentedRepeat.backgroundColor = [UIColor clearColor];
    
    // landscape control
    
    self.hmsSegmentedLandscape.sectionTitles = @[@"Both", @"Landscape"];
    self.hmsSegmentedLandscape.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
    self.hmsSegmentedLandscape.selectionIndicatorLocation = HMSegmentedControlSelectionIndicatorLocationDown;
    self.hmsSegmentedLandscape.verticalDividerEnabled = YES;
    self.hmsSegmentedLandscape.verticalDividerColor = [UIColor blackColor];
    self.hmsSegmentedLandscape.verticalDividerWidth = 1.0f;
    self.hmsSegmentedLandscape.backgroundColor = [UIColor clearColor];
    
}


- (void)disableMediaControlButtons {
    
    // grey them out
    self.buttonStartStop.alpha  = kButtonSubtleAlpha;
    self.buttonBack.alpha       = kButtonSubtleAlpha;
    self.buttonPause.alpha      = kButtonSubtleAlpha;
    self.buttonNext.alpha       = kButtonSubtleAlpha;
    
    // disable them
    self.buttonStartStop.enabled    = NO;
    self.buttonBack.enabled         = NO;
    self.buttonPause.enabled        = NO;
    self.buttonNext.enabled         = NO;
}

// this enables the play and manual next image buttons
- (void)enableMediaControlButtons {
    
    // fill them in
    self.buttonStartStop.alpha  = kButtonStrongAlpha;
    self.buttonNext.alpha       = kButtonStrongAlpha;
    
    // enable them
    self.buttonStartStop.enabled    = YES;
    self.buttonNext.enabled         = YES;
}

- (void)updateMediaControlButtons {
    
    // check if can enable media buttons
    if ([self.mediaArray count] > 0) {
        
        // 02-07-15
//        // enable the corresponding buttons
//        [self enableMediaControlButtons];
        
        // Move this code here from buttonStartStop
        // enable and show pause
        self.buttonPause.alpha = kButtonStrongAlpha;
        self.buttonPause.enabled = YES;
        
        // hide the manual next button
        self.buttonNext.alpha = kButtonSubtleAlpha;
        self.buttonNext.enabled = NO;
        
        // hide the manual back button
        self.buttonBack.alpha = kButtonSubtleAlpha;
        self.buttonBack.enabled = NO;
        
        // change button icon to 'stop'
        [self.buttonStartStop setImage:[UIImage imageNamed:@"icon-stop-highlight"] forState:UIControlStateNormal];
        
        // set pause button back to 'pause' icon
        [self.buttonPause setImage:[UIImage imageNamed:@"icon-pause-highlight"] forState:UIControlStateNormal];
        
        // highlight the media button
        UIImage *buttonImage = [UIImage imageNamed:@"icon-picker-highlight"];
        [self.buttonShowLibrary setImage:buttonImage forState:UIControlStateNormal];
        
        // enable the corresponding buttons
        [self enableMediaControlButtons];
        
    } else {
        // show media button as thin lines (no images selected)
        UIImage *buttonImage = [UIImage imageNamed:@"icon-picker-highlight"];
        [self.buttonShowLibrary setImage:buttonImage forState:UIControlStateNormal];
        
        // disable media buttons
        [self disableMediaControlButtons];
    }
    
    // check if show is running so we can enable 'paws' button
    if (self.isOnPlayActive) {
        
        // show is running
        // disable the forward back and next buttons
        self.buttonPause.alpha      = kButtonSubtleAlpha;
        self.buttonPause.enabled    = NO;
        self.buttonNext.alpha       = kButtonSubtleAlpha;
        self.buttonNext.enabled     = NO;
        
        // enable the pause button
        self.buttonPause.alpha      = kButtonStrongAlpha;
        self.buttonPause.enabled    = YES;
        
    } else {
        
        // show is not running
        // disable the pause button
        self.buttonPause.alpha      = kButtonSubtleAlpha;
        self.buttonPause.enabled    = NO;
        // added 02-07-15
//        self.buttonNext.alpha       = kButtonSubtleAlpha;
//        self.buttonNext.enabled     = NO;
        
        // replace the 'stop' icon with 'run'
        UIImage *buttonImage = [UIImage imageNamed:@"icon-play-highlight"];
        [self.buttonStartStop setImage:buttonImage forState:UIControlStateNormal];
        
        // 03-25-15 noticed that 'next' button was thin after selecting images
        UIImage *buttonNext = [UIImage imageNamed:@"icon-next-highlight"];
        [self.buttonNext setImage:buttonNext forState:UIControlStateNormal];
        
        // enable the next button
        [self updateNextButtonUsingBounds];
        
    }
}

- (void)updateBackButtonUsingBounds {
    
    // backlimit based on mode
    NSUInteger backLimit = 0;
    if (self.isOnModeForward) {
        backLimit = 1;
    }
    
    // check back button
    if (self.mediaIndex <= backLimit) {
        self.buttonBack.alpha = kButtonSubtleAlpha;
        self.buttonBack.enabled = NO;
    } else {
        self.buttonBack.alpha = kButtonStrongAlpha;
        self.buttonBack.enabled = YES;
    }
}

- (void)updateNextButtonUsingBounds {
    
    // check next button
    // TODO: Improve the mediaIndex to account for any portrait images at end of a slideshow
    if (self.mediaIndex >= [self.mediaArray count]) {
        self.buttonNext.alpha = kButtonSubtleAlpha;
        self.buttonNext.enabled = NO;
    } else {
        self.buttonNext.alpha = kButtonStrongAlpha;
        self.buttonNext.enabled = YES;
    }
}


- (IBAction)buttonShowLibraryTouch:(id)sender {
    // show library as selected
    [self presentViewController:self.pickerController animated:YES completion:NULL];
}


- (IBAction)buttonStartStopTouch:(id)sender {
    
    // no matter what, check if the timer is running and if yes, stop the timer
    if ([self.timerForShow isValid]) {
        [self.timerForShow invalidate];
        self.timerForShow = nil;
    }
    
    // check if that a device is already selected
    if (self.selectedDevice == nil) {
        [self chooseDevice:self];
        self.isOnWaitingForChromecastStart = YES;
        return;
    }
    
    [self handlerForStartStopButton];
    
}

- (IBAction)buttonBackTouch:(id)sender {
    
    // first check is we are playing slideshow
    if ([self.timerForShow isValid]) {
        
        [self.timerForShow invalidate];
        self.timerForShow = nil;
    }
    
    // check if that a device is already selected
    if (self.selectedDevice == nil) {
        [self chooseDevice:self];
        return;
    }
    
    if (([self.mediaArray count] > 0) && (self.selectedDevice != nil)) {
        // backwards direction = FALSE
        [self manuallyDisplayNextImageFromUIImageArray:FALSE];
    }
}

- (IBAction)buttonPauseTouch:(id)sender {
    
    // first check is we are playing slideshow
    if ([self.timerForShow isValid]) {
        
        // stop timer to pause
        [self.timerForShow invalidate];
        self.timerForShow = nil;
        
        // change 'pause' button icon to 'play'
        UIImage *buttonImage = [UIImage imageNamed:@"icon-play-highlight"];
        [self.buttonPause setImage:buttonImage forState:UIControlStateNormal];
        
    } else {
        
        // change pause btton from 'play' icon to 'pause'
        UIImage *buttonImage = [UIImage imageNamed:@"icon-pause-highlight"];
        [self.buttonPause setImage:buttonImage forState:UIControlStateNormal];
        
        // restart timer without resetting index
//        [self displayImagesFromNSDataArray:self.mediaArray];
        [self displayImagesFromUIImageArray:self.mediaArray];

    }
}

- (IBAction)buttonNextTouch:(id)sender {
    
    // first check is we are playing slideshow
    if ([self.timerForShow isValid]) {
        
        [self.timerForShow invalidate];
        self.timerForShow = nil;
    }
    
    // check if that a device is already selected
    if (self.selectedDevice == nil) {
        [self chooseDevice:self];
        return;
    }
    
    // check if array is ready & cast device ready
    if (([self.mediaArray count] > 0) && (self.selectedDevice != nil)) {
        // forward direction = TRUE
        [self manuallyDisplayNextImageFromUIImageArray:TRUE];
    }
    
}


// Invoke Social Share features
- (IBAction)buttonSocialTouch:(id)sender {
    
    [self showSharingActivityView];
}


// segemt controls

- (void)hmsSegmentSpeedTouch:(id)sender {
    
    if (self.hmsSegmentSpeed.selectedSegmentIndex == 0) {
        self.timerSpeed = kTimerSlow;
        
    } else if (self.hmsSegmentSpeed.selectedSegmentIndex == 1) {
        self.timerSpeed = kTimerMedium;
        
    } else if (self.hmsSegmentSpeed.selectedSegmentIndex == 2) {
        self.timerSpeed = kTimerFast;
    }
    
    // stop the show
    if ([self.timerForShow isValid]) {
        [self.timerForShow invalidate];
        self.timerForShow = nil;
        
        // check if we're in a position to restart the show
        if (self.mediaIndex < [self.mediaArray count]) {
        
            // restart timer with new speed
            self.timerForShow = [NSTimer
                                 scheduledTimerWithTimeInterval:self.timerSpeed
                                 target:self
                                 selector:@selector(selectorForDisplayImagesTimer:)
                                 userInfo:self.mediaArray
                                 repeats:YES];
        }
    }

}

- (void)hmsSegmentRandomTouch:(id)sender {
    
    if (self.hmsSegmentedRandom.selectedSegmentIndex == 0) {
        self.isOnSwitchRandomize = NO;
    } else if (self.hmsSegmentedRandom.selectedSegmentIndex == 1) {
        self.isOnSwitchRandomize = YES;
    }
    
}

- (void)hmsSegmentRepeatTouch:(id)sender {
    
    if (self.hmsSegmentedRepeat.selectedSegmentIndex == 0) {
        self.isOnSwitchRepeat = NO;
    } else if (self.hmsSegmentedRepeat.selectedSegmentIndex == 1) {
        self.isOnSwitchRepeat = YES;
    }
    
}

- (void)hmsSegmentLandscapeTouch:(id)sender {
    
    if (self.hmsSegmentedLandscape.selectedSegmentIndex == 0) {
        self.isOnSwitchLandscape = NO;
    } else if (self.hmsSegmentedLandscape.selectedSegmentIndex == 1) {
        self.isOnSwitchLandscape = YES;
    }
    
}

// segmented controls

//- (void)segmentedControlChangedValue:(HMSegmentedControl *)segmentedControl {
//    NSLog(@"Selected index %ld (via UIControlEventValueChanged)", (long)segmentedControl.selectedSegmentIndex);
//}
//
//- (void)uisegmentedControlChangedValue:(UISegmentedControl *)segmentedControl {
//    NSLog(@"Selected index %ld", (long)segmentedControl.selectedSegmentIndex);
//    
//}


#pragma mark - GCKDeviceManagerDelegate

- (void)deviceManagerDidConnect:(GCKDeviceManager *)deviceManager {
    NSLog(@"deviceManagerDidConnect:!");
    [self updateButtonStates];
    [self.deviceManager launchApplication:kReceiverAppID];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
didConnectToCastApplication:(GCKApplicationMetadata *)applicationMetadata
            sessionID:(NSString *)sessionID
  launchedApplication:(BOOL)launchedApplication {
    
    NSLog(@"Cast application has launched");
    self.mediaControlChannel = [[GCKMediaControlChannel alloc] init];
    self.mediaControlChannel.delegate = self;
    [self.deviceManager addChannel:self.mediaControlChannel];
    [self.mediaControlChannel requestStatus];
    
    // handle previous cast request that may have been delayed
    if (self.isOnWaitingForChromecastStart) {
        self.isOnWaitingForChromecastStart = NO;
        // request slideshow start
        [self handlerForStartStopButton];
    } else {
        // not waiting, set background image
        [self showBackgroundCastImage];
    }
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
//    NSLog(@"mediaControlChannelDidUpdateMetadata");
    
}

- (void)mediaControlChannelDidUpdateStatus:(GCKMediaControlChannel *)mediaControlChannel {
//    NSLog(@"mediaControlChannelDidUpdateStatus:");
    
}

#pragma mark - GCDWebServer Methods

- (void)webServerStart {
    
    // Start server on port 80
    [SharedWebServer startWithPort:80 bonjourName:nil];
    NSLog(@"Web server started, visit %@", SharedWebServer.serverURL);
    
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

// customized method
- (void)updateChromecastWithTitle:(NSString *)title subTitle:(NSString *)subTitle imageURL:(NSString *)imageURL mediaURL:(NSString *)mediaURL contentType:(NSString *)type {
    
    //Define Media metadata
    GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] init];
    
    [metadata setString:title forKey:kGCKMetadataKeyTitle];
    [metadata setString:subTitle forKey:kGCKMetadataKeySubtitle];
    
    // changed 02-09-15 from imageURL
    [metadata addImage:[[GCKImage alloc]
                        initWithURL:[[NSURL alloc] initWithString:@"http://www.incaffeine.com/img/slides/slide-bg.jpg"]
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

// only used for testing purposes
- (void)testChromecast {

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
//    GCKMediaInformation *mediaInformation =
//    [[GCKMediaInformation alloc] initWithContentID:
//     @"http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
//                                        streamType:GCKMediaStreamTypeNone
//                                       contentType:@"video/mp4"
//                                          metadata:metadata
//                                    streamDuration:0
//                                        customData:nil];

//    // test with inCaffeine website image
    GCKMediaInformation *mediaInformation =
    [[GCKMediaInformation alloc] initWithContentID:
     @"http://www.incaffeine.com/img/slides/slide-bg.jpg"
                                        streamType:GCKMediaStreamTypeNone
                                       contentType:@"text/html"
                                          metadata:metadata
                                    streamDuration:0
                                        customData:nil];
    
    
    // test with Leemark HTML5, CSS, JavaScript (no JQuery) website image
//    GCKMediaInformation *mediaInformation =
//    [[GCKMediaInformation alloc] initWithContentID:
//     @"http://help.websiteos.com/websiteos/example_of_a_simple_html_page.htm"
//                                        streamType:GCKMediaStreamTypeNone
//                                       contentType:@"text/html"
//                                          metadata:metadata
//                                    streamDuration:0
//                                        customData:nil];
    
    // cast static image
//    GCKMediaInformation *mediaInformation =
//    [[GCKMediaInformation alloc] initWithContentID:
//     @"http://www.incaffeine.com"
//                                        streamType:GCKMediaStreamTypeNone
//                                       contentType:@"text/html"
//                                          metadata:metadata
//                                    streamDuration:0
//                                        customData:nil];
    
    
    //cast video
    [_mediaControlChannel loadMedia:mediaInformation autoplay:TRUE playPosition:0];
    
}

#pragma mark - WSAssetPickerController Delegates

- (void)assetPickerControllerDidCancel:(WSAssetPickerController *)sender
{
    // Dismiss the WSAssetPickerController.
    [self dismissViewControllerAnimated:YES completion:NULL];
}

// WSAssetPicker delegate
- (void)assetPickerController:(WSAssetPickerController *)sender didFinishPickingMediaWithAssets:(NSArray *)assets
{
    // Dismiss the WSAssetPickerController.
    [self dismissViewControllerAnimated:YES completion:^{
        // handle the assets here.
        self.mediaArray = assets;
        
        // update the UI
        [self updateMediaControlButtons];
    }];
    
    // increment picker counter used to create unique URL
    self.pickerCounter = self.pickerCounter + 1;
    
}


#pragma mark - Main Methods

// sets the TV image background as soon as the device connects
- (void)showBackgroundCastImage {
    
    // build image info from scratch, checking the server URL each time
    NSMutableString *mediaURL = [[NSMutableString alloc] init];
    if (SharedWebServer.serverURL) {
        [mediaURL appendString:[SharedWebServer.serverURL absoluteString]];
        
    } else {
        NSLog(@"Error catch: SharedWebServer.serverURL nil");
        return;
    }
    
    // prepare background image
    UIImage *image = [UIImage imageNamed:@"castground0.jpg"];
    
    self.mediaData = UIImageJPEGRepresentation(image, 0.7);
    self.mediaType = @"image/jpeg";
    
    //prepare local web server URL for image
    [mediaURL appendString:@"background0.jpg"];
    
    // update cast
    [self updateChromecastWithTitle:@"Image"
                           subTitle:@"from iPhone"
                           imageURL:@"http://incaffeine.com/img/slides/slide-bg.jpg"
                           mediaURL:[mediaURL copy]
                        contentType:self.mediaType];
    
}

- (void)handlerForStartStopButton {
    
    // toggle play on/off
    if (self.isOnPlayActive) {
        
        // we are in active play mode, so stop the show
        self.isOnPlayActive = NO;
        
        // change 'stop' icon to 'play', disable 'pause', enable 'next'
        [self updateMediaControlButtons];
        
        // change button icon to 'play'
        UIImage *buttonImage = [UIImage imageNamed:@"icon-play-highlight"];
        [self.buttonStartStop setImage:buttonImage forState:UIControlStateNormal];
        
        // change background alpha
        //            self.imageViewBackground.alpha = 0.0;
        [UIView animateWithDuration:kBackgroundAnimationSpeed animations:^{
            self.imageViewBackground.alpha = kBackgroundSubtleAlpha;
        }];
        
    } else {
        
        // we are hard stopped (not paused), let's start the show
        self.isOnPlayActive = YES;
        
        // check if array is ready & cast device ready
        if (([self.mediaArray count] > 0) && (self.selectedDevice != nil)) {
            
            // call method instead of doing all the above
            [self updateMediaControlButtons];
            
            // display first image without delay
            self.mediaIndex = 0;
            [self manuallyDisplayNextImageFromUIImageArray:YES];
            
            // set timed show to start after first image
            self.mediaIndex = 1;
            
            // call method that will NSTimer iterate and cast entire array
            [self displayImagesFromUIImageArray:self.mediaArray];
            
            // change background alpha
            [UIView animateWithDuration:kBackgroundAnimationSpeed animations:^{
                self.imageViewBackground.alpha = kButtonStrongAlpha;
            }];
            
        } else {
            NSLog(@"Error catch: Nothing to start playing, or device no selected");
        }
    }
}


- (void)displayImagesFromUIImageArray:(NSArray *)imageArray {
    
    if (!imageArray) {
        return;
    }
    
    if ([imageArray count] > 0) {
        
        // setup image counter incremented by NSTimer --> MOVED OUTSIDE METHOD
        //        self.mediaIndex = 0;
        
        // check if timer already running and invalidate if it is
        if ([self.timerForShow isValid]) {
            [self.timerForShow invalidate];
            self.timerForShow = nil;
        }
        
        // start timer to walk through all array items
        self.timerForShow = [NSTimer
                             scheduledTimerWithTimeInterval:self.timerSpeed
                             target:self
                             selector:@selector(selectorForDisplayImagesTimer:)
                             userInfo:self.mediaArray
                             repeats:YES];
        
    } else {
        // do nothing
        NSLog(@"Oops!  No image selected, don't invoke NSTimer");
    }
}

// Selector method called by NSTimer that dynamically processes images
- (void)selectorForDisplayImagesTimer:(NSTimer *)timer {

    NSLog(@"... selector counter: %lu", (unsigned long)self.mediaIndex);
    
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
        
        // get image picked from image directory
        UIImage *image;
        
        // ALAsset extractor moved here from loop in assetPicker delegate
        ALAsset *asset;
        
        // are we to randomize and ... can we?
        if ((self.isOnSwitchRandomize) && ([self.randomNumbersArray count] == [itemArray count])) {
            // in order to randomize we intermediate the index
            asset = itemArray[[self.randomNumbersArray[self.mediaIndex] intValue]];
            image = [UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage];
            
        } else {
            // use straight index
            asset = itemArray[self.mediaIndex];
            image = [UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage];
        }
        
        // check if landscape for image fit
        if (image.size.width > image.size.height) {
            // scale to fill
            CGSize newSize = CGSizeMake(kScreenWidth, kScreenHeight);
            image = [CCJImageEngine scaleImage:image toSize:newSize];
            
        } else {
            
            if (self.isOnSwitchLandscape) {
                
                BOOL foundLandscapeImage = FALSE;
                
                // loop through current position to next non-portrait image
                for (long i = self.mediaIndex; i < [itemArray count]; i++) {
                    
                    // get next image
                    if ((self.isOnSwitchRandomize) && ([self.randomNumbersArray count] == [itemArray count])) {
                        // in order to randomize we intermediate the index
                        asset = itemArray[[self.randomNumbersArray[i] intValue]];
                        image = [UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage];
                        
                    } else {
                        // use straight index
                        asset = itemArray[i];
                        image = [UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage];
                    }
                    // check image
                    if (image.size.width > image.size.height) {
                        // scale to fill
                        CGSize newSize = CGSizeMake(kScreenWidth, kScreenHeight);
                        image = [CCJImageEngine scaleImage:image toSize:newSize];
                        
                        foundLandscapeImage = TRUE;
                        // get out of for loop and show image
                        break;
                    }
                
                    self.mediaIndex = i;
                } // for loop
                
                // avoid showing the last image loaded if it's not landscape
                if (!foundLandscapeImage) {
                    return;
                }
                
            } // isOnSwitchLandscape
        } // width > height

        // if iPad, show the image locally
        self.imageViewShow.image = image;
        
        self.mediaData = UIImageJPEGRepresentation(image, 0.6);
        self.mediaType = @"image/jpeg";
        
        // start building the image name
        [mediaURL appendString:@"image"];
        // check if the URL needs to be unique
        if (self.isOnSwitchRepeat) {
            
            // URLs repeat so should be cacheable
            // first append the picker index
            [mediaURL appendString:[NSString stringWithFormat:@"%lu", (unsigned long)self.pickerCounter]];
            [mediaURL appendString:@"a"];
    
            if ((self.isOnSwitchRandomize) && ([self.randomNumbersArray count] == [itemArray count]) && (self.mediaIndex < [itemArray count])) {
                // we're repeating random images, so we use the random increment, necessary because of image caching
                [mediaURL appendString:[NSString stringWithFormat:@"%d",[self.randomNumbersArray[self.mediaIndex] intValue]]];
            } else {
                // we're repeating non-random images, so use simple increment
                [mediaURL appendString:[NSString stringWithFormat:@"%lu", (unsigned long)self.mediaIndex]];
            }
            
        } else {
            
            // set the URL's media index uniquely to avoid getting a cached image
            [mediaURL appendString:[NSString stringWithFormat:@"%d",(int)CFAbsoluteTimeGetCurrent()]];
        }

        [mediaURL appendString:@".jpg"];
        
        // update cast
        [self updateChromecastWithTitle:@"Image"
                               subTitle:@"from iPhone"
                               imageURL:@"http://incaffeine.com/img/slides/slide-bg.jpg"
                               mediaURL:[mediaURL copy]
                            contentType:self.mediaType];
        
        /*
        // animate screen background with fade-out/fade-in
        self.imageViewBackground.alpha = kBackgroundStrongAlpha;
        double fadeTime = self.timerSpeed - kBackgroundAnimationSpeed;
        NSLog(@"fade in time: %f", fadeTime);
        [UIView animateWithDuration:fadeTime animations:^{
            // first fade in
            self.imageViewBackground.alpha = kBackgroundSubtleAlpha;
//            [UIView animateWithDuration:kBackgroundAnimationSpeed animations:^{
//                // fade back out
//                self.imageViewBackground.alpha = kBackgroundStrongAlpha;
//            }];
        }];
         */
        
        
        [UIView animateWithDuration:kBackgroundAnimationSpeed animations:^{
            // fade in quickly
            self.imageViewBackground.alpha = kBackgroundStrongAlpha;
            
            double fadeTime = self.timerSpeed - kBackgroundAnimationSpeed - 0.75;
            NSLog(@"fade in time: %f", fadeTime);
            [UIView animateWithDuration:fadeTime animations:^{
                // first fade in
                self.imageViewBackground.alpha = kBackgroundSubtleAlpha;
            }];
    
        }];
        
        
    } else {
        NSLog(@"Oops! self.mediaIndex > [itemArray count]");
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
            // re-shuffle image order in case it's needed
            self.randomNumbersArray = [self createRandomArray:[itemArray count]];
            self.mediaIndex = 0;
        } else {
            // let's stop the timer and do not come back here if we're done
            NSLog(@"==> Done streaming");
            [self.timerForShow invalidate];
            self.timerForShow = nil;
            
            // reset media index in case user wants to manualy view images
            self.mediaIndex = 0;
            
            // let controler know that we're stopped
            self.isOnPlayActive = NO;
            
            // animate stop
            [UIView animateWithDuration:kBackgroundAnimationSpeed animations:^{
                self.imageViewBackground.alpha = kBackgroundSubtleAlpha;
            }];
            
            // change 'stop' icon to 'play', disable 'pause', enable 'next'
            [self updateMediaControlButtons];
        }
    }
}

//// more sophisticated selector
//- (void)selectorForTimerForShowFromNSDataArray:(NSTimer *)timer {
//    
//    // EXTRACT USERINFO
//    
//    // extract the info sent by timer & check it
//    NSArray *itemArray = [timer userInfo];
//    if (!itemArray) {
//        // [timer invalidate];
//        [self.timerForShow invalidate];
//        self.timerForShow = nil;
//        return;
//    }
//    
//    // CHECK WEB SERVER & GET URL TO BUILD
//    
//    // build image info from scratch, checking the server URL each time
//    NSMutableString *mediaURL = [[NSMutableString alloc] init];
//    if (SharedWebServer.serverURL) {
//        [mediaURL appendString:[SharedWebServer.serverURL absoluteString]];
//        
//    } else {
//        NSLog(@"Error catch: SharedWebServer.serverURL nil");
//        return;
//    }
//    
//    // WORK ON THE IMAGE & UPDATE CHROMECAST WITH IT
//    
//    // check media type
//    if (self.mediaIndex < [itemArray count]) {
//        
//        // are we to randomize and ... can we?
//        if ((self.isOnSwitchRandomize) && ([self.randomNumbersArray count] == [itemArray count])) {
//            
//            // in order to randomize we intermediate the index
//            self.mediaData = itemArray[[self.randomNumbersArray[self.mediaIndex] intValue]];
//            
//        } else {
//            // use straight index
//            self.mediaData = itemArray[self.mediaIndex];
//        }
//        
//        self.mediaType = @"image/jpeg";
//        
//        // start building the image name
//        [mediaURL appendString:@"image"];
//        // check if the URL needs to be unique
//        if (self.isOnSwitchRepeat) {
//            
//            // URLs repeat so should be cacheable
//            // first append the picker index
//            [mediaURL appendString:[NSString stringWithFormat:@"%lu",self.pickerCounter]];
//            [mediaURL appendString:@"a"];
//            
//            if ((self.isOnSwitchRandomize) && ([self.randomNumbersArray count] == [itemArray count])) {
//                
//                // we're repeating random images, so we use the random increment
//                [mediaURL appendString:[NSString stringWithFormat:@"%d",[self.randomNumbersArray[self.mediaIndex] intValue]]];
//                
//            } else {
//                // we're repeating non-random images, so use simple increment
//                [mediaURL appendString:[NSString stringWithFormat:@"%lu",self.mediaIndex]];
//            }
//            
//        } else {
//            
//            // set the URL's media index uniquely to avoid getting a cached image
//            [mediaURL appendString:[NSString stringWithFormat:@"%d",(int)CFAbsoluteTimeGetCurrent()]];
//        }
//        
//        [mediaURL appendString:@".jpg"];
//        
//        // UPDATE CHROMECAST
//        
//        // update cast
//        [self updateChromecastWithTitle:@"Image"
//                               subTitle:@"from iPhone"
//                               imageURL:@"http://incaffeine.com/img/slides/slide-bg.jpg"
//                               mediaURL:[mediaURL copy]
//                            contentType:self.mediaType];
//        
//    } else {
//        NSLog(@"Oop! Something's being naughty: no mediaData");
//    }
//    
//    // CHECK IF SHOULD TERMINATE
//    
//    // increment image index
//    self.mediaIndex = self.mediaIndex + 1;
//    
//    // check where we're at
//    if (self.mediaIndex >= [itemArray count]) {
//        
//        // are we supposed to repeat?
//        if (self.isOnSwitchRepeat) {
//            // keep streaming, starting back at first image.
//            NSLog(@"==> Restart streaming");
//            // re-shuffle image order
//            self.randomNumbersArray = [self createRandomArray:[itemArray count]];
//            self.mediaIndex = 0;
//        } else {
//            // let's stop the timer and do not come back here if we're done
//            NSLog(@"==> Done streaming");
//            [self.timerForShow invalidate];
//            self.timerForShow = nil;
//            
//            // reset media index in case user wants to manualy view images
//            self.mediaIndex = 0;
//            
//            // let controler know that we're stopped
//            self.isOnPlayActive = NO;
//            
//            // animate stop view
//            [UIView animateWithDuration:kBackgroundAnimationSpeed animations:^{
//                self.imageViewBackground.alpha = kBackgroundSubtleAlpha;
//            }];
//            
//            // change 'stop' icon to 'play', disable 'pause', enable 'next'
//            [self updateMediaControlButtons];
//        }
//    }
//}



- (void)manuallyDisplayNextImageFromUIImageArray:(BOOL)showNext {
    
    // check if we're to decrement first
    if (!showNext) {
        // check what we did last time we were here
        if (self.isOnModeForward) {
            // last time here we moved forward, so go back two
            if (self.mediaIndex > 1) {
                self.mediaIndex = self.mediaIndex - 2;
            }
        } else {
            // last time we were going backwards
            if (self.mediaIndex > 0) {
                self.mediaIndex = self.mediaIndex - 1;
            }
        }
        self.isOnModeForward = FALSE;
    } else {
        // handle unique case where we've moved back to beginning and image repeats
        if (!self.isOnModeForward && self.mediaIndex == 0) {
            self.mediaIndex = self.mediaIndex + 1;
        }
    }
    
    // build image info from scratch, checking the server URL each time
    NSMutableString *mediaURL = [[NSMutableString alloc] init];
    if (SharedWebServer.serverURL) {
        [mediaURL appendString:[SharedWebServer.serverURL absoluteString]];
        
    } else {
        NSLog(@"Error catch: SharedWebServer.serverURL nil");
        return;
    }
    
    // WORK ON THE IMAGE & UPDATE CHROMECAST WITH IT
    
    // check index bounds
    if (self.mediaIndex < [self.mediaArray count]) {
        
        UIImage *image;
        ALAsset *asset;
        
        // are we to randomize and ... can we?
        if ((self.isOnSwitchRandomize) && ([self.randomNumbersArray count] == [self.mediaArray count])) {
            
            // in order to randomize we intermediate the index
            asset = self.mediaArray[[self.randomNumbersArray[self.mediaIndex] intValue]];
            image = [UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage];
            
        } else {
            // use straight index
            
            asset = self.mediaArray[self.mediaIndex];
            image = [UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage];
        }
        
        // check image orientation
        if (image.size.width > image.size.height) {
            
            // scale to fill
            CGSize newSize = CGSizeMake(kScreenWidth, kScreenHeight);
            image = [CCJImageEngine scaleImage:image toSize:newSize];
            
        } else {
            
            if (self.isOnSwitchLandscape) {
                // skip this image
                return;
            }
        }
        
        // if iPad, show the image locally
        self.imageViewShow.image = image;
        
        self.mediaData = UIImageJPEGRepresentation(image, 0.5);
        self.mediaType = @"image/jpeg";
        
        // start building the image name
        [mediaURL appendString:@"image"];
        
        // set the URL's media index uniquely to avoid getting a cached image
        //        [mediaURL appendString:[NSString stringWithFormat:@"%d",(int)CFAbsoluteTimeGetCurrent()]];
        
        // checking to a straight indexed image to improve forward<->back performance
        // first append the picker index
        [mediaURL appendString:[NSString stringWithFormat:@"%lu",self.pickerCounter]];
        [mediaURL appendString:@"a"];
        
        // we're repeating non-random images, so use simple increment
        [mediaURL appendString:[NSString stringWithFormat:@"%lu",self.mediaIndex]];
        
        [mediaURL appendString:@".jpg"];
        
        // UPDATE CHROMECAST
        
        // update cast
        // Uncomment before ship & remove test
        [self updateChromecastWithTitle:@"Image"
                               subTitle:@"from iPhone"
                               imageURL:@"http://incaffeine.com/img/slides/slide-bg.jpg"
                               mediaURL:[mediaURL copy]
                            contentType:self.mediaType];
        
        // comment before ship
//        [self testChromecast];
        
        
    } else {
        NSLog(@"Catch! index exceeding bounds");
    }
    
    if (showNext) {
        self.isOnModeForward = TRUE;
        if (self.mediaIndex >= [self.mediaArray count]) {
            // we've trying to get past end of array
            return;
        } else {
            self.mediaIndex = self.mediaIndex + 1;
        }
    } else {
        self.isOnModeForward = FALSE;
    }
    
    // update buttons if necessary
    [self updateNextButtonUsingBounds];
    [self updateBackButtonUsingBounds];
    
}


#pragma mark - Helper Methods

- (void)configureControlButtonsAsThinIcons {
    
    UIImage *buttonPlay = [UIImage imageNamed:@"icon-play"];
    [self.buttonStartStop setImage:buttonPlay forState:UIControlStateNormal];
    
    UIImage *buttonBack = [UIImage imageNamed:@"icon-back"];
    [self.buttonBack setImage:buttonBack forState:UIControlStateNormal];
    
    UIImage *buttonPause = [UIImage imageNamed:@"icon-pause"];
    [self.buttonPause setImage:buttonPause forState:UIControlStateNormal];
    
    UIImage *buttonNext = [UIImage imageNamed:@"icon-next"];
    [self.buttonNext setImage:buttonNext forState:UIControlStateNormal];
    
}

- (void)configureContolButtonsAsThickIcons {
    
    UIImage *buttonPlay = [UIImage imageNamed:@"icon-play-highlight"];
    [self.buttonStartStop setImage:buttonPlay forState:UIControlStateNormal];
    
    UIImage *buttonBack = [UIImage imageNamed:@"icon-back-highlight"];
    [self.buttonBack setImage:buttonBack forState:UIControlStateNormal];
    
    UIImage *buttonPause = [UIImage imageNamed:@"icon-pause-highlight"];
    [self.buttonPause setImage:buttonPause forState:UIControlStateNormal];
    
    UIImage *buttonNext = [UIImage imageNamed:@"icon-next-highlight"];
    [self.buttonNext setImage:buttonNext forState:UIControlStateNormal];
    
}


// Created an array of NSData JPEG compressed images from UIImages array
// method also supports landscape aspect fill & skipping portrait images
- (NSArray *)createNSDataArrayFromUIImageArray:(NSArray *)imageArray {
    
    if (!imageArray) {
        return nil;
    }
    
//    NSUInteger itemCount = [imageArray count];
    NSMutableArray *imageArrayMutable = [[NSMutableArray alloc] initWithCapacity:[imageArray count]];
    
    for (int i = 0; i < [imageArray count]; i++) {
        
        UIImage *image;
        image = imageArray[i];
        
        // check image orientation
        if (image.size.width > image.size.height) {
            
            // scale to fill
            CGSize newSize = CGSizeMake(kScreenWidth, kScreenHeight);
            image = [CCJImageEngine scaleImage:image toSize:newSize];
            
        } else {
            
            if (self.isOnSwitchLandscape) {
                // skip this image
                continue;
            }
        }

        // compress image
//        mediaData = UIImageJPEGRepresentation(image, 0.5);
        // add to array
        [imageArrayMutable addObject:UIImageJPEGRepresentation(image, 0.5)];
    }
    
    return [imageArrayMutable copy];
    
}


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

//save SharedUserModel
- (void)saveSharedUserModelUsingProperties {
    
    // todo: update model
//    SharedUserModel.userSpeedySwitchOn   = self.isOnSwitchSpeed;
    SharedUserModel.userRandomSwitchOn   = self.isOnSwitchRandomize;
    SharedUserModel.userRepeatSwitchOn   = self.isOnSwitchRepeat;
    SharedUserModel.userLandcapeSwitchOn = self.isOnSwitchLandscape;
    
}

// restore from SharedUserModel
- (void)restorePropertiesFromSharedUserModel {
    
    // todo: update model
//    self.isOnSwitchSpeed        = SharedUserModel.userSpeedySwitchOn;
    self.isOnSwitchRandomize    = SharedUserModel.userRandomSwitchOn;
    self.isOnSwitchRepeat       = SharedUserModel.userRepeatSwitchOn;
    self.isOnSwitchLandscape    = SharedUserModel.userLandcapeSwitchOn;
    
    // set the switch states manually
    // todo: restore from used model
    if (self.hmsSegmentSpeed.selectedSegmentIndex == 0) {
        self.timerSpeed = kTimerSlow;
        
    } else if (self.hmsSegmentSpeed.selectedSegmentIndex == 1) {
        self.timerSpeed = kTimerMedium;
        
    } else if (self.hmsSegmentSpeed.selectedSegmentIndex == 2) {
        self.timerSpeed = kTimerFast;
    }
    
    if (self.isOnSwitchRandomize) {
        self.hmsSegmentedRandom.selectedSegmentIndex = 1;
    } else {
        self.hmsSegmentedRandom.selectedSegmentIndex = 0;
    }
    
    if (self.isOnSwitchRepeat) {
        self.hmsSegmentedRepeat.selectedSegmentIndex = 1;
    } else {
        self.hmsSegmentedRepeat.selectedSegmentIndex = 0;
    }
    
    if (self.isOnSwitchLandscape) {
        self.hmsSegmentedLandscape.selectedSegmentIndex = 1;
    } else {
        self.hmsSegmentedLandscape.selectedSegmentIndex = 0;
    }
}

#pragma mark - ADBanner delegates

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error {
    
    [self.adBanner setHidden:YES];
    
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
    
}

//This method adds shared adbannerview to the current view and sets its location to bottom of screen
//Should work on all devices

-(void) addADBannerViewToBottom
{
    self.adBanner.delegate = self;
    //Position banner just below the screen
    self.adBanner.frame = CGRectMake(0, self.view.bounds.size.height, 0, 0);
    //Height will be automatically set, raise the view by its own height
    self.adBanner.frame = CGRectOffset(self.adBanner.frame, 0, -self.adBanner.frame.size.height -self.tabBarController.tabBar.frame.size.height);
    [self.view addSubview:self.adBanner];
    
}

-(void) addADBannerViewToTop
{
    self.adBanner.delegate = self;
    //Position banner just below the top status bar
    self.adBanner.frame = CGRectMake(0, 0, 0, 0);
    //Height will be automatically set, lower the view by its own height
    self.adBanner.frame = CGRectOffset(self.adBanner.frame, 0, +self.adBanner.frame.size.height/2.8);
    [self.view addSubview:self.adBanner];
    
}


-(void) removeADBannerView
{
    self.adBanner.delegate = nil;
    [self.adBanner removeFromSuperview];
}


@end

// FUTURE VERSION:
// feature - Allow 'select all' in media picker if feasable

// CURRENT VERSION:
// todo - Test app's response to 'Received notification that device disconnected'
// todo - Check why had to background and re-enter app in order to see Chromecast option
// todo - Update 'next' button to hidden when switching to landscape only from portrait during manual view
// todo - Convert images to movie with image fade-ins

// 04-01-15 - Adding WatchKit
// 03-25-15 - Set device background to pulse gradually based on timer speed
// 03-25-15 - Set buttons to thin on Chrome disconnect, thick on reconnect
// 03-25-15 - Fixed 'next' button no highlighted.  Refactored code to highlight/thin buttons.
// 03-25-15 - Installed and set a background image to display on Cast start
// 03-23-15 - Set up background image alpha to pulse animated on each image transition
// 03-23-15 - Set up Play and Next button to be thin when device is not connected
// 03-21-15 - Changed buttons to highlighted state for better visibility
// 03-21-15 - Fixed some autolayout constraint errors
// 03-20-15 - Set up a Custom Receiver in HTML and loaded on incaffeine.com
// consider - Set up and test GCDWebServer to play movies (as files?) https://github.com/swisspol/GCDWebServer/issues/66
// todo - Test Chromecast Default Receiver
// 02-09-15 - Test during extended runtime using instruments to watch for memory leaks, CPU usage
// 02-09-15 - Evaluate using HTML5 for image transitions VS creating a movie file.  Looks like I need to create own receiver http://stackoverflow.com/questions/23800651/chromecast-ios-stream-html-content (1.75 hours 09:00 - 10:45)
// 02-08-15 - Beta testing reveals viewers dislike image transitions to black screen. (0.5 hours)
// 02-07-15 - Hide manual 'next' button when starting slideshow from 'buttonStartStop'. (0.5 h + ___ 09:15--9:45)
// 02-07-15 - Set up Autolayout presentations for iPads (1.0 hours - 08:15-09:15)
// 02-03-15 - Resolve Auto Layout landscape presentation (2.75 + ___ hours = 09:45-12:30, 15:00-)  
// 01-31-15 - debug: Find why I'm displaying one portrait image, while others are being squelched. (0.25 h = 19:45-20:00)
// 01-31-15 - debug: Caught another 'NSRangeException' occurence. 'Fast''Random'Repeat''Landscape'.  Traced, found and remediated. (0.5 h 18:45-19:15)
// 01-31-15 - Modify code to show first slide without delay (0.25 h = 18:15-18:30)
// 01-31-15 - Final cleanup of comments and any loitering NSLogs (0.5 h = 17:15-17:45)
// 01-31-15 - Testing response to 'didReceiveMemoryWarning' conditions. (0.75 hours = 16:30-17:15)
// 01-31-15 - Testing: Debug: "'NSRangeException', reason: '*** -[__NSArrayI objectAtIndex:]: index 7 beyond bounds" when switched from 'slow' to 'fast' while in 'repeat'+''random' slideshow view. (0.5 hours 16:00-16:30)
// 01-31-15 - Testing: Debug: Found landscape only pauses on portrait images (0.75 hours 10:15-11:00)
// 01-31-15 - Cleaned up some loose ends in UISwitch to Segmented Control conversion (0.5 hours 9:45-10:15)
// 01-31-15 - Debug: On buttonStart without first Chromecasting not playing after Chromecast start.  Also removed iAd, and updated layout. (0.75 hours - 09:00-9:45)
// 01-31-15 - Animate background alpha on start/stop (0.5 hours 08:30-09:00
// 01-30-15 - Convert UISwitch and test connections moved to HMSSegmentedControl (19:45-
// 01-30-15 - Implement HMSegmentedControl (16:15-18:00)
// 01-30-15 - Review open source options for UISwitches and Segmented Controls with better interfaces (1.0 hours - 13:30-14:30)
// 01-30-15 - Upload completed artwork to iTunes Connect and write app descriptions, URLs etc (1.0 hours 08:30-9:30)
// 01-30-15 - Revised app icons for better contrast and used makeappicon.com to set sizes. (0.5 hours 08:00-08:25)
// 01-29-15 - Learning different best practices to configure Launch images in their own storyboard (0.75 hours - 19:00 - 19:45)
// 01-29-15 - Purchased prefered image and formatted to 2x, 3x for background, prepared app icons. (4.5 hours - 12:30-5:00)
// 01-28-15 - Downloaded images from Dreamstime for background image and app colors (1.0 hours)
// 01-28-15 - Complete Wenderlich's Beginning AutoLayout Video Tutorial (0.5 hours - 3:30-4:00)
// 01-28-15 - Changed design to access image reference from outside of imagePicker, and ran test with 264 images. (0.75 hours 7:30-8:15)
// 01-27-15 - Looked at using file-system; http://stackoverflow.com/questions/16050393/memory-issue-when-using-large-nsarray-of-uiimage
// 01-27-15 - Critical Debug: Memory force close again when selected 189 images. Researching solutions. (8:30-9:15)
// 01-27-15 - Rewrite methods that do in-delay processing.  New methods process UIImage array instead of NSData array (1.75 hours - 6:30 - 8:15)
// 01-27-15 - Test pre-processing when more than 'n' images have been selected.  Noted large memory buildup, then release if no crash happens. (1 hour - 5:30-6:30)
// 01-27-15 - Static 'Analyze' found 'dead stores'. (0.75 hours - 4:00 - 4:45)
// 01-27-15 - Static 'Analyze' found multiple "Potential null dereference" in GCDWebServer (1 hours - 1:30 - 2:30)
// 01-27-15 - Handle WSAssetTableViewController deprecations (0.5 hours 1:00-1:30)
// 01-27-15 - Important: If selecting 'play', or 'next' but not connected, bring up Chromecast devices (0.25 hours - 8:30-8:45)
// todo - Debug: Picked 76+ images.  Crashed app due to memory error.
// 01-26-15 - Clean up NSLog statements (0.25 hours - 3:45-4:00)
// 01-26-15 - Clean up code TODOs (0.25 hours - 3:30-3:45)
// 01-26-15 - Debug: When manually back to first slide, pressing 'next' redisplays same slide (0.2 hours - 3:10-3:20)
// 01-26-15 - Debug: Noticed that when 'repeat' switch is selected image index is not simple in the manual mode, but it is in slideshow mode. (0.5 hours - 2:45-3:10)
// 01-26-15 - Wire boolean tracker when play button is "active", since pause stops NSTimer.  Refactored method with better logic in discrete method (1:50-2:40)
// 01-26-15 - Debug: When pressing 'pause' button, should replace 'pause' with play & enable restart (0.5 hours = 1:20-1:50)
// 01-26-15 - Debug: Stopping a running slideshow does not remove the pause button and display 'next' button.  This is done Ok, when slideshow ends normally though. (5 minutes 1:15-1:20)
// 01-23-15 - Debug buttons:  Only show back button when index == 1 (2:15-3:00)
// 01-23-15 - Test the new buttons, start/stop, pause, back, forward. (12:30-2:00)
// 01-23-15 - Setup buttons to be greyed out when their functions are not enabled (11:30-12:15)
// 01-23-15 - Reset button constraints in Autolayout (11:00-11:30)
// 01-23-15 - BackToDrawingBoard: Review and revise method to set alpha on an (IBAction)button (9:30-10:15)
// 01-23-15 - Add graphics assets in place of buttons on UI into xcassets sets (8:30-9:30)
// 01-22-15 - New bug [UIImage length] unrecognized selector.  Found wrong return: (0.1)
// 01-22-15 - Had to refactor control methods to allow manual stepping through images (6:00-8:30)
// 01-22-15 - Wire the new stop-start, pause, forward, back switches (5:30-6:00)
// 01-22-15 - Background-image, edited photo from SnowAwesome archives (3:45-4:45)
// 01-22-15 - Look & Feel.  Making background image, and added UIImage in IB. (2:30-3:45)
// 01-22-15 - UI Redesign Work on look & feel using Auto Layout.  A struggle! (12:00 - 2:45)
// 01-22-15 - Add buttons to manually control slideshow, pause, forward, back (9:00 - 9:30)
// 01-21-15 - Set switches from CCJUserModel preferences on launch: UNABLE TO DEBUG (3:20 - 4:05)
// 01-21-15 - Add switchLandscape to CCJUserModel for serialization (3:15 - 3:20)
// 01-21-15 - When in repeat mode, don't reprocess images.  Just loop through the URLs.  Redoing logic using a method to pre-process images.  (1.5 hours / 1:45 - 3:15)
// 01-21-15 - Add landscape only option button (Added as part of rewrite above)
// 01-21-15 - Getting old images: Add a 'run counter' incremented in didFinishPickingMedia to image URL (0.5 hour - 9:30-10:00)
// 01-21-15 - Test new method that processes image after Chromecast update (8:45 - 9:30)
// 01-20-15 - Added switchLandscape to show only landscape images (7:45 - 8:15)
// 01-20-15 - Look to buffer the image for the next display cycle, one ahead. (2h 3:30-4:30, 6:30-7:30)
// 01-20-15 - Noticed difference in load speeds of landscape VS portrait images possibly due to aspect fill routine slowing landscape load.
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
// 01-15-15 - What happened to the Chromecast icon?  My UIImage covered it. Duh! (0.10 hours)
// 01-14-15 - Wire speed switch to timer.  Wow Ringo by Joris Voorn is insane perfect!  (4:45 pm - Completed control for switchSpeed.  Took 1:15 hours)
// 01-14-15 - Loop array of UIImages with a timer.  http://stackoverflow.com/questions/1449035/how-do-i-use-nstimer Got it woking with NSTime (Done at 3:15 using 0.75 hours)
// 01-14-15 - Cast first image from new picker array 2:29 pm while in the groove with Rachel Row - Follow The Step (Justin Martin Remix) - Deep House!  (2.5 hours to this point)
// 01-14-15 - Wire up array of image URLs being select and convert them to array of UIImage (2 hours - as of 14:15)
// In WSAssetTableViewController.h will need to replace rightBarButtonItem 'Done' with Chromecast icon
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
// 01-04-15 - Created project
//
/* 
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
 */


