#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class KDArtworkSession;

@interface KDSessionStore : NSObject

- (NSArray<KDArtworkSession *> *)loadSessions;
- (KDArtworkSession *)saveImage:(UIImage *)image existingSession:(KDArtworkSession *)existingSession;
- (UIImage *)artworkImageForSession:(KDArtworkSession *)session;
- (UIImage *)thumbnailImageForSession:(KDArtworkSession *)session;
- (void)deleteSession:(KDArtworkSession *)session;
- (BOOL)hasSavedSessions;
- (BOOL)saveDraftImage:(UIImage *)image;
- (UIImage *)loadDraftImage;
- (void)clearDraftImage;

@end
