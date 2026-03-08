#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(FaroReactNative, NSObject)

RCT_EXTERN_METHOD(initialize:(NSString *)configJson
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(pushLog:(NSString *)level
                  message:(NSString *)message
                  context:(NSString *)context
                  timestamp:(NSString *)timestamp)

RCT_EXTERN_METHOD(pushError:(NSString *)type
                  value:(NSString *)value
                  stacktrace:(NSString *)stacktrace
                  context:(NSString *)context)

RCT_EXTERN_METHOD(pushMeasurement:(NSString *)type
                  values:(NSString *)values
                  context:(NSString *)context)

RCT_EXTERN_METHOD(pushEvent:(NSString *)name
                  attributes:(NSString *)attributes
                  domain:(NSString *)domain)

RCT_EXTERN_METHOD(setUser:(NSString *)userJson)
RCT_EXTERN_METHOD(resetUser)
RCT_EXTERN_METHOD(setSession:(NSString *)sessionId)
RCT_EXTERN_METHOD(setView:(NSString *)viewName)
RCT_EXTERN_METHOD(pause)
RCT_EXTERN_METHOD(unpause)

RCT_EXTERN_METHOD(getDeviceInfo:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

@end
