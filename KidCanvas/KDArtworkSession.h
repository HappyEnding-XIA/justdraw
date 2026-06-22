#import <Foundation/Foundation.h>

@interface KDArtworkSession : NSObject <NSSecureCoding>

@property (nonatomic, copy) NSString *sessionIdentifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artworkFileName;
@property (nonatomic, copy) NSString *thumbnailFileName;
@property (nonatomic, strong) NSDate *modifiedAt;

@end
