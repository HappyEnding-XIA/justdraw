#import "KDArtworkSession.h"

@implementation KDArtworkSession

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _modifiedAt = [NSDate date];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.sessionIdentifier forKey:@"sessionIdentifier"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.artworkFileName forKey:@"artworkFileName"];
    [coder encodeObject:self.thumbnailFileName forKey:@"thumbnailFileName"];
    [coder encodeObject:self.modifiedAt forKey:@"modifiedAt"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _sessionIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"sessionIdentifier"];
        _title = [coder decodeObjectOfClass:[NSString class] forKey:@"title"];
        _artworkFileName = [coder decodeObjectOfClass:[NSString class] forKey:@"artworkFileName"];
        _thumbnailFileName = [coder decodeObjectOfClass:[NSString class] forKey:@"thumbnailFileName"];
        _modifiedAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"modifiedAt"];
    }
    return self;
}

@end
