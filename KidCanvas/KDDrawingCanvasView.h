#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, KDToolMode) {
    KDToolModeBrush = 0,
    KDToolModeEraser,
    KDToolModeFill,
    KDToolModeSticker,
    KDToolModePicker
};

typedef NS_ENUM(NSInteger, KDBrushStyle) {
    KDBrushStylePencil = 0,
    KDBrushStylePen,
    KDBrushStyleCrayon
};

typedef NS_ENUM(NSInteger, KDEraserShape) {
    KDEraserShapeCircle = 0,
    KDEraserShapeCloud,
    KDEraserShapeStar
};

@class KDDrawingCanvasView;

@protocol KDDrawingCanvasViewDelegate <NSObject>

- (void)drawingCanvasView:(KDDrawingCanvasView *)canvasView didPickColor:(UIColor *)color;
@optional
- (void)drawingCanvasViewSelectionDidChange:(KDDrawingCanvasView *)canvasView;
- (void)drawingCanvasViewContentDidChange:(KDDrawingCanvasView *)canvasView;

@end

@interface KDDrawingCanvasView : UIView

@property (nonatomic, weak) id<KDDrawingCanvasViewDelegate> delegate;
@property (nonatomic, strong) UIColor *currentColor;
@property (nonatomic, assign) CGFloat currentLineWidth;
@property (nonatomic, assign) KDToolMode currentToolMode;
@property (nonatomic, assign) KDBrushStyle currentBrushStyle;
@property (nonatomic, assign) KDEraserShape currentEraserShape;
@property (nonatomic, copy) NSString *currentStickerSymbol;
@property (nonatomic, assign) CGFloat fillTolerance;

- (void)undoLastAction;
- (void)redoLastAction;
- (void)clearCanvas;
- (void)startBlankCanvas;
- (UIImage *)snapshotImage;
- (void)replaceCanvasWithImage:(UIImage *)image;
- (void)restoreCanvasWithImage:(UIImage *)image;
- (void)insertStickerSymbol:(NSString *)symbol atNormalizedPoint:(CGPoint)normalizedPoint;
- (void)loadLineArtImage:(UIImage *)image;
- (void)deleteSelectedSticker;
- (void)bringSelectedStickerToFront;
- (BOOL)hasSelectedSticker;
- (BOOL)canUndo;
- (BOOL)canRedo;
- (BOOL)hasVisibleContent;

@end
