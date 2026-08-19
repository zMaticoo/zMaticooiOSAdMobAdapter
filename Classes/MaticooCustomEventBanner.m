#import "MaticooCustomEventBanner.h"
#include <stdatomic.h>
@import MaticooSDK;
#import "MaticooAdMobAdapterDebugLog.h"
#import "MaticooCustomExtras.h"

static NSString * const kAdapterSource = @"admob";
static const NSInteger kAdTypeBanner = 1;

#define dispatch_main_MATAdapter_ASYNC_safe(block)\
        if ([NSThread isMainThread]) {\
        block();\
        } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
        }

static NSString *MATAdTypeDes(NSString *placementId, NSString * _Nullable errorMsg) {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"placementId"] = placementId ?: @"";
    dic[@"adType"] = @(kAdTypeBanner);
    dic[@"source"] = kAdapterSource;
    if (errorMsg.length) {
        dic[@"error"] = errorMsg;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
}

@interface MaticooCustomEventBanner () <GADMediationAdapter, GADMediationBannerAd, MATBannerAdDelegate> {
    /// The completion handler to call when the ad loading succeeds or fails.
    GADMediationBannerLoadCompletionHandler _loadCompletionHandler;

    /// The ad event delegate to forward ad rendering events to the Google Mobile Ads SDK.
    id<GADMediationBannerAdEventDelegate> _adEventDelegate;

    NSString *_placementId;
}
/// load 在主线程写，GMA 可能在其它线程读 `-view` / dealloc。ARC 并发读写 nonatomic strong 会读到哨兵 0x400000000000bad0。
@property (nonatomic, strong) MATBannerAd *bannerAd;
@end

@implementation MaticooCustomEventBanner

@synthesize bannerAd = _bannerAd;

- (MATBannerAd *)bannerAd {
    @synchronized (self) {
        return _bannerAd;
    }
}

- (void)setBannerAd:(MATBannerAd *)bannerAd {
    @synchronized (self) {
        _bannerAd = bannerAd;
    }
}

#pragma mark - GADMediationAdapter

+ (void)setUpWithConfiguration:(GADMediationServerConfiguration *)configuration
             completionHandler:(GADMediationAdapterSetUpCompletionBlock)completionHandler {
    NSString *appkey = [[NSBundle mainBundle].infoDictionary objectForKey:@"zMaticooAppKey"];
    if (appkey == nil || [appkey isEqualToString:@""]) {
        NSError *error = [NSError errorWithDomain:@"com.google.zmaticoo" code:100 userInfo:@{NSLocalizedDescriptionKey: @"zmaticoo appkey is null"}];
        completionHandler(error);
    } else {
        [MaticooCustomExtras applyAdMobAgeRestrictedTreatment];

        [[MaticooAds shareSDK] setMediationName:@"admob"];
        [[MaticooAds shareSDK] initSDK:appkey onSuccess:^{
            completionHandler(nil);
        } onError:^(NSError * _Nonnull error) {
            completionHandler(error);
        }];
    }
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

- (void)loadBannerForAdConfiguration:(GADMediationBannerAdConfiguration *)adConfiguration
                   completionHandler:(GADMediationBannerLoadCompletionHandler)completionHandler {

    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationBannerLoadCompletionHandler originalCompletionHandler = [completionHandler copy];

    _loadCompletionHandler = ^id<GADMediationBannerAdEventDelegate>(
        _Nullable id<GADMediationBannerAd> ad, NSError *_Nullable error) {
        // Only allow completion handler to be called once.
        if (atomic_flag_test_and_set(&completionHandlerCalled)) {
            return nil;
        }

        id<GADMediationBannerAdEventDelegate> delegate = nil;
        if (originalCompletionHandler) {
            delegate = originalCompletionHandler(ad, error);
        }
        originalCompletionHandler = nil;
        return delegate;
    };

    NSString *adUnit = adConfiguration.credentials.settings[@"parameter"];
    if (![adUnit isKindOfClass:[NSString class]] || adUnit.length == 0) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(nil, @"placement id is null or invalid type")];
        NSError *error = [NSError errorWithDomain:@"com.google.zmaticoo" code:100 userInfo:[NSDictionary dictionaryWithObject:@"zmaticoo placement id is null" forKey:@"reason"]];
        if (_loadCompletionHandler) {
            _loadCompletionHandler(nil, error);
        }
        return;
    }
    _placementId = adUnit;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATAdTypeDes(_placementId, nil)];

    dispatch_main_MATAdapter_ASYNC_safe(^{
        MATBannerAd *bannerAd = [[MATBannerAd alloc] initWithPlacementID:adUnit];
        bannerAd.delegate = self;
        bannerAd.frame = CGRectMake(0, 0,
                                    adConfiguration.adSize.size.width,
                                    adConfiguration.adSize.size.height);

        id extras = adConfiguration.extras;
        if ([extras isKindOfClass:[MaticooCustomExtras class]]) {
            id le = ((MaticooCustomExtras *)extras).localExtra;
            NSDictionary *localExtra = [le isKindOfClass:[NSDictionary class]] ? le : nil;
            if (localExtra) {
                bannerAd.localExtra = localExtra;
                id canCloseObj = localExtra[@"can_close_ad"];
                if ([canCloseObj isKindOfClass:[NSNumber class]]) {
                    bannerAd.canCloseAd = [(NSNumber *)canCloseObj boolValue];
                } else if ([canCloseObj isKindOfClass:[NSString class]]) {
                    bannerAd.canCloseAd = [(NSString *)canCloseObj boolValue];
                }
            }
        }
        self.bannerAd = bannerAd;
        // 上面已把同一份 localExtra 赋给 bannerAd，无需再经 extraMap 传一次。
        [bannerAd loadAd];
    });
}

#pragma mark - GADMediationBannerAd

- (nonnull UIView *)view {
    MATBannerAd *ad = self.bannerAd;
    if (ad == nil) {
        UIView *bannerAdNilView = [[UIView alloc] init];
        return bannerAdNilView;
    }
    return ad;
}

#pragma mark - MATBannerAdDelegate

- (void)bannerAdDidLoad:(MATBannerAd *)bannerAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATAdTypeDes(_placementId, nil)];
    if (_loadCompletionHandler) {
        _adEventDelegate = _loadCompletionHandler(self, nil);
    }
}

- (void)bannerAd:(MATBannerAd *)bannerAd didFailWithError:(NSError *)error {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(_placementId, error.localizedDescription)];
    if (_loadCompletionHandler) {
        _loadCompletionHandler(nil, error);
    }
}

- (void)bannerAdDidImpression:(MATBannerAd *)bannerAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATAdTypeDes(_placementId, nil)];
    [_adEventDelegate reportImpression];
}

- (void)bannerAdDidClick:(MATBannerAd *)bannerAd {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATAdTypeDes(_placementId, nil)];
    [_adEventDelegate reportClick];
}

- (void)bannerAd:(MATBannerAd *)bannerAd showFailWithError:(NSError *)error {
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(_placementId, error.localizedDescription)];
    [_adEventDelegate didFailToPresentWithError:error];
}

- (void)bannerAdDismissed:(MATBannerAd *)bannerAd {
    [_adEventDelegate didDismissFullScreenView];
}

- (void)bannerAdDidLeaveApp:(MATBannerAd *)bannerAd {
}

- (void)dealloc {
    MaticooAdMobAdapterDebugLog(@"banner MATBannerAdapter dealloc adapter=%p placementId=%@ thread=%@ main=%d",self, _placementId, [NSThread currentThread], [NSThread isMainThread]);
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_destroy" des:MATAdTypeDes(_placementId, nil)];
    MATBannerAd *ad = nil;
    @synchronized (self) {
        ad = _bannerAd;
        _bannerAd = nil;
    }
    ad.delegate = nil;
    if (ad) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ad destroy];
        });
    }
}

@end
