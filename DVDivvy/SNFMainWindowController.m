//
//  SNFEpisodeSlicer.m
//  DVDivvy
//
//  Created by Chris Adamson on 9/20/13.
//  Copyright (c) 2013 Subsequently & Furthermore, Inc. CC0 License - http://creativecommons.org/about/cc0//

#import "SNFMainWindowController.h"
#import <AVFoundation/AVFoundation.h>
#import "SNFExportDivvy.h"
#import "SNFExportDivvyDelegate.h"

#define PROGRESS_TIMER_INTERVAL 0.5
#define PLAYER_TIMER_INTERVAL 0.037

@interface SNFMainWindowController() <SNFExportDivvyDelegate>
@property (nonatomic, strong) NSMutableArray *sliceTimes;

@property (weak) IBOutlet NSView *playerView;
@property (weak) IBOutlet NSSlider *scrubSlider;
@property (weak) IBOutlet NSTextField *currentTimeLabel;
@property (weak) IBOutlet NSTableView *sliceTable;
@property (weak) IBOutlet NSTextField *exportDestinationLabel;
@property (weak) IBOutlet NSProgressIndicator *exportProgressIndicator;
@property (weak) IBOutlet NSButton *removeSliceButton;
@property (weak) IBOutlet NSButton *exportButton;
@property (weak) IBOutlet NSTableColumn *tableColumnSliceNumber;
@property (weak) IBOutlet NSTableColumn *tableColumnSliceTime;
@property (weak) IBOutlet NSTableColumn *tableColumnEpisodeDuration;
@property (strong) NSTimer *progressTimer;

@property (strong) AVPlayer *player;
@property (strong) AVPlayerLayer *playerLayer;

@property (strong) NSURL *assetURL;
@property (strong) NSURL *exportDirectoryURL;

@property (strong) SNFExportDivvy *divvy;


- (IBAction)handleBackFrameTapped:(NSButton *)sender;
- (IBAction)handleForwardFrameTapped:(NSButton *)sender;
- (IBAction)handleAddSliceTapped:(id)sender;
- (IBAction)handleRemoveSliceTapped:(NSButton *)sender;
- (IBAction)handleExportButtonTapped:(id)sender;
@property (weak) IBOutlet NSButton *playPauseButton;
- (IBAction)handlePlayPauseTapped:(id)sender;

@property (strong) id playerPeriodicListener;
@property (strong) id playerExtremesListener;

@end

@implementation SNFMainWindowController

-(void) awakeFromNib {
	// didn't realize this would be called multiple times (and windowDidLoad is *never* called)
	// b/c my window and controller are both in MainMenu.xib. maybe I should put window in its
	// own nib.
	if (!self.sliceTimes) {
		self.sliceTimes = [[NSMutableArray alloc] init];
	}
	self.playerView.layer.backgroundColor = [[NSColor blackColor] CGColor];
}


#pragma mark table stuff
-(NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
	if (! self.player) {
		return 0;
	} else {
		return [self.sliceTimes count] + 1;
	}
}

-(NSView*) tableView:(NSTableView *)tableView
  viewForTableColumn:(NSTableColumn *)tableColumn
				 row:(NSInteger)row {
	NSTableCellView *cell = nil;

	// rows are segments. slice times are dividers between segments.
	// last row is duration minus last slice time.
	
	if (tableColumn == self.tableColumnSliceNumber) {
		cell = [tableView makeViewWithIdentifier:@"EpisodeDurationCell" owner:self];
		[cell.textField setIntegerValue:row + 1];
	} else if (tableColumn == self.tableColumnSliceTime) {
		cell = [tableView makeViewWithIdentifier:@"SliceTimeCell" owner:self];
		CMTime sliceTime = kCMTimeZero;
		if (row > 0) {
//			NSValue *timeValue = self.sliceTimes[row - 1];
//			[timeValue getValue:&sliceTime];
			sliceTime = [self.sliceTimes[row-1] CMTimeValue];
		 }
		[cell.textField setStringValue:[self stringForTime:sliceTime]];

	} else if (tableColumn == self.tableColumnEpisodeDuration) {
		cell = [tableView makeViewWithIdentifier:@"EpisodeDurationCell" owner:self];
		[cell.textField setStringValue:@"bar"];

		CMTime firstSliceTime = kCMTimeZero;
		CMTime secondSliceTime = self.player.currentItem.duration;
		if (row > 0) {
			firstSliceTime = [self.sliceTimes[row-1] CMTimeValue];
		}
		if (row < [self.sliceTimes count]) {
			if ([self.sliceTimes count] > 0) {
				secondSliceTime = [self.sliceTimes[row] CMTimeValue];
			}
		}
		
		firstSliceTime.value *= -1;
		CMTime duration = CMTimeAdd(secondSliceTime, firstSliceTime);
		
		[cell.textField setStringValue:[self stringForTime:duration]];

	}
	
	return cell;
}

-(void) sortSliceTimes {
	[self.sliceTimes sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		NSValue *value1 = (NSValue*) obj1;
		NSValue *value2 = (NSValue*) obj2;
		CMTime time1 = [value1 CMTimeValue];
		CMTime time2 = [value2 CMTimeValue];
		int32_t comparison = CMTimeCompare(time1, time2);
		if (comparison == 0) {
			return NSOrderedSame;
		} else if (comparison < 0) {
			return NSOrderedAscending;
		} else {
			return NSOrderedDescending;
		}
	}];
}

#pragma mark button handlers

- (IBAction)handleBackFrameTapped:(id)sender {
	CMTime frameTime = CMTimeMakeWithSeconds(-1.0/30.0, self.player.currentItem.duration.timescale);
	CMTime backwardTime = CMTimeAdd([self.player.currentItem currentTime], frameTime);
	[self.player seekToTime:backwardTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
	[self refreshCurrentTimeLabel];
}

- (IBAction)handleForwardFrameTapped:(id)sender {
	CMTime frameTime = CMTimeMakeWithSeconds(1.0/30.0, self.player.currentItem.duration.timescale);
	CMTime forwardTime = CMTimeAdd([self.player.currentItem currentTime], frameTime);
	[self.player seekToTime:forwardTime  toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
	[self refreshCurrentTimeLabel];
}

- (IBAction)handleAddSliceTapped:(id)sender {
	
	CMTime currentTime = self.player.currentTime;
	NSValue *currentTimeValue = [NSValue valueWithCMTime:currentTime];
	[self.sliceTimes addObject:currentTimeValue];
	[self sortSliceTimes];
		
	[self.sliceTable reloadData];
}

- (IBAction)handlePlayPauseTapped:(id)sender {
	if (!self.player) {
		return;
	}
	if ([self.playPauseButton state] == NSOnState) {
		// if at end, return to zero before playing
		if (CMTimeCompare(self.player.currentItem.duration, self.player.currentTime) == 0) {
			[self.player.currentItem seekToTime:kCMTimeZero];
		}
		[self.player play];
	} else {
		[self.player pause];
	}
}


- (IBAction)handleRemoveSliceTapped:(NSButton *)sender {
	// can't delete w/no selection
	// can't delete row 0
	NSInteger selectedRow = [self.sliceTable selectedRow];
	if (selectedRow < 1) {
		return;
	}
	// can't delete if only one row
	if ([self.sliceTimes count] == 0)  {
		return;
	}
	
	NSIndexSet *removalSet = [NSIndexSet indexSetWithIndex:selectedRow];
	[self.sliceTable removeRowsAtIndexes:removalSet withAnimation:NSTableViewAnimationSlideUp];
	[self.sliceTimes removeObjectAtIndex:selectedRow];
	[self.sliceTable reloadData];
	
}

- (IBAction)handleSliderAction:(NSSlider *)slider {
	NSLog (@"slider now %f", [slider floatValue]);
	CMTime scrubTime = CMTimeMake([slider intValue], self.player.currentItem.duration.timescale);
	[self.player seekToTime:scrubTime];
	[self refreshCurrentTimeLabel];
}

-(void) keyDown:(NSEvent *)theEvent {
	NSString *characters = [theEvent characters];
	BOOL handled = NO;
	if (characters && [characters length] > 0) {
		unichar theKey = [characters characterAtIndex:0];
		if (theKey == NSRightArrowFunctionKey) {
			[self handleForwardFrameTapped:nil];
			handled = YES;
		} else if (theKey == NSLeftArrowFunctionKey) {
			[self handleBackFrameTapped:nil];
			handled = YES;
		}
	}
	if (! handled) {
		[super keyDown:theEvent];
	}
}

#pragma mark open movie file
-(BOOL) openURL:(NSURL *)url {
	self.assetURL = url;
	self.asset = [AVURLAsset URLAssetWithURL:url
									 options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @(YES)}];

	// destroy old player and observers
	[self.player removeTimeObserver:self.playerPeriodicListener];
	[self.player removeTimeObserver:self.playerExtremesListener];
	
	// create player
	self.player = [AVPlayer playerWithURL:url];
	
	// initialize the UI
	[self.playerLayer removeFromSuperlayer];
	self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
	self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
	self.playerLayer.frame = [self.playerView bounds];
	[[self.playerView layer] addSublayer:self.playerLayer];

	[self.player.currentItem addObserver:self
							  forKeyPath:@"duration"
								 options:0
								 context:nil];
	
	[self.scrubSlider setEnabled: (self.player != nil)];
	[self.scrubSlider setMaxValue: self.player.currentItem.duration.value];
	
	[self.sliceTable reloadData];
	[self refreshExportAvailability];

	[self.playPauseButton setEnabled:YES];
	
	return (self.asset != nil);
}

-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (([keyPath isEqualToString:@"duration"]) &&
		(object == self.player.currentItem)) {
		NSLog (@"duration value now %lld", self.player.currentItem.duration.value);
		// set slider max to duration
		[self.scrubSlider setMaxValue: self.player.currentItem.duration.value];
		// set up boundary listener
		__weak SNFMainWindowController *weakSelf = self;
		NSArray *boundaryTimes = @[[NSValue valueWithCMTime:kCMTimeZero],
								   [NSValue valueWithCMTime:self.player.currentItem.duration]];
		self.playerExtremesListener = [self.player addBoundaryTimeObserverForTimes:boundaryTimes
																			 queue:dispatch_get_main_queue() usingBlock:^
		{
			// if at end, pause
			if (CMTimeCompare(weakSelf.player.currentItem.duration, weakSelf.player.currentTime) == 0) {
				[weakSelf.player pause];
				[weakSelf.playPauseButton setState:NSOffState];
			}
		}];
		
		
		// time label refresh
		CMTime interval = CMTimeMakeWithSeconds(PLAYER_TIMER_INTERVAL,
												self.player.currentItem.duration.timescale);
		self.playerPeriodicListener = [self.player
									   addPeriodicTimeObserverForInterval:interval
									   queue:dispatch_get_main_queue()
									   usingBlock:^(CMTime time)
									   {
										   [weakSelf refreshCurrentTimeLabel];
									   }];

	}
}

-(void) refreshCurrentTimeLabel {
	if (! self.player.currentItem) {
		[self.currentTimeLabel setStringValue:@"00:00:00.000"];
		return;
	}
	[self.currentTimeLabel setStringValue: [self stringForTime:[self.player currentTime]]];
}

-(NSString*) stringForTime: (CMTime) time {
	NSTimeInterval timeInSeconds = CMTimeGetSeconds(time);
	UInt16 seconds = fmod(timeInSeconds, 60.0);
	UInt16 minutes = fmod (timeInSeconds / 60.0, 60.0);
	UInt16 hours = timeInSeconds / (60.0 * 60.0);
	UInt16 milliseconds = (timeInSeconds - (int) timeInSeconds) * 1000;
	return [NSString stringWithFormat:@"%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds];
}

#pragma mark export

- (IBAction)handleDestinationTapped:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanCreateDirectories:YES];
	[openPanel setCanChooseFiles:NO];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setPrompt:NSLocalizedString(@"Export", @"name for export save sheet button")];
	[openPanel setTitle:NSLocalizedString(@"Export Directory", @"title for export save sheet")];
	NSArray *directories = [[NSFileManager defaultManager] URLsForDirectory:NSMoviesDirectory
																  inDomains:NSUserDomainMask];
	if (directories && [directories count] > 0) {
		[openPanel setDirectoryURL:directories[0]];
	}
	[openPanel beginSheetModalForWindow:[self window]
					  completionHandler:^(NSInteger result)
	 {
		 if (result == NSOKButton) {
			 self.exportDirectoryURL = [openPanel URL];
			 [self.exportDestinationLabel setStringValue: [self.exportDirectoryURL lastPathComponent]];
			 [self refreshExportAvailability];
		 }
	 }];
	
}

-(void) refreshExportAvailability {
	[self.exportButton setEnabled: (self.exportDirectoryURL && self.player)];
}

- (IBAction)handleExportButtonTapped:(id)sender {
	if (self.divvy) {
		NSLog (@"can't export while export already running");
		return;
	}
	
	CMTimeRange exportTimeRanges [[self.sliceTimes count] + 1];
	for (int i=0; i<=[self.sliceTimes count]; i++) {
		CMTime startTime = kCMTimeZero;
		CMTime endTime = self.player.currentItem.duration;
		if (i > 0) {
//			NSValue *timeValue = self.sliceTimes[i-1];
//			[timeValue getValue:&startTime];
			startTime = [self.sliceTimes[i-1] CMTimeValue];
		}
		if (i < [self.sliceTimes count]) {
//			NSValue *timeValue = self.sliceTimes[i];
//			[timeValue getValue:&endTime];
			endTime = [self.sliceTimes[i] CMTimeValue];
		}
		exportTimeRanges[i] = CMTimeRangeFromTimeToTime(startTime, endTime);
		NSLog (@"range %d from %f to %f",
			   i, CMTimeGetSeconds(startTime), CMTimeGetSeconds((endTime)));
	}
		
	self.divvy = [[SNFExportDivvy alloc] init];
	self.divvy.asset = self.asset;
	self.divvy.assetURL = self.assetURL;
	self.divvy.outputDirectoryURL = self.exportDirectoryURL;
	[self.divvy setTimeRanges:exportTimeRanges count:[self.sliceTimes count] + 1];
	self.divvy.delegate = self;
	[self.divvy startDivvy];
	
	// monitor progress
	self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:PROGRESS_TIMER_INTERVAL
														  target:self
														selector:@selector(updateProgress:)
														userInfo:nil
														 repeats:YES];
	[self.exportProgressIndicator setHidden:NO];
}


-(void) updateProgress: (NSTimer*) timer {
	NSLog (@"divvy progress %f", [self.divvy progress]);
	[self.exportProgressIndicator setDoubleValue: [self.divvy progress]];
}


#pragma mark delegate

-(void) divvyDidFinish:(SNFExportDivvy *)divvy {
	divvy.delegate = nil;
	[self.progressTimer invalidate];
	self.progressTimer = nil;
	[self.exportProgressIndicator setHidden:YES];
	[self.exportProgressIndicator setDoubleValue:0.0];
	self.divvy = nil;
}


@end
