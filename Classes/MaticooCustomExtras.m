//
//  MaticooCustomExtras.m
//  MediationExample
//
//  Created by xuge on 2024/11/11.
//  Copyright © 2024 Google, Inc. All rights reserved.
//

#import "MaticooCustomExtras.h"
#import "MaticooAdMobAdapterDebugLog.h"
@import MaticooSDK;

/// 与 GADAgeRestrictedTreatment 数值对齐（不直接引用枚举，兼容 GMA < 13.3 头文件）。
static const NSInteger kMATAdMobAgeTreatmentUnspecified = 0;
static const NSInteger kMATAdMobAgeTreatmentChild = 1;

@implementation MaticooCustomExtras

+ (nullable NSDictionary<NSString *, id> *)loadExtraMapFromExtras:(nullable id)extras {
    if (![extras isKindOfClass:[MaticooCustomExtras class]]) {
        return nil;
    }
    id localExtra = ((MaticooCustomExtras *)extras).localExtra;
    return [localExtra isKindOfClass:[NSDictionary class]] ? localExtra : nil;
}

+ (nullable NSNumber *)mutedFromLocalExtra:(nullable NSDictionary<NSString *, id> *)localExtra {
    if (![localExtra isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id value = localExtra[@"is_muted"];
    if ([value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *text = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([text caseInsensitiveCompare:@"true"] == NSOrderedSame) {
            return @YES;
        }
        if ([text caseInsensitiveCompare:@"false"] == NSOrderedSame) {
            return @NO;
        }
    }
    if (value != nil) {
        MaticooAdMobAdapterDebugLog(@"ignore illegal is_muted=%@", value);
    }
    return nil;
}

+ (void)applyAdMobGlobalVideoMute {
    BOOL muted = GADMobileAds.sharedInstance.applicationMuted;
    MaticooAds *sdk = [MaticooAds shareSDK];
    sdk.videoMute = muted;
    MaticooAdMobAdapterDebugLog(@"AdMob applicationMuted=%d -> MaticooAds.videoMute", muted);
}

+ (nullable NSNumber *)zmat_numberValueForKey:(NSString *)key onObject:(NSObject *)object {
    if (key.length == 0 || !object) {
        return nil;
    }
    if (![object respondsToSelector:NSSelectorFromString(key)]) {
        return nil;
    }
    @try {
        id raw = [object valueForKey:key];
        return [raw isKindOfClass:[NSNumber class]] ? raw : nil;
    } @catch (__unused NSException *ex) {
        return nil;
    }
}

+ (void)applyAdMobAgeRestrictedTreatment {
    GADRequestConfiguration *config = GADMobileAds.sharedInstance.requestConfiguration;

    // GMA ≥ 13.3：ageRestrictedTreatment；默认 Unspecified(0) 时继续看旧字段。
    NSNumber *ageNumber = [self zmat_numberValueForKey:@"ageRestrictedTreatment" onObject:config];
    if (ageNumber != nil && ageNumber.integerValue != kMATAdMobAgeTreatmentUnspecified) {
        BOOL restricted = (ageNumber.integerValue == kMATAdMobAgeTreatmentChild);
        [[MaticooAds shareSDK] setIsAgeRestrictedUser:restricted];
        MaticooAdMobAdapterDebugLog(@"AdMob ageRestrictedTreatment=%@ -> setIsAgeRestrictedUser:%d",
                                    ageNumber, restricted);
        return;
    }

    // GMA < 13.3 或媒体只写了旧 API。
    NSNumber *childDirected = [self zmat_numberValueForKey:@"tagForChildDirectedTreatment" onObject:config];
    if (childDirected != nil) {
        [[MaticooAds shareSDK] setIsAgeRestrictedUser:childDirected.boolValue];
        MaticooAdMobAdapterDebugLog(@"AdMob tagForChildDirectedTreatment=%@ -> setIsAgeRestrictedUser:%d",
                                    childDirected, childDirected.boolValue);
        return;
    }

    MaticooAdMobAdapterDebugLog(@"AdMob age treatment unset (new=%@ old=%@), skip",
                                ageNumber, childDirected);
}

@end
