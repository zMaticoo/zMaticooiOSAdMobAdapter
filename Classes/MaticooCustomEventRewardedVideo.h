#import <Foundation/Foundation.h>
#import <GoogleMobileAds/GoogleMobileAds.h>

@interface MaticooCustomEventRewardedVideo : NSObject
- (void)loadRewardedAdForAdConfiguration:(GADMediationRewardedAdConfiguration *)adConfiguration
                     completionHandler:(GADMediationRewardedLoadCompletionHandler)completionHandler;
@end
