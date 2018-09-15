//
//  AppDelegate.m
//  Fanny
//
//  Created by Daniel Storm on 1/26/16.
//  Copyright © 2016 Daniel Storm. All rights reserved.
//  https://itunes.apple.com/us/developer/daniel-storm/id432169230?
//
//  Licensed under the GNU General Public License.
//  

#import "AppDelegate.h"
#import "ViewController.h"
#import "SMCWrapper.h"

// Disable NSLog
#define NSLog(...)

@interface AppDelegate () <NSMenuDelegate> {
    // SMC
    SMCWrapper *smc;
    
    // NSTimer
    NSTimer *updateStatsTimer;
    
    // NSMenuItem
    // CPU
    NSMenuItem *cpuTempMenuItem;
    // Fan
    NSMenuItem *fanNumberMenuItemDefault;
    NSMenuItem *fanRPMMenuItemDefault;
    NSMenuItem *fanTarMenuItemDefault;
    NSMenuItem *fanMinMenuItemDefault;
    NSMenuItem *fanMaxMenuItemDefault;
    
    // NSString
    NSString *osxMode;
    
    // NSColor
    NSColor *titleColor;
    NSColor *bodyColor;
}

@property (strong, nonatomic) NSStatusItem *statusItem;
@property (assign, nonatomic) BOOL darkModeOn;
@property(strong) NSWindowController *infoWindowController;

@end

@implementation AppDelegate

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"applicationDidFinishLaunching");
    
    // Check if in dark mode
    // If osxMode is nil then it isn't in dark mode, but if osxMode is @"Dark" then it is in dark mode.
    osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    
    if (!osxMode) {
        NSLog(@"Dark mode disabled");
        titleColor = [NSColor blackColor];
        bodyColor = [NSColor darkGrayColor];
    }
    else {
        NSLog(@"Dark mode enabled");
        titleColor = [NSColor whiteColor];
        bodyColor = [NSColor lightGrayColor];
    }
    
    // Status bar icon
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSImage *statusIcon = [NSImage imageNamed:@"fanIcon.png"];
    [statusIcon setTemplate:YES];
    _statusItem.image = statusIcon;
    
    // Create menu
    NSMenu *menu = [NSMenu new];
    
    // Menu labels
    cpuTempMenuItem = [NSMenuItem new];
    fanNumberMenuItemDefault = [NSMenuItem new];
    fanRPMMenuItemDefault = [NSMenuItem new];
    fanMinMenuItemDefault = [NSMenuItem new];
    fanMaxMenuItemDefault = [NSMenuItem new];
    fanTarMenuItemDefault = [NSMenuItem new];
    
    // Set default titles of labels
    [fanNumberMenuItemDefault setTitleWithMnemonic:@"Fan: #0"];
    [fanRPMMenuItemDefault setTitleWithMnemonic:@"Current: 0000 RPM"];
    [fanMinMenuItemDefault setTitleWithMnemonic:@"Min: 0000 RPM"];
    [fanMaxMenuItemDefault setTitleWithMnemonic:@"Max: 0000 RPM"];
    [fanTarMenuItemDefault setTitleWithMnemonic:@"Target: 0000 RPM"];
    [cpuTempMenuItem setTitleWithMnemonic:@"CPU: 0.0°C"];
    
    // Menu buttons
    NSMenuItem *moreApps = [[NSMenuItem alloc]initWithTitle:@"More Apps" action:@selector(moreAppsClicked:) keyEquivalent:@""];
    NSMenuItem *info = [[NSMenuItem alloc]initWithTitle:@"Info" action:@selector(infoClicked:) keyEquivalent:@""];
    NSMenuItem *quit = [[NSMenuItem alloc]initWithTitle:@"Quit" action:@selector(quitClicked:) keyEquivalent:@"q"];

    // Add items to menu
    [menu addItem:fanNumberMenuItemDefault]; // Fan number
    [menu addItem:fanRPMMenuItemDefault]; // Actual
    [menu addItem:fanMinMenuItemDefault]; // Minimum
    [menu addItem:fanMaxMenuItemDefault]; // Maximum
    [menu addItem:fanTarMenuItemDefault]; // Target
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:cpuTempMenuItem]; // CPU Temp
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:moreApps];
    [menu addItem:info];
    [menu addItem:quit];
    
    // Add menu to status bar
    _statusItem.menu = menu;
    
    // Create SMC
    smc = [SMCWrapper sharedWrapper];
    
    // Get stats timer
    [updateStatsTimer invalidate];
    updateStatsTimer = nil;
    updateStatsTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                        target:self
                                                      selector:@selector(getStats)
                                                      userInfo:nil
                                                       repeats:YES];
    
    // Create info window
    NSStoryboard *storyBoard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    self.infoWindowController = [storyBoard instantiateControllerWithIdentifier:@"infoWindow"];
    
    // Check if first run
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"firstRun"]) {
        // First run
        // Show info window
        [self.infoWindowController showWindow:self];
        
        // Update defaults
        [defaults setBool:YES forKey:@"firstRun"];
    }
}

-(void)infoClicked:(id)sender {
    [self.infoWindowController showWindow:self];
    [NSApp activateIgnoringOtherApps:YES];
}

-(void)moreAppsClicked:(id)sender {
    // Open Mac App Store
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"macappstore://itunes.apple.com/developer/daniel-storm/id432169230?mt=12&at=1l3vm3h&ct=FANNY"]];
}

-(void)quitClicked:(id)sender {
    [NSApp terminate:self];
}

-(void)getStats {
    // Setup NSUserDefaults
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"TodayExtensionSharingDefaults"];
    
    char key[5];
    float temperatureFloat = 0;
    
    // Clear menu
    _statusItem.menu = nil;
    NSMenu *menu = [NSMenu new];
    
    // Get number of fans
    NSNumber *numFans;
    int numberOfFans;
    [smc readKey:"FNum" intoNumber:&numFans];
    numberOfFans = [numFans intValue];
    
    // Set number of fans default
    [sharedDefaults setInteger:numberOfFans forKey:@"numberOfFans"];
    
    // Loop through each fan
    for (int i = 0; i < numberOfFans; i++) {
        
        // Stats and info
        NSString *fanID;
        NSNumber *fanRPM;
        NSNumber *tarRPM;
        NSNumber *minRPM;
        NSNumber *maxRPM;
        NSNumber *safeRPM;
        NSString *fanNumberDefault;
        
        // NSMenuItems
        NSMenuItem *fanNumberMenuItem = [NSMenuItem new];
        NSMenuItem *fanRPMMenuItem = [NSMenuItem new];
        NSMenuItem *fanMinMenuItem = [NSMenuItem new];
        NSMenuItem *fanMaxMenuItem = [NSMenuItem new];
        NSMenuItem *fanTarMenuItem = [NSMenuItem new];
        
        NSLog(@"\n\nFan #%d", i+1);
        
        // Set title of fan number menu label // Starts at 0 so add 1
        [fanNumberMenuItem setTitleWithMnemonic:[NSString stringWithFormat:@"Fan: #%d", i+1]];
        // Set title color
        NSDictionary *attributes = @{ NSFontAttributeName: [NSFont menuBarFontOfSize:14], NSForegroundColorAttributeName: titleColor };
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:[fanNumberMenuItem title] attributes:attributes];
        [fanNumberMenuItem setAttributedTitle:attributedTitle];
        // Add to menu
        [menu addItem:fanNumberMenuItem];
        
        // Fan ID
        // Usually NULL
        sprintf(key, "F%dID", i);
        if ( [smc readKey:key asString:&fanID] ){
            NSLog(@"Fan ID:\t %@\n", fanID);
        }
        
        // Actual Speed
        sprintf(key, "F%dAc", i);
        if ( [smc readKey:key intoNumber:&fanRPM] ){
            NSLog(@"Fan Speed (RPM):\t %@\n", fanRPM);
            fanNumberDefault = [NSString stringWithFormat:@"fan%dActual", i];
            [sharedDefaults setInteger:[fanRPM intValue] forKey:fanNumberDefault];
            
            // Set title of fan RPM menu label
            [fanRPMMenuItem setTitleWithMnemonic:[[NSString alloc] initWithFormat:@"Current: %d RPM", fanRPM]];
            // Set title color
            NSDictionary *attributes = @{ NSFontAttributeName: [NSFont menuBarFontOfSize:14], NSForegroundColorAttributeName: bodyColor };
            NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:[fanRPMMenuItem title] attributes:attributes];
            [fanRPMMenuItem setAttributedTitle:attributedTitle];
            // Add to menu
            [menu addItem:fanRPMMenuItem];
        }
        
        // Target Speed
        sprintf(key, "F%dTg", i);
        if ( [smc readKey:key intoNumber:&tarRPM] ){
            NSLog(@"Target Speed (RPM):\t %@\n", tarRPM);
            fanNumberDefault = [NSString stringWithFormat:@"fan%dTarget", i];
            [sharedDefaults setInteger:[tarRPM intValue] forKey:fanNumberDefault];
            
            // Set title of fan target menu label
            [fanTarMenuItem setTitleWithMnemonic:[[NSString alloc] initWithFormat:@"Target: %d RPM", tarRPM]];
            
            // Set title color
            NSDictionary *attributes = @{ NSFontAttributeName: [NSFont menuBarFontOfSize:12], NSForegroundColorAttributeName: bodyColor };
            NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:[fanTarMenuItem title] attributes:attributes];
            [fanTarMenuItem setAttributedTitle:attributedTitle];
            // Add to menu
            [menu addItem:fanTarMenuItem];
        }
        
        // Min Speed
        sprintf(key, "F%dMn", i);
        if ( [smc readKey:key intoNumber:&minRPM] ){
            NSLog(@"Min Speed (RPM):\t %@\n", minRPM);
            fanNumberDefault = [NSString stringWithFormat:@"fan%dMin", i];
            [sharedDefaults setInteger:[minRPM intValue] forKey:fanNumberDefault];
            
            // Set title of fan min menu label
            [fanMinMenuItem setTitleWithMnemonic:[[NSString alloc] initWithFormat:@"Min: %d RPM", minRPM]];
            // Set title color
            NSDictionary *attributes = @{ NSFontAttributeName: [NSFont menuBarFontOfSize:12], NSForegroundColorAttributeName: bodyColor };
            NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:[fanMinMenuItem title] attributes:attributes];
            [fanMinMenuItem setAttributedTitle:attributedTitle];
            // Add to menu
            [menu addItem:fanMinMenuItem];
        }
        
        // Max Speed
        sprintf(key, "F%dMx", i);
        if ( [smc readKey:key intoNumber:&maxRPM] ){
            NSLog(@"Max Speed (RPM):\t %@\n", maxRPM);
            fanNumberDefault = [NSString stringWithFormat:@"fan%dMax", i];
            [sharedDefaults setInteger:[maxRPM intValue] forKey:fanNumberDefault];
            
            // Set title of fan max menu label
            [fanMaxMenuItem setTitleWithMnemonic:[[NSString alloc] initWithFormat:@"Max: %d RPM", maxRPM]];
            // Set title color
            NSDictionary *attributes = @{ NSFontAttributeName: [NSFont menuBarFontOfSize:12], NSForegroundColorAttributeName: bodyColor };
            NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:[fanMaxMenuItem title] attributes:attributes];
            [fanMaxMenuItem setAttributedTitle:attributedTitle];
            // Add to menu
            [menu addItem:fanMaxMenuItem];
        }
        
        // Safe Speed
        // Usually NULL
        sprintf(key, "F%dSf", i);
        if ( [smc readKey:key intoNumber:&safeRPM] ){
            NSLog(@"Safe Speed (RPM):\t %@\n", safeRPM);
        }
        // Add separator
        [menu addItem:[NSMenuItem separatorItem]];
    }
    
    // Get temperature
    NSNumber *temp;
    if ( [smc readKey:"TC0P" intoNumber:&temp] ){
        NSLog(@"CPU Temperature:\t %@", [temp stringValue]);
        temperatureFloat = [temp floatValue];
        
        // Set temperature default
        [sharedDefaults setFloat:temperatureFloat forKey:@"temperature"];
        
        // Set title of CPU temp menu label
        [cpuTempMenuItem setTitleWithMnemonic:[NSString stringWithFormat:@"CPU: %.02f °C",[temp floatValue]]];
        // Set title color
        NSDictionary *attributes = @{ NSFontAttributeName: [NSFont menuBarFontOfSize:14], NSForegroundColorAttributeName: titleColor };
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:[cpuTempMenuItem title] attributes:attributes];
        [cpuTempMenuItem setAttributedTitle:attributedTitle];
        // Add to menu
        [menu addItem:cpuTempMenuItem];
        [menu addItem:[NSMenuItem separatorItem]];
    }
    
    // Create menu items
    NSMenuItem *moreApps = [[NSMenuItem alloc]initWithTitle:@"More Apps" action:@selector(moreAppsClicked:) keyEquivalent:@""];
    NSMenuItem *info = [[NSMenuItem alloc]initWithTitle:@"Info" action:@selector(infoClicked:) keyEquivalent:@""];
    NSMenuItem *quit = [[NSMenuItem alloc]initWithTitle:@"Quit" action:@selector(quitClicked:) keyEquivalent:@"q"];
    
    // Add menu items
    [menu addItem:moreApps];
    [menu addItem:info];
    [menu addItem:quit];
    
    // Update menu
    _statusItem.menu = menu;
    
    // Sync defaults
    [sharedDefaults synchronize];
}

-(void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
