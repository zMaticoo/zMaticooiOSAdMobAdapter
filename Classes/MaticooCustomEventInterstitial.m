#import "MaticooCustomEventInterstitial.h"
#include <stdatomic.h>
@import MaticooSDK;
#import "MaticooCustomExtras.h"

static NSString * const kAdapterSource = @"admob";
static const NSInteger kAdTypeInterstitial = 2;

static NSString *MATAdTypeDes(NSString *placementId, NSString * _Nullable errorMsg) {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"placementId"] = placementId ?: @"";
    dic[@"adType"] = @(kAdTypeInterstitial);
    dic[@"source"] = kAdapterSource;
    if (errorMsg.length) {
        dic[@"error"] = errorMsg;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
}

@interface MaticooCustomEventInterstitial () <GADMediationAdapter, GADMediationInterstitialAd, MATInterstitialAdDelegate> {
  /// The completion handler to call when the ad loading succeeds or fails.
  GADMediationInterstitialLoadCompletionHandler _loadCompletionHandler;

  /// The ad event delegate to forward ad rendering events to the Google Mobile Ads SDK.
  id<GADMediationInterstitialAdEventDelegate> _adEventDelegate;
    
    MATInterstitialAd *_interstitial;
    NSString *_placementId;
}

@end

@implementation MaticooCustomEventInterstitial

#pragma mark GADCustomEventInterstitial implementation


+ (void)setUpWithConfiguration:(GADMediationServerConfiguration *)configuration
             completionHandler:(GADMediationAdapterSetUpCompletionBlock)completionHandler {
  // This is where you you will initialize the SDK that this custom event is built for.
  // Upon finishing the SDK initialization, call the completion handler with success.
    NSString *appkey = [[NSBundle mainBundle].infoDictionary objectForKey:@"zMaticooAppKey"];
    if (appkey == nil || [appkey isEqualToString:@""]) {
        NSError *error = [NSError errorWithDomain:@"com.google.zmaticoo" code:100 userInfo:@{NSLocalizedDescriptionKey: @"zmaticoo appkey is null"}];
        completionHandler(error);
    } else {
        // COPPA
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

- (void)loadInterstitialForAdConfiguration:
            (GADMediationInterstitialAdConfiguration *)adConfiguration
                         completionHandler:
                             (GADMediationInterstitialLoadCompletionHandler)completionHandler {

    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationInterstitialLoadCompletionHandler originalCompletionHandler =
    [completionHandler copy];
    
    _loadCompletionHandler = ^id<GADMediationInterstitialAdEventDelegate>(
                                                                          _Nullable id<GADMediationInterstitialAd> ad, NSError *_Nullable error) {
                                                                              // Only allow completion handler to be called once.
                                                                              if (atomic_flag_test_and_set(&completionHandlerCalled)) {
                                                                                  return nil;
                                                                              }
                                                                              
                                                                              id<GADMediationInterstitialAdEventDelegate> delegate = nil;
                                                                              if (originalCompletionHandler) {
                                                                                  // Call original handler and hold on to its return value.
                                                                                  delegate = originalCompletionHandler(ad, error);
                                                                              }
                                                                              
                                                                              // Release reference to handler. Objects retained by the handler will also be released.
                                                                              originalCompletionHandler = nil;
                                                                              
                                                                              return delegate;
                                                                          };
    NSString *adUnit = adConfiguration.credentials.settings[@"parameter"];
    if (![adUnit isKindOfClass:[NSString class]] || adUnit.length == 0){
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(nil, @"placement id is null or invalid type")];
        NSError *error= [NSError errorWithDomain:@"com.google.zmaticoo" code:100 userInfo:[NSDictionary dictionaryWithObject:@"zmaticoo placement id is null" forKey:@"reason"]];
        if (_loadCompletionHandler) {
            _loadCompletionHandler(nil, error);
        }
        return;
    }
    _placementId = adUnit;
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load" des:MATAdTypeDes(_placementId, nil)];
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_interstitial = [[MATInterstitialAd alloc] initWithPlacementID:adUnit];
        self->_interstitial.delegate = self;
        [self->_interstitial loadAd];
    });
}

#pragma mark GADMediationInterstitialAd implementation

- (void)presentFromViewController:(UIViewController *)viewController {
    if (_interstitial && _interstitial.isReady) {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show" des:MATAdTypeDes(_placementId, nil)];
        [_interstitial showAdFromViewController:viewController];
    } else {
        [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(_placementId, @"ad is not ready")];
        NSError *error = [NSError errorWithDomain:@"com.google.zmaticoo" code:30101 userInfo:@{NSLocalizedDescriptionKey: @"Interstitial ad is not ready"}];
        [_adEventDelegate didFailToPresentWithError:error];
    }
}


#pragma mark - Delegate

- (void)interstitialAdDidLoad:(MATInterstitialAd *)interstitialAd{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_success" des:MATAdTypeDes(_placementId, nil)];
    if (_loadCompletionHandler) {
        _adEventDelegate = _loadCompletionHandler(self, nil);
    }
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd didFailWithError:(NSError *)error{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_load_failed" des:MATAdTypeDes(_placementId, error.localizedDescription)];
    if (_loadCompletionHandler) {
        _loadCompletionHandler(nil, error);
    }
}

- (void)interstitialAdWillLogImpression:(MATInterstitialAd *)interstitialAd{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_imp" des:MATAdTypeDes(_placementId, nil)];
    [_adEventDelegate willPresentFullScreenView];
    [_adEventDelegate reportImpression];
}

- (void)interstitialAdDidClick:(MATInterstitialAd *)interstitialAd{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_click" des:MATAdTypeDes(_placementId, nil)];
    [_adEventDelegate reportClick];
}

//did click close button
- (void)interstitialAdDidClose:(MATInterstitialAd *)interstitialAd{
    [_adEventDelegate didDismissFullScreenView];
}

- (void)interstitialAd:(MATInterstitialAd *)interstitialAd displayFailWithError:(NSError *)error{
    [[MaticooAds shareSDK] adapterEventReportWithEventName:@"adapter_show_failed" des:MATAdTypeDes(_placementId, error.localizedDescription)];
    [_adEventDelegate didFailToPresentWithError:error];
}

- (void)interstitialAdWillClose:(MATInterstitialAd *)interstitialAd {}
- (void)interstitialAdDidSkip:(MATInterstitialAd *)interstitialAd {}
- (void)interstitialAdEndCardShow:(MATInterstitialAd *)interstitialAd {}

@end
