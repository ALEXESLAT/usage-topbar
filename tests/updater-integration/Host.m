#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>
#import <sys/stat.h>

// Dedicated fixture app only. Never linked into UsageTopbar or its production UI.
static NSString *scenario(void) { return [NSBundle.mainBundle objectForInfoDictionaryKey:@"FixtureScenario"]; }
static void record(NSString *event) {
    NSString *path=[NSBundle.mainBundle objectForInfoDictionaryKey:@"FixtureLog"];
    NSData *data=[[event stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    [handle seekToEndOfFile]; [handle writeData:data]; [handle closeFile];
}
@interface Harness : NSObject<NSApplicationDelegate,SPUUserDriver,SPUUpdaterDelegate>
@property(nonatomic,strong) SPUUpdater *updater;
@property(nonatomic,strong) NSTask *child;
@property(nonatomic) BOOL retried;
@end
@implementation Harness
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    NSString *version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    record([@"launched:" stringByAppendingString:version]);
    BOOL recovering = [NSProcessInfo.processInfo.arguments containsObject:@"--verify-recovery"];
    if ([scenario() hasPrefix:@"preferences-"] || [scenario() hasPrefix:@"recovery-"]) {
        NSTask *probe=[NSTask new];
        probe.executableURL=[NSBundle.mainBundle URLForResource:@"PreferencesProbe" withExtension:nil];
        probe.arguments=@[NSBundle.mainBundle.bundleIdentifier, ([version isEqualToString:@"21"] && !recovering) ? @"seed" : @"verify", ([scenario() isEqualToString:@"preferences-hidden"] || [scenario() hasPrefix:@"recovery-"]) ? @"hidden" : @"shown"];
        NSError *error=nil;
        if (![probe launchAndReturnError:&error]) { [self finish:@"preferences-probe-launch-failed"]; return; }
        [probe waitUntilExit];
        if (probe.terminationStatus != 0) { [self finish:@"preferences-failed"]; return; }
        record([@"preferences-preserved:" stringByAppendingString:version]);
    }
    if (recovering) { [self finish:@"manual-recovery-verified"]; return; }
    if ([scenario() isEqualToString:@"recovery-launch-failure"] && [version isEqualToString:@"22"]) {
        record(@"intentional-new-version-startup-exit"); exit(42);
    }
    if (([version isEqualToString:@"22"] || [version isEqualToString:@"23"])) { [self finish:@"relaunched-new-version"]; return; }
    self.child=[NSTask new]; self.child.executableURL=[NSURL fileURLWithPath:@"/bin/sleep"]; self.child.arguments=@[@"120"];
    [self.child launchAndReturnError:nil]; record([NSString stringWithFormat:@"owned-child:%d",self.child.processIdentifier]);
    self.updater=[[SPUUpdater alloc] initWithHostBundle:NSBundle.mainBundle applicationBundle:NSBundle.mainBundle userDriver:self delegate:self];
    self.updater.automaticallyChecksForUpdates=NO; self.updater.automaticallyDownloadsUpdates=NO; self.updater.sendsSystemProfile=NO;
    NSError *error=nil;
    if (![self.updater startUpdater:&error]) { [self finish:[@"start-error:" stringByAppendingString:error.description]]; return; }
    [self.updater checkForUpdates];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,45*NSEC_PER_SEC),dispatch_get_main_queue(),^{[self finish:@"timeout"];});
}
- (void)applicationWillTerminate:(NSNotification *)note {
    if (self.child.running) { [self.child terminate]; [self.child waitUntilExit]; }
    record(@"termination-cleanup");
}
- (void)finish:(NSString *)event { record(event); dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/5),dispatch_get_main_queue(),^{[NSApp terminate:nil];}); }
- (void)showUpdatePermissionRequest:(SPUUpdatePermissionRequest *)request reply:(void (^)(SUUpdatePermissionResponse *))reply { [self finish:@"unexpected-permission"]; }
- (void)showUserInitiatedUpdateCheckWithCancellation:(void (^)(void))cancel { record(@"manual-check"); if ([scenario() isEqualToString:@"cancel-check"]) { cancel(); [self finish:@"cancelled-check"]; } }
- (void)showUpdateFoundWithAppcastItem:(SUAppcastItem *)item state:(SPUUserUpdateState *)state reply:(void (^)(SPUUserUpdateChoice))reply {
    record([@"update-found:" stringByAppendingString:item.versionString]);
    if ([scenario() isEqualToString:@"cancel-offer"]) { reply(SPUUserUpdateChoiceDismiss); [self finish:@"cancelled-offer"]; }
    else reply(SPUUserUpdateChoiceInstall); // Explicit fixture-only consent.
}
- (void)showUpdateReleaseNotesWithDownloadData:(SPUDownloadData *)data { [self finish:@"unexpected-release-notes"]; }
- (void)showUpdateReleaseNotesFailedToDownloadWithError:(NSError *)error { [self finish:@"unexpected-release-notes-error"]; }
- (void)showUpdateNotFoundWithError:(NSError *)error acknowledgement:(void (^)(void))ack { record([NSString stringWithFormat:@"no-update:%ld",(long)error.code]); ack(); [self finish:@"no-update-finished"]; }
- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))ack { record([NSString stringWithFormat:@"updater-error:%@:%ld:%@",error.domain,(long)error.code,error.description]); ack();
    if ([scenario() isEqualToString:@"recovery-download"] && !self.retried) {
        self.retried=YES; record(@"old-version-kept-before-retry");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{[self.updater checkForUpdates];});
    } else { [self finish:@"error-finished"]; }
}
- (void)showDownloadInitiatedWithCancellation:(void (^)(void))cancel { record(@"download-start"); if ([scenario() isEqualToString:@"cancel-download"]) { cancel(); [self finish:@"cancelled-download"]; } }
- (void)showDownloadDidReceiveExpectedContentLength:(uint64_t)length {}
- (void)showDownloadDidReceiveDataOfLength:(uint64_t)length {}
- (void)showDownloadDidStartExtractingUpdate { record(@"extracting"); }
- (void)showExtractionReceivedProgress:(double)progress {}
- (void)showReadyToInstallAndRelaunch:(void (^)(SPUUserUpdateChoice))reply {
    record(@"ready-to-install");
    if ([scenario() isEqualToString:@"recovery-install-blocked"]) {
        if (chflags(NSBundle.mainBundle.bundlePath.fileSystemRepresentation, UF_IMMUTABLE) != 0) {
            [self finish:@"fault-injection-failed"]; return;
        }
        record(@"test-bundle-locked-after-extraction");
    }
    if ([scenario() isEqualToString:@"cancel-install"]) { reply(SPUUserUpdateChoiceSkip); [self finish:@"cancelled-install"]; }
    else reply(SPUUserUpdateChoiceInstall);
}
- (void)showInstallingUpdateWithApplicationTerminated:(BOOL)terminated retryTerminatingApplication:(void (^)(void))retry { record(@"installing"); }
- (void)showUpdateInstalledAndRelaunched:(BOOL)relaunched acknowledgement:(void (^)(void))ack { record(@"installed"); ack(); }
- (void)dismissUpdateInstallation { record(@"dismissed"); }
- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SPUUpdater *)updater { return NO; }
- (NSArray *)allowedSystemProfileKeysForUpdater:(SPUUpdater *)updater { return @[]; }
- (NSArray *)feedParametersForUpdater:(SPUUpdater *)updater sendingSystemProfile:(BOOL)sendingProfile { return @[]; }
- (BOOL)updater:(SPUUpdater *)updater shouldDownloadReleaseNotesForUpdate:(SUAppcastItem *)item { return NO; }
@end
int main(int argc,const char *argv[]) {
    @autoreleasepool { NSApplication *app=NSApplication.sharedApplication; Harness *delegate=[Harness new]; app.delegate=delegate; [app setActivationPolicy:NSApplicationActivationPolicyAccessory]; [app run]; }
    return 0;
}
