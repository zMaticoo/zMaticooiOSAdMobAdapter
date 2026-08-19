//
//  MaticooCustomExtras.h
//  MediationExample
//
//  Created by xuge on 2024/11/11.
//  Copyright © 2024 Google, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GoogleMobileAds/GoogleMobileAds.h>

NS_ASSUME_NONNULL_BEGIN

@interface MaticooCustomExtras : NSObject<GADAdNetworkExtras>

@property(copy, nonatomic) NSDictionary * localExtra;

/// 取出 `adConfiguration.extras` 里的 `localExtra`，原样交给 `-loadAdExtraMap:`。
/// 这里不挑 key、不改写值，取不到时返回 nil，调用方原样传给 load 接口即可。
+ (nullable NSDictionary<NSString *, id> *)loadExtraMapFromExtras:(nullable id)extras;

/// 读取 `localExtra[@"is_muted"]`；`NSNumber`/`BOOL` 或 `"true"`/`"false"`，非法或缺省返回 nil。
+ (nullable NSNumber *)mutedFromLocalExtra:(nullable NSDictionary<NSString *, id> *)localExtra;

/// AdMob 全局静音 `GADMobileAds.applicationMuted` → `MaticooAds.videoMute`（仅影响插屏/激励等全屏，不影响 Native）
+ (void)applyAdMobGlobalVideoMute;

/// AdMob 年龄限制 → `MaticooAds setIsAgeRestrictedUser:`。
/// 优先新 API `ageRestrictedTreatment`（GMA ≥ 13.3）；没有或 Unspecified 时回退旧 `tagForChildDirectedTreatment`。
/// 读写均走运行时 selector / KVC，链老版 GMA 头文件也能编译。
+ (void)applyAdMobAgeRestrictedTreatment;

@end

NS_ASSUME_NONNULL_END
