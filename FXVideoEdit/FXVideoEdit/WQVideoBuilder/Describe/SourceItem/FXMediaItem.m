//
//  FXMediaItem.m
//  FXVideoEdit
//
//  Created by xunni zou on 2020/7/24.
//  Copyright © 2020 xunni zou. All rights reserved.
//

#import "FXMediaItem.h"

static NSString *const AVAssetTracksKey = @"tracks";
static NSString *const AVAssetDurationKey = @"duration";
static NSString *const AVAssetCommonMetadataKey = @"commonMetadata";

@interface FXMediaItem ()

@property (nonatomic, copy) NSString *title;

@property (nonatomic, copy) NSString *filename;

@property (strong, nonatomic) NSURL *url;

@end

@implementation FXMediaItem


- (id)initWithAvAsset:(AVAsset *)videoAsset
{
    self = [super init];
    if (self) {
        _asset = videoAsset;
    }
    return self;
}

- (id)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        _url = url;
        _urlString = url.absoluteString;
        _filename = [[url lastPathComponent] copy];
        NSDictionary *options = @{AVURLAssetPreferPreciseDurationAndTimingKey:
                                      @YES};
        _asset = [AVURLAsset URLAssetWithURL:url
                                     options:options];
    }
    return self;
}

- (NSString *)title {
    if (!_title) {
        for (AVMetadataItem *metaItem in [self.asset commonMetadata]) {
            if ([metaItem.commonKey isEqualToString:AVMetadataCommonKeyTitle]) {
                _title = [metaItem stringValue];
                break;
            }
        }
    }
    if (!_title) {
        _title = self.filename;
    }
    return _title;
}

- (NSString *)mediaType {
    NSAssert(NO, @"Must be overridden in subclass.");
    return nil;
}

- (void)prepareWithCompletionBlock:(FXPreparationCompletionBlock)completionBlock {
    [self.asset loadValuesAsynchronouslyForKeys:@[AVAssetTracksKey, AVAssetDurationKey, AVAssetCommonMetadataKey]
                              completionHandler:^{
                                  // Production code should be more robust.  Specifically, should capture error in failure case.
                                  AVKeyValueStatus tracksStatus = [self.asset statusOfValueForKey:AVAssetTracksKey error:nil];
                                  AVKeyValueStatus durationStatus = [self.asset statusOfValueForKey:AVAssetDurationKey error:nil];
                                  self->_prepared = (tracksStatus == AVKeyValueStatusLoaded) && (durationStatus == AVKeyValueStatusLoaded);
                                  if (self.prepared) {
                                      self.timeRange = CMTimeRangeMake(kCMTimeZero, self.asset.duration);
                                      [self performPostPrepareActionsWithCompletionBlock:completionBlock];
                                  } else {
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          if (completionBlock) {
                                              completionBlock(NO);
                                          }
                                      });
                                  }
                              }];
}

- (void)performPostPrepareActionsWithCompletionBlock:(FXPreparationCompletionBlock)completionBlock {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completionBlock) {
            completionBlock(self.prepared);
        }
    });
}

- (BOOL)isTrimmed {
    if (!self.prepared) {
        return NO;
    }
    return CMTIME_COMPARE_INLINE(self.timeRange.duration, <, self.asset.duration);
}

- (AVPlayerItem *)makePlayable {
    return [AVPlayerItem playerItemWithAsset:self.asset];
}

- (BOOL)isEqual:(id)other {
    if (self == other) {
        return YES;
    }
    if (!other || ![other isKindOfClass:[self class]]) {
        return NO;
    }

    return [self.url isEqual:[other url]];
}

- (NSUInteger)hash {
    return [self.url hash];
}

@end
