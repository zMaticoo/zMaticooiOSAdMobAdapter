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

@property(nonatomic) NSDictionary * localExtra;

@end

NS_ASSUME_NONNULL_END
