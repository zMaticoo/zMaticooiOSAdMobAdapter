//
//  MaticooAdMobAdapterDebugLog.h
//  Optional NSLog-style traces for MaticooAdMobAdapter (off unless MATICOO_ADMOB_ADAPTER_LOG is set).
//

#ifndef MaticooAdMobAdapterDebugLog_h
#define MaticooAdMobAdapterDebugLog_h

#ifdef MATICOO_ADMOB_ADAPTER_LOG
#define MaticooAdMobAdapterDebugLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define MaticooAdMobAdapterDebugLog(...)
#endif

#endif /* MaticooAdMobAdapterDebugLog_h */
