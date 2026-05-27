//
//  MaticooCustomEventNative.m
//  MaticooAdMobAdapter
//
//  AdMob mediation native adapter for Maticoo Native ad.
//  - 实现 GADMediationAdapter + GADMediationNativeAd + GADMediatedUnifiedNativeAd 接口
//  - 把 Maticoo MATNativeAdElements 映射为 GADMediatedUnifiedNativeAd 资产
//  - handlesUserClicks/handlesUserImpressions 返回 YES；didRenderInView: 内 registerViewForInteraction，
//    曝光/点击/展示失败经 MATNativeAd 回调后 reportImpression/reportClick/didFailToPresentWithError 上报给 GAD
//

#import "MaticooCustomEventNative.h"
#import "MaticooAdMobAdapterDebugLog.h"
#import "MaticooCustomExtras.h"
#include <stdatomic.h>
@import MaticooSDK;

static NSString * const kAdapterSource = @"admob";
static const NSInteger kAdTypeNative = 4;
static NSString * const kUseImageSelfRenderKey = @"use_image_self_render";

static NSString *MATAdTypeDes(NSString *placementId, NSString * _Nullable errorMsg) {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"placementId"] = placementId ?: @"";
    dic[@"adType"] = @(kAdTypeNative);
    dic[@"source"] = kAdapterSource;
    if (errorMsg.length) {
        dic[@"error"] = errorMsg;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
}

@interface MaticooCustomEventNative () <MATNativeAdDelegate, MATVideoLifecycleDelegate> {
    MATNativeAd *_nativeAd;
    GADMediationNativeLoadCompletionHandler _loadCompletionHandler;
    id<GADMediationNativeAdEventDelegate> _adEventDelegate;
    NSString *_placementId;
    UIView *_renderedAdView;

    // Mapped assets
    NSString *_mappedHeadline;
    NSString *_mappedBody;
    NSString *_mappedCallToAction;
    NSString *_mappedAdvertiser;
    GADNativeAdImage *_mappedIcon;
    NSArray<GADNativeAdImage *> *_mappedImages;
    UIView *_mappedMediaView;
    MATAdChoicesView *_mappedAdChoicesView;
    BOOL _useImageSelfRender;
}
@end

@implementation MaticooCustomEventNative

#pragma mark - GADMediationAdapter

+ (void)setUpWithConfiguration:(GADMediationServerConfiguration *)configuration
             completionHandler:(GADMediationAdapterSetUpCompletionBlock)completionHandler {
    NSString *appkey = [[NSBundle mainBundle].infoDictionary objectForKey:@"zMaticooAppKey"];
    if (appkey == nil || [appkey isEqualToString:@""]) {
        NSError *error = [NSError errorWithDomain:@"com.google.zmaticoo" code:100
                                         userInfo:@{NSLocalizedDescriptionKey: @"zmaticoo appkey is null"}];
        completionHandler(error);
        return;
    }
    NSNumber *childDirected = GADMobileAds.sharedInstance.requestConfiguration.tagForChildDirectedTreatment;
    if (childDirected != nil) {
        [[MaticooAds shareSDK] setIsAgeRestrictedUser:childDirected.boolValue];
    }
    [[MaticooAds shareSDK] setMediationName:@"admob"];
    [[MaticooAds shareSDK] initSDK:appkey onSuccess:^{
        completionHandler(nil);
    } onError:^(NSError * _Nonnull error) {
        completionHandler(error);
    }];
}

+ (GADVersionNumber)adSDKVersion {
    GADVersionNumber version = {2, 2, 0};
    return version;
}

+ (GADVersionNumber)adapterVersion {
    GADVersionNumber version = {2, 2, 0};
    return version;
}

+ (nullable Class<GADAdNetworkExtras>)networkExtrasClass {
    return [MaticooCustomExtras class];
}

#pragma mark - Load

- (void)loadNativeAdForAdConfiguration:(GADMediationNativeAdConfiguration *)adConfiguration
                     completionHandler:(GADMediationNativeLoadCompletionHandler)completionHandler {
    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationNativeLoadCompletionHandler originalCompletionHandler = [completionHandler copy];
    _loadCompletionHandler = ^id<GADMediationNativeAdEventDelegate>(
        _Nullable id<GADMediationNativeAd> ad, NSError *_Nullable error) {
        if (atomic_flag_test_and_set(&completionHandlerCalled)) {
            return nil;
        }
        id<GADMediationNativeAdEventDelegate> delegate = nil;
        if (originalCompletionHandler) {
            delegate = originalCompletionHandler(ad, error);
        }
        originalCompletionHandler = nil;
        return delegate;
    };

    NSString *adUnit = adConfiguration.credentials.settings[@"parameter"];
    if (![adUnit isKindOfClass:[NSString class]] || adUnit.length == 0) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                           des:MATAdTypeDes(nil, @"placement id is null or invalid type")];
        NSError *error = [NSError errorWithDomain:@"com.google.zmaticoo" code:100
                                         userInfo:@{@"reason": @"zmaticoo placement id is null"}];
        if (_loadCompletionHandler) {
            _loadCompletionHandler(nil, error);
        }
        return;
    }
    _placementId = adUnit;
    _useImageSelfRender = NO;
    id extras = adConfiguration.extras;
    if ([extras isKindOfClass:[MaticooCustomExtras class]]) {
        id le = ((MaticooCustomExtras *)extras).localExtra;
        NSDictionary *localExtra = [le isKindOfClass:[NSDictionary class]] ? le : nil;
        if (localExtra) {
            id useImageSelfRenderObj = localExtra[kUseImageSelfRenderKey];
            if ([useImageSelfRenderObj isKindOfClass:[NSNumber class]]) {
                _useImageSelfRender = [(NSNumber *)useImageSelfRenderObj boolValue];
            }
        }
    }
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load"
                                                       des:MATAdTypeDes(_placementId, nil)];
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_nativeAd = [[MATNativeAd alloc] initWithPlacementID:adUnit];
        self->_nativeAd.delegate = self;
        [self->_nativeAd loadAd];
    });
}

#pragma mark - GADMediatedUnifiedNativeAd

- (NSString *)headline      { return _mappedHeadline; }
- (NSString *)body          { return _mappedBody; }
- (NSString *)callToAction  { return _mappedCallToAction; }
- (NSString *)advertiser    { return _mappedAdvertiser; }
- (GADNativeAdImage *)icon  { return _mappedIcon; }
- (NSArray<GADNativeAdImage *> *)images { return _mappedImages; }
- (NSDictionary<NSString *,id> *)extraAssets { return nil; }
- (NSDecimalNumber *)starRating { return nil; }
- (NSString *)store { return nil; }
- (NSString *)price { return nil; }

- (UIView *)mediaView { return _mappedMediaView; }
- (UIView *)adChoicesView { return _mappedAdChoicesView; }
- (BOOL)hasVideoContent {
    MATMediaContent *media = _nativeAd.nativeElements.mediaContent;
    if (media.hasVideoContent) {
        return YES;
    }
    if (_useImageSelfRender) {
        return NO;
    }
    return YES;
}

- (CGFloat)mediaContentAspectRatio {
    MATMediaContent *media = _nativeAd.nativeElements.mediaContent;
    if (media.hasVideoContent) {
        return media.aspectRatio;
    }
    if (_useImageSelfRender) {
        return media.aspectRatio;
    }
    return 0;
}
- (NSTimeInterval)duration { return _nativeAd.nativeElements.mediaContent.duration; }

- (BOOL)handlesUserClicks      { return YES; }
- (BOOL)handlesUserImpressions { return YES; }

- (void)didRenderInView:(UIView *)view
    clickableAssetViews:(NSDictionary<GADNativeAssetIdentifier,UIView *> *)clickableAssetViews
 nonclickableAssetViews:(NSDictionary<GADNativeAssetIdentifier,UIView *> *)nonclickableAssetViews
         viewController:(UIViewController *)viewController {
    _renderedAdView = view;
    NSMutableArray<UIView *> *clickables = [NSMutableArray array];
    for (UIView *v in clickableAssetViews.allValues) {
        [clickables addObject:v];
    }
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show"
                                                       des:MATAdTypeDes(_placementId, nil)];
    [_nativeAd registerViewForInteraction:view
                                mediaView:(MATMediaView *)_mappedMediaView
                           clickableViews:clickables];
}

- (void)didUntrackView:(UIView *)view {
    _renderedAdView = nil;
}

#pragma mark - Asset mapping

- (void)admob_mapElementsAndComplete {
    MATNativeAdElements *e = _nativeAd.nativeElements;
    _mappedHeadline = e.headline ?: @"";
    _mappedBody = e.body ?: @"";
    _mappedCallToAction = e.callToAction ?: @"";
    _mappedAdvertiser = e.advertiser;

    if (e.icon.image) {
        _mappedIcon = [[GADNativeAdImage alloc] initWithImage:e.icon.image];
    } else if (e.icon.imageURL) {
        _mappedIcon = [[GADNativeAdImage alloc] initWithURL:e.icon.imageURL scale:1.0];
    }

    if (e.images.count > 0) {
        NSMutableArray<GADNativeAdImage *> *imgs = [NSMutableArray array];
        for (MATAdImage *adImg in e.images) {
            if (adImg.image) {
                [imgs addObject:[[GADNativeAdImage alloc] initWithImage:adImg.image]];
            } else if (adImg.imageURL) {
                [imgs addObject:[[GADNativeAdImage alloc] initWithURL:adImg.imageURL scale:1.0]];
            }
        }
        _mappedImages = [imgs copy];
    }

    MATMediaView *mv = nil;
    if (e.mediaContent.hasVideoContent) {
        mv = [[MATMediaView alloc] init];
        mv.clipsToBounds = YES;
    } else if (_useImageSelfRender) {
        mv = nil;
    } else {
        mv = [[MATMediaView alloc] init];
        mv.clipsToBounds = YES;
    }
    _mappedMediaView = mv;

    _mappedAdChoicesView = [[MATAdChoicesView alloc] init];
    [_mappedAdChoicesView setNativeAd:_nativeAd];

    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success"
                                                       des:MATAdTypeDes(_placementId, nil)];
    if (_loadCompletionHandler) {
        _adEventDelegate = _loadCompletionHandler(self, nil);
    }
}

#pragma mark - MATNativeAdDelegate

- (void)nativeAdLoadSuccess:(MATNativeAd *)nativeAd {
    MATVideoController *vc = nativeAd.nativeElements.mediaContent.videoController;
    if (vc) {
        vc.delegate = self;
    }
    [self admob_mapElementsAndComplete];
}

- (void)nativeAdFailed:(MATNativeAd *)nativeAd withError:(NSError *)error {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed"
                                                       des:MATAdTypeDes(_placementId, error.localizedDescription)];
    if (_loadCompletionHandler) {
        _loadCompletionHandler(nil, error);
    }
}

- (void)nativeAdDisplayed:(MATNativeAd *)nativeAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp"
                                                       des:MATAdTypeDes(_placementId, nil)];
    [_adEventDelegate reportImpression];
}

- (void)nativeAd:(MATNativeAd *)nativeAd displayFailWithError:(NSError *)error {
    (void)nativeAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed"
                                                       des:MATAdTypeDes(_placementId, error.localizedDescription)];
    [_adEventDelegate didFailToPresentWithError:error];
}

- (void)nativeAdClicked:(MATNativeAd *)nativeAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click"
                                                       des:MATAdTypeDes(_placementId, nil)];
    [_adEventDelegate reportClick];
}

#pragma mark - MATVideoLifecycleDelegate

- (void)videoDidStart {
    MaticooAdMobAdapterDebugLog(@"native videoDidStart adapter=%p placementId=%@", self, _placementId);
    [_adEventDelegate didPlayVideo];
}

- (void)videoDidPlay {
    MaticooAdMobAdapterDebugLog(@"native videoDidPlay adapter=%p placementId=%@", self, _placementId);
    [_adEventDelegate didPlayVideo];
}

- (void)videoDidPause {
    MaticooAdMobAdapterDebugLog(@"native videoDidPause adapter=%p placementId=%@", self, _placementId);
    [_adEventDelegate didPauseVideo];
}

- (void)videoDidEnd {
    MaticooAdMobAdapterDebugLog(@"native videoDidEnd adapter=%p placementId=%@", self, _placementId);
    [_adEventDelegate didEndVideo];
}

- (void)videoDidMute:(BOOL)isMuted {
    MaticooAdMobAdapterDebugLog(@"native videoDidMute adapter=%p placementId=%@ isMuted=%d", self, _placementId, isMuted);
    if (isMuted) {
        [_adEventDelegate didMuteVideo];
    } else {
        [_adEventDelegate didUnmuteVideo];
    }
}

- (void)dealloc {
    MaticooAdMobAdapterDebugLog(@"native MaticooCustomEventNative dealloc adapter=%p placementId=%@", self, _placementId);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy"
                                                       des:MATAdTypeDes(_placementId, nil)];
    MATNativeAd *ad = _nativeAd;
    _nativeAd.delegate = nil;
    _nativeAd = nil;
    if (ad) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ad destroy];
        });
    }
}

@end
