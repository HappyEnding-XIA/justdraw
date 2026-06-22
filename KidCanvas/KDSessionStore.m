#import "KDSessionStore.h"

#import "KDArtworkSession.h"

@interface KDSessionStore ()

@property (nonatomic, strong) NSURL *sessionsDirectoryURL;
@property (nonatomic, strong) NSURL *metadataURL;
@property (nonatomic, strong) NSURL *draftURL;

@end

@implementation KDSessionStore

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURL *documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        _sessionsDirectoryURL = [documentsURL URLByAppendingPathComponent:@"KidCanvasSessions" isDirectory:YES];
        _metadataURL = [_sessionsDirectoryURL URLByAppendingPathComponent:@"sessions.archive"];
        _draftURL = [_sessionsDirectoryURL URLByAppendingPathComponent:@"draft.png"];
        [self ensureDirectoryExists];
    }
    return self;
}

- (NSArray<KDArtworkSession *> *)loadSessions {
    NSData *data = [NSData dataWithContentsOfURL:self.metadataURL];
    if (!data) {
        return @[];
    }

    NSSet *classes = [NSSet setWithObjects:[NSArray class], [KDArtworkSession class], [NSString class], [NSDate class], nil];
    NSError *error = nil;
    NSArray<KDArtworkSession *> *sessions = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:&error];
    if (error || !sessions) {
        return @[];
    }

    return [sessions sortedArrayUsingComparator:^NSComparisonResult(KDArtworkSession *lhs, KDArtworkSession *rhs) {
        NSDate *lhsDate = lhs.modifiedAt ?: [NSDate distantPast];
        NSDate *rhsDate = rhs.modifiedAt ?: [NSDate distantPast];
        return [rhsDate compare:lhsDate];
    }];
}

- (KDArtworkSession *)saveImage:(UIImage *)image existingSession:(KDArtworkSession *)existingSession {
    if (![self isValidImage:image]) {
        return nil;
    }

    [self ensureDirectoryExists];

    NSMutableArray<KDArtworkSession *> *sessions = [[self loadSessions] mutableCopy];
    KDArtworkSession *session = [self sessionByCopyingSession:existingSession] ?: [[KDArtworkSession alloc] init];
    if (session.sessionIdentifier.length == 0) {
        session.sessionIdentifier = [[NSUUID UUID] UUIDString];
        session.artworkFileName = [NSString stringWithFormat:@"%@.png", session.sessionIdentifier];
        session.thumbnailFileName = [NSString stringWithFormat:@"%@-thumb.jpg", session.sessionIdentifier];
    }

    session.modifiedAt = [NSDate date];
    if (session.title.length == 0) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"MMM d, HH:mm";
        session.title = [NSString stringWithFormat:@"Artwork %@", [formatter stringFromDate:session.modifiedAt]];
    }

    NSURL *artworkURL = [self.sessionsDirectoryURL URLByAppendingPathComponent:session.artworkFileName];
    NSURL *thumbnailURL = [self.sessionsDirectoryURL URLByAppendingPathComponent:session.thumbnailFileName];
    BOOL hadPreviousArtwork = [[NSFileManager defaultManager] fileExistsAtPath:artworkURL.path];
    BOOL hadPreviousThumbnail = [[NSFileManager defaultManager] fileExistsAtPath:thumbnailURL.path];
    NSData *previousArtworkData = hadPreviousArtwork ? [NSData dataWithContentsOfURL:artworkURL] : nil;
    NSData *previousThumbnailData = hadPreviousThumbnail ? [NSData dataWithContentsOfURL:thumbnailURL] : nil;

    NSData *pngData = UIImagePNGRepresentation(image);
    if (!pngData || ![pngData writeToURL:artworkURL atomically:YES]) {
        return nil;
    }

    UIImage *thumbnail = [self thumbnailImageFromImage:image];
    NSData *thumbData = UIImageJPEGRepresentation(thumbnail, 0.85);
    if (!thumbData || ![thumbData writeToURL:thumbnailURL atomically:YES]) {
        [self restoreFileAtURL:artworkURL previousData:previousArtworkData existed:hadPreviousArtwork];
        [self restoreFileAtURL:thumbnailURL previousData:previousThumbnailData existed:hadPreviousThumbnail];
        return nil;
    }

    NSUInteger existingIndex = [sessions indexOfObjectPassingTest:^BOOL(KDArtworkSession *candidate, NSUInteger idx, BOOL *stop) {
        return [candidate.sessionIdentifier isEqualToString:session.sessionIdentifier];
    }];

    if (existingIndex != NSNotFound) {
        sessions[existingIndex] = session;
    } else {
        [sessions insertObject:session atIndex:0];
    }

    if (![self persistSessions:sessions]) {
        [self restoreFileAtURL:artworkURL previousData:previousArtworkData existed:hadPreviousArtwork];
        [self restoreFileAtURL:thumbnailURL previousData:previousThumbnailData existed:hadPreviousThumbnail];
        return nil;
    }

    return session;
}

- (UIImage *)artworkImageForSession:(KDArtworkSession *)session {
    if (!session.artworkFileName.length) {
        return nil;
    }

    NSURL *url = [self.sessionsDirectoryURL URLByAppendingPathComponent:session.artworkFileName];
    NSData *data = [NSData dataWithContentsOfURL:url];
    return data ? [UIImage imageWithData:data] : nil;
}

- (UIImage *)thumbnailImageForSession:(KDArtworkSession *)session {
    if (!session.thumbnailFileName.length) {
        return nil;
    }

    NSURL *url = [self.sessionsDirectoryURL URLByAppendingPathComponent:session.thumbnailFileName];
    NSData *data = [NSData dataWithContentsOfURL:url];
    return data ? [UIImage imageWithData:data] : nil;
}

- (void)deleteSession:(KDArtworkSession *)session {
    if (!session.sessionIdentifier.length) {
        return;
    }

    NSMutableArray<KDArtworkSession *> *sessions = [[self loadSessions] mutableCopy];
    NSIndexSet *indexes = [sessions indexesOfObjectsPassingTest:^BOOL(KDArtworkSession *candidate, NSUInteger idx, BOOL *stop) {
        return [candidate.sessionIdentifier isEqualToString:session.sessionIdentifier];
    }];
    if (indexes.count == 0) {
        return;
    }

    if (session.artworkFileName.length > 0) {
        NSURL *artworkURL = [self.sessionsDirectoryURL URLByAppendingPathComponent:session.artworkFileName];
        [[NSFileManager defaultManager] removeItemAtURL:artworkURL error:nil];
    }
    if (session.thumbnailFileName.length > 0) {
        NSURL *thumbnailURL = [self.sessionsDirectoryURL URLByAppendingPathComponent:session.thumbnailFileName];
        [[NSFileManager defaultManager] removeItemAtURL:thumbnailURL error:nil];
    }

    [sessions removeObjectsAtIndexes:indexes];
    [self persistSessions:sessions];
}

- (BOOL)hasSavedSessions {
    return self.loadSessions.count > 0;
}

- (BOOL)saveDraftImage:(UIImage *)image {
    if (![self isValidImage:image]) {
        return NO;
    }

    [self ensureDirectoryExists];
    NSData *pngData = UIImagePNGRepresentation(image);
    return pngData && [pngData writeToURL:self.draftURL atomically:YES];
}

- (UIImage *)loadDraftImage {
    NSData *data = [NSData dataWithContentsOfURL:self.draftURL];
    return data ? [UIImage imageWithData:data] : nil;
}

- (void)clearDraftImage {
    [[NSFileManager defaultManager] removeItemAtURL:self.draftURL error:nil];
}

- (void)ensureDirectoryExists {
    [[NSFileManager defaultManager] createDirectoryAtURL:self.sessionsDirectoryURL withIntermediateDirectories:YES attributes:nil error:nil];
}

- (BOOL)persistSessions:(NSArray<KDArtworkSession *> *)sessions {
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:sessions requiringSecureCoding:YES error:&error];
    if (data && !error) {
        return [data writeToURL:self.metadataURL atomically:YES];
    }
    return NO;
}

- (UIImage *)thumbnailImageFromImage:(UIImage *)image {
    if (![self isValidImage:image]) {
        return nil;
    }

    CGSize targetSize = CGSizeMake(240.0, 180.0);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [[UIColor whiteColor] setFill];
        UIRectFill((CGRect){CGPointZero, targetSize});

        CGSize imageSize = image.size;
        CGFloat scale = MIN(targetSize.width / imageSize.width, targetSize.height / imageSize.height);
        CGSize drawSize = CGSizeMake(imageSize.width * scale, imageSize.height * scale);
        CGRect drawRect = CGRectMake((targetSize.width - drawSize.width) / 2.0,
                                     (targetSize.height - drawSize.height) / 2.0,
                                     drawSize.width,
                                     drawSize.height);
        [image drawInRect:drawRect];
    }];
}

- (BOOL)isValidImage:(UIImage *)image {
    return image != nil && image.size.width > 0.0 && image.size.height > 0.0;
}

- (KDArtworkSession *)sessionByCopyingSession:(KDArtworkSession *)session {
    if (!session) {
        return nil;
    }

    KDArtworkSession *copy = [[KDArtworkSession alloc] init];
    copy.sessionIdentifier = session.sessionIdentifier;
    copy.artworkFileName = session.artworkFileName;
    copy.thumbnailFileName = session.thumbnailFileName;
    copy.title = session.title;
    copy.modifiedAt = session.modifiedAt;
    return copy;
}

- (void)restoreFileAtURL:(NSURL *)url previousData:(NSData *)previousData existed:(BOOL)existed {
    if (existed && previousData) {
        [previousData writeToURL:url atomically:YES];
    } else {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    }
}

@end
