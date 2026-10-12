// LDDiskCache — offline cache (mirrors web IndexedDB usage) + failed-upload outbox.
// Everything is plain JSON files under Library/Caches + Documents/Outbox. iOS 12 safe.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LDDiskCache : NSObject
// Response caches (overwrite on success, read on network failure).
+ (void)saveMomentsJSON:(id)json;
+ (nullable id)loadMomentsJSON;
+ (void)saveFriendsJSON:(id)json;
+ (nullable id)loadFriendsJSON;
+ (void)saveMessagesJSON:(id)json;
+ (nullable id)loadMessagesJSON;
+ (void)saveOverlaysJSON:(id)json;
+ (nullable id)loadOverlaysJSON;

// Outbox: @{ filePath, isVideo, caption, audience, createdAt } — filePath points
// at a persistent copy under Documents/Outbox (tmp files may vanish).
+ (nullable NSDictionary *)stageOutboxItemWithFileURL:(NSURL *)src
                                             isVideo:(BOOL)isVideo
                                             caption:(NSString *)caption
                                            audience:(NSString *)audience;
+ (NSArray<NSDictionary *> *)pendingOutboxItems;
+ (void)removeOutboxItem:(NSString *)itemId;
+ (void)markOutboxSent:(NSString *)itemId error:(nullable NSString *)error;
// Maintenance for the Settings page.
+ (NSUInteger)outboxCount;
+ (void)clearOutbox;
+ (void)clearCaches;
@end

NS_ASSUME_NONNULL_END
