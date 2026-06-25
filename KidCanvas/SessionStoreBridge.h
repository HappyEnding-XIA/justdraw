#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// ObjC bridge over the Swift `SessionStore` (from `KCSessionPersistence`),
/// covering all operations that the OC `KDSessionStore` provides.
///
/// Session metadata is returned as NSDictionary arrays so OC code does not
/// need direct access to the Swift `ArtworkSession` type.
/// Selectors verified against compiled `.o` via `strings`.
@interface SessionStoreBridge : NSObject

+ (SessionStoreBridge *)shared;

// MARK: - Session queries

- (BOOL)hasSavedSessions;
- (NSInteger)sessionCount;
/// Returns all sessions as an array of dictionaries (newest first).
/// Keys: id, title, artworkFileName, thumbnailFileName, modifiedAt (NSDate).
- (NSArray<NSDictionary *> *)loadSessionDictionaries;

// MARK: - Artwork save (UIImage convenience)

/// Saves artwork from a UIImage. Generates PNG + 240×180 JPEG thumbnail
/// internally. If `existingSessionId` is non-nil, updates that session;
/// otherwise creates a new one. Returns the session dictionary, or nil.
- (NSDictionary *_Nullable)saveImage:(UIImage *)image
                    existingSessionId:(NSString *_Nullable)existingSessionId;

// MARK: - Artwork load (UIImage convenience)

/// Returns the full-resolution artwork as a UIImage.
- (UIImage *_Nullable)artworkImageForSessionId:(NSString *)sessionId;
/// Returns the thumbnail as a UIImage.
- (UIImage *_Nullable)thumbnailImageForSessionId:(NSString *)sessionId;

// MARK: - Session delete

- (void)deleteSessionWithId:(NSString *)sessionId;

// MARK: - Draft autosave (UIImage convenience)

- (BOOL)saveDraftImage:(UIImage *)image;
- (UIImage *_Nullable)loadDraftImage;
- (void)clearDraft;

@end

NS_ASSUME_NONNULL_END
