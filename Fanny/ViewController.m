//
//  ViewController.m
//  Fanny
//
//  Created by Daniel Storm on 1/26/16.
//  Copyright © 2016 Daniel Storm. All rights reserved.
//  https://itunes.apple.com/us/developer/daniel-storm/id432169230?
//
//  Licensed under the GNU General Public License.
//  

#import "ViewController.h"

// Disable NSLog
#define NSLog(...)

@implementation ViewController {
    // NSTextField
    __weak IBOutlet NSTextField *instructionTextField;
    
    // NSImageView
    __weak IBOutlet NSImageView *iconImageView;

    // NSButton
    __weak IBOutlet NSButton *moreAppsButton;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"viewDidLoad");
    
    // Set instructions
    [instructionTextField setStringValue:@"To enable the Fanny Widget,\nplease open Notification Center,\nclick New/Edit (at the bottom), then click the\ngreen + icon to the right of Fanny."];
}

-(void)viewDidAppear {
    // Update style based on if user is using aqua or dark appearance
    [self updateStyle];
}

-(void)updateStyle {
    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] == nil) {
        // Aqua
        [self.view.window setTitlebarAppearsTransparent:true];
        self.view.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        
        NSVisualEffectView *visualEffectView = [[NSVisualEffectView alloc]initWithFrame: self.view.frame];
        visualEffectView.material = NSVisualEffectMaterialAppearanceBased;
        visualEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        visualEffectView.state = NSVisualEffectStateActive;
        [self.view addSubview:visualEffectView positioned:NSWindowBelow relativeTo:nil];
    }
    else {
        // Dark
        [self.view.window setTitlebarAppearsTransparent:true];
        self.view.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
        
        NSVisualEffectView *visualEffectView = [[NSVisualEffectView alloc]initWithFrame: self.view.frame];
        visualEffectView.material = NSVisualEffectMaterialAppearanceBased;
        visualEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        visualEffectView.state = NSVisualEffectStateActive;
        [self.view addSubview:visualEffectView positioned:NSWindowBelow relativeTo:nil];
    }
}

-(IBAction)moreAppsButton:(id)sender {
    NSLog(@"more apps button pressed");
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://itunes.apple.com/us/developer/daniel-storm/id432169230?iPhoneSoftwarePage=1#iPhoneSoftwarePage"]];
    [moreAppsButton setState:NSOffState];
}

-(void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

@end
