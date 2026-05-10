#import "MaticooCustomEventRewardedVideo.h"
#include <stdatomic.h>
@import MaticooSDK;
#import "MaticooCustomExtras.h"

static NSString * const kAdapterSource = @"admob";
static const NSInteger kAdTypeRewardedVideo = 3;

static NSString *MATAdTypeDes(NSString *placementId, NSString * _Nullable errorMsg) {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"placementId"] = placementId ?: @"";
    dic[@"adType"] = @(kAdTypeRewardedVideo);
    dic[@"source"] = kAdapterSource;
    if (errorMsg.length) {
        dic[@"error"] = errorMsg;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
}

@interface MaticooCustomEventRewardedVideo () <GADMediationAdapter, GADMediationRewardedAd, MATRewardedVideoAdDelegate> {
    GADMediationRewardedLoadCompletionHandler _loadCompletionHandler;
    id<GADMediationRewardedAdEventDelegate> _adEventDelegate;

    MATRewardedVideoAd *_rewarded;
    NSString *_placementId;
}

@end

@implementation MaticooCustomEventRewardedVideo

+ (void)setUpWithConfiguration:(GADMediationServerConfiguration *)configuration
             completionHandler:(GADMediationAdapterSetUpCompletionBlock)completionHandler {
    NSString *appkey = [[NSBundle mainBundle].infoDictionary objectForKey:@"zMaticooAppKey"];
    if (appkey == nil || [appkey isEqualToString:@""]) {
        NSError *error = [NSError errorWithDomain:@"com.google.zmaticoo" code:100 userInfo:@{NSLocalizedDescriptionKey: @"zmaticoo appkey is null"}];
        completionHandler(error);
    } else {
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
}

+ (GADVersionNumber)adSDKVersion {
    GADVersionNumber version = {2, 1, 0};
    return version;
}

+ (GADVersionNumber)adapterVersion {
    GADVersionNumber version = {2, 1, 0};
    return version;
}

+ (nullable Class<GADAdNetworkExtras>)networkExtrasClass {
    return [MaticooCustomExtras class];
}

- (void)loadRewardedAdForAdConfiguration:(GADMediationRewardedAdConfiguration *)adConfiguration
                       completionHandler:(GADMediationRewardedLoadCompletionHandler)completionHandler {

    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationRewardedLoadCompletionHandler originalCompletionHandler = [completionHandler copy];

    _loadCompletionHandler = ^id<GADMediationRewardedAdEventDelegate>(
        _Nullable id<GADMediationRewardedAd> ad, NSError *_Nullable error) {
        if (atomic_flag_test_and_set(&completionHandlerCalled)) {
            return nil;
        }

        id<GADMediationRewardedAdEventDelegate> delegate = nil;
        if (originalCompletionHandler) {
            delegate = originalCompletionHandler(ad, error);
        }
        originalCompletionHandler = nil;
        return delegate;
    };

    NSString *adUnit = adConfiguration.credentials.settings[@"parameter"];
    if (adUnit == nil) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(adUnit, @"placement id is null")];
        NSError *error = [NSError errorWithDomain:@"com.google.zmaticoo" code:100 userInfo:[NSDictionary dictionaryWithObject:@"zmaticoo placement id is null" forKey:@"reason"]];
        _loadCompletionHandler(nil, error);
        return;
    }
    _placementId = adUnit;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATAdTypeDes(_placementId, nil)];
    _rewarded = [[MATRewardedVideoAd alloc] initWithPlacementID:adUnit];
    _rewarded.delegate = self;
    id extras = adConfiguration.extras;
    if (extras != nil && [extras isKindOfClass:[MaticooCustomExtras class]]) {
        id localExtra = ((MaticooCustomExtras *)extras).localExtra;
        if ([localExtra isKindOfClass:[NSDictionary class]]) {
            [_rewarded loadAdExtraMap:(NSDictionary *)localExtra];
        } else if ([localExtra isKindOfClass:[NSString class]] && [(NSString *)localExtra length] > 0) {
            [_rewarded loadAd:(NSString *)localExtra];
        } else {
            [_rewarded loadAd];
        }
    } else {
        [_rewarded loadAd];
    }
}

#pragma mark - GADMediationRewardedAd

- (void)presentFromViewController:(UIViewController *)viewController {
    if (_rewarded && _rewarded.isReady) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show" des:MATAdTypeDes(_placementId, nil)];
        [_rewarded showAdFromViewController:viewController];
    } else {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(_placementId, @"ad is not ready")];
        NSError *error = [NSError errorWithDomain:@"com.google.zmaticoo" code:30101 userInfo:@{NSLocalizedDescriptionKey: @"Rewarded ad is not ready"}];
        [_adEventDelegate didFailToPresentWithError:error];
    }
}

#pragma mark - MATRewardedVideoAdDelegate

- (void)rewardedVideoAdDidLoad:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATAdTypeDes(_placementId, nil)];
    _adEventDelegate = _loadCompletionHandler(self, nil);
}

- (void)rewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *)error {
    (void)rewardedVideoAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(_placementId, error.localizedDescription)];
    _adEventDelegate = _loadCompletionHandler(nil, error);
}

- (void)rewardedVideoAd:(MATRewardedVideoAd *)rewardedVideoAd displayFailWithError:(NSError *)error {
    (void)rewardedVideoAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(_placementId, error.localizedDescription)];
    [_adEventDelegate didFailToPresentWithError:error];
}

- (void)rewardedVideoAdStarted:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
    [_adEventDelegate didStartVideo];
}

- (void)rewardedVideoAdCompleted:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
    [_adEventDelegate didEndVideo];
}

- (void)rewardedVideoAdWillLogImpression:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATAdTypeDes(_placementId, nil)];
    [_adEventDelegate willPresentFullScreenView];
    [_adEventDelegate reportImpression];
}

- (void)rewardedVideoAdDidClick:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATAdTypeDes(_placementId, nil)];
    [_adEventDelegate reportClick];
}

- (void)rewardedVideoAdWillClose:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
}

- (void)rewardedVideoAdDidClose:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
    [_adEventDelegate didDismissFullScreenView];
}

- (void)rewardedVideoAdReward:(MATRewardedVideoAd *)rewardedVideoAd rewardInfo:(MATRewardInfo *)rewardInfo {
    (void)rewardedVideoAd;
    (void)rewardInfo;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_reward" des:MATAdTypeDes(_placementId, nil)];
    [_adEventDelegate didRewardUser];
}

- (void)rewardedVideoAdDidSkip:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
}

- (void)rewardedVideoAdEndCardShow:(MATRewardedVideoAd *)rewardedVideoAd {
    (void)rewardedVideoAd;
}

@end
