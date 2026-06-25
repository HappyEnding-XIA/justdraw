//
//  KDDrawingCanvasView.m
//  KidCanvas
//
//  Created by 小大 on 2026/6/25.
//

#import "KDDrawingCanvasView.h"
#import "KCDrawingEngineBridge.h"

#import <stdint.h>
#import <limits.h>
#import <math.h>

static const NSUInteger KDMaximumHistoryStates = 48;
static const CGFloat KDStickerMinimumScale = 0.48;
static const CGFloat KDStickerMaximumScale = 2.6;

@interface KDStroke : NSObject

@property (nonatomic, strong) UIBezierPath *path;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, assign) CGFloat pressureTotal;
@property (nonatomic, assign) NSInteger pressureSampleCount;
@property (nonatomic, assign) CGPoint startPoint;
@property (nonatomic, assign) BOOL dotStroke;
@property (nonatomic, assign) KDToolMode toolMode;
@property (nonatomic, assign) KDBrushStyle brushStyle;
@property (nonatomic, assign) KDEraserShape eraserShape;

- (CGFloat)averagePressure;

@end

@implementation KDStroke

- (CGFloat)averagePressure {
    if (self.pressureSampleCount <= 0) {
        return 1.0;
    }
    return self.pressureTotal / (CGFloat)self.pressureSampleCount;
}

@end

@interface KDStickerView : UIImageView

@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, strong) UIColor *symbolColor;

@end

@implementation KDStickerView

@end

@interface KDStickerState : NSObject

@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, strong) UIColor *symbolColor;
@property (nonatomic, assign) CGPoint center;
@property (nonatomic, assign) CGAffineTransform transform;

@end

@implementation KDStickerState

@end

@interface KDCanvasState : NSObject

@property (nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic, strong) NSArray<KDStroke *> *strokes;
@property (nonatomic, strong) NSArray<KDStickerState *> *stickers;

@end

@implementation KDCanvasState

@end

@interface KDDrawingCanvasView () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) NSMutableArray<KDStroke *> *strokes;
@property (nonatomic, strong) NSMutableArray<KDStickerView *> *stickers;
@property (nonatomic, strong) NSMutableArray<KDCanvasState *> *undoStates;
@property (nonatomic, strong) NSMutableArray<KDCanvasState *> *redoStates;
@property (nonatomic, strong) KDStroke *activeStroke;
@property (nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic, strong) KDCanvasState *pendingStrokeState;
@property (nonatomic, strong) KDCanvasState *pendingStickerTransformState;
@property (nonatomic, assign) BOOL activeStrokeDidMutate;
@property (nonatomic, assign) BOOL stickerTransformDidMutate;
@property (nonatomic, assign) NSInteger activeStickerGestureCount;
@property (nonatomic, weak) KDStickerView *selectedStickerView;

- (void)addPressureSampleFromTouch:(UITouch *)touch toStroke:(KDStroke *)stroke;
- (CGFloat)normalizedPressureForTouch:(UITouch *)touch;
- (void)drawCrayonGrainForPath:(UIBezierPath *)path color:(UIColor *)color lineWidth:(CGFloat)lineWidth;
- (void)clearHistoryStacks;
- (void)trimHistoryStack:(NSMutableArray<KDCanvasState *> *)stack;
- (void)constrainStickerView:(KDStickerView *)sticker;
- (void)constrainStickerScale:(KDStickerView *)sticker;
- (void)constrainStickerCenter:(KDStickerView *)sticker;

@end

@implementation KDDrawingCanvasView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.multipleTouchEnabled = YES;
        _strokes = [NSMutableArray array];
        _stickers = [NSMutableArray array];
        _undoStates = [NSMutableArray array];
        _redoStates = [NSMutableArray array];
        _currentColor = [UIColor colorWithRed:0.94 green:0.43 blue:0.45 alpha:1.0];
        _currentLineWidth = 12.0;
        _currentToolMode = KDToolModeBrush;
        _currentBrushStyle = KDBrushStylePencil;
        _currentEraserShape = KDEraserShapeCircle;
        _currentStickerSymbol = @"star.fill";
        _fillTolerance = 28.0;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    [[UIColor whiteColor] setFill];
    UIRectFill(self.bounds);
    [self drawImage:self.backgroundImage aspectFitInRect:self.bounds];

    for (KDStroke *stroke in self.strokes) {
        [self drawStroke:stroke];
    }

    if (self.activeStroke) {
        [self drawStroke:self.activeStroke];
    }
}

- (void)drawStroke:(KDStroke *)stroke {
    UIColor *strokeColor = stroke.toolMode == KDToolModeEraser ? [UIColor whiteColor] : stroke.color;
    CGFloat pressure = stroke.toolMode == KDToolModeEraser ? 1.0 : [stroke averagePressure];
    CGFloat renderedLineWidth = [KCDrawingEngineBridge renderedStrokeLineWidthWithBrushStyle:stroke.brushStyle
                                                                               lineWidth:stroke.lineWidth
                                                                        averagePressure:pressure];
    CGFloat alpha = [KCDrawingEngineBridge renderedStrokeAlphaWithBrushStyle:stroke.brushStyle
                                                                lineWidth:stroke.lineWidth
                                                         averagePressure:pressure];

    if (stroke.toolMode == KDToolModeEraser && stroke.eraserShape != KDEraserShapeCircle) {
        [self drawStampedEraserStroke:stroke color:strokeColor];
        return;
    }

    [[strokeColor colorWithAlphaComponent:alpha] setStroke];
    UIBezierPath *renderPath = [stroke.path copy];
    renderPath.lineCapStyle = kCGLineCapRound;
    renderPath.lineJoinStyle = kCGLineJoinRound;
    renderPath.lineWidth = renderedLineWidth;
    [renderPath stroke];

    if (stroke.brushStyle == KDBrushStylePencil && stroke.toolMode != KDToolModeEraser) {
        [[strokeColor colorWithAlphaComponent:0.16] setStroke];
        UIBezierPath *softPath = [renderPath copy];
        softPath.lineWidth = MAX(1.0, renderedLineWidth * 1.45);
        [softPath stroke];
    }

    if (stroke.brushStyle == KDBrushStyleCrayon && stroke.toolMode != KDToolModeEraser) {
        for (NSInteger index = 0; index < 3; index++) {
            [[strokeColor colorWithAlphaComponent:0.16] setStroke];
            UIBezierPath *texturePath = [renderPath copy];
            texturePath.lineWidth = MAX(1.0, renderedLineWidth * 0.28);
            CGAffineTransform transform = CGAffineTransformMakeTranslation((CGFloat)(index - 1) * 1.8, (CGFloat)(index % 2 == 0 ? 1.2 : -1.2));
            [texturePath applyTransform:transform];
            [texturePath stroke];
        }
        [self drawCrayonGrainForPath:renderPath color:strokeColor lineWidth:renderedLineWidth];
    }
}

- (void)drawCrayonGrainForPath:(UIBezierPath *)path color:(UIColor *)color lineWidth:(CGFloat)lineWidth {
    CGRect bounds = CGPathGetBoundingBox(path.CGPath);
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    CGRect grainBounds = CGRectInset(bounds, -lineWidth * 0.5, -lineWidth * 0.5);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    UIBezierPath *clipPath = [path copy];
    clipPath.lineWidth = MAX(2.0, lineWidth * 1.06);
    clipPath.lineCapStyle = kCGLineCapRound;
    clipPath.lineJoinStyle = kCGLineJoinRound;
    [clipPath addClip];

    [[color colorWithAlphaComponent:0.18] setStroke];
    CGFloat spacing = MAX(4.0, lineWidth * 0.46);
    NSInteger columnCount = MIN(220, MAX(1, (NSInteger)ceil(CGRectGetWidth(grainBounds) / spacing)));
    NSInteger rowCount = MIN(180, MAX(1, (NSInteger)ceil(CGRectGetHeight(grainBounds) / spacing)));
    for (NSInteger row = 0; row <= rowCount; row++) {
        for (NSInteger column = 0; column <= columnCount; column++) {
            NSUInteger seed = (NSUInteger)(row * 37 + column * 17);
            CGFloat jitterX = (CGFloat)((seed % 7) - 3) * 0.34;
            CGFloat jitterY = (CGFloat)(((seed / 3) % 7) - 3) * 0.28;
            CGFloat x = CGRectGetMinX(grainBounds) + column * spacing + jitterX;
            CGFloat y = CGRectGetMinY(grainBounds) + row * spacing + jitterY;
            CGFloat dashLength = MAX(1.5, lineWidth * (0.10 + (CGFloat)(seed % 5) * 0.018));

            UIBezierPath *dash = [UIBezierPath bezierPath];
            dash.lineWidth = MAX(0.7, lineWidth * 0.045);
            dash.lineCapStyle = kCGLineCapRound;
            [dash moveToPoint:CGPointMake(x - dashLength * 0.5, y)];
            [dash addLineToPoint:CGPointMake(x + dashLength * 0.5, y + ((seed % 2 == 0) ? 0.7 : -0.7))];
            [dash stroke];
        }
    }

    CGContextRestoreGState(context);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (event.allTouches.count > 1) {
        return;
    }

    UITouch *touch = touches.anyObject;
    CGPoint point = [touch locationInView:self];

    if ([self hitTestStickerAtPoint:point]) {
        return;
    }

    if (self.currentToolMode == KDToolModePicker) {
        UIColor *pickedColor = [self colorAtPoint:point];
        self.currentColor = pickedColor ?: self.currentColor;
        [self.delegate drawingCanvasView:self didPickColor:self.currentColor];
        return;
    }

    if (self.currentToolMode == KDToolModeFill) {
        KDCanvasState *previousState = [self canvasStateSnapshot];
        if ([self performFloodFillAtPoint:point color:self.currentColor]) {
            [self commitUndoStateSnapshot:previousState];
        }
        return;
    }

    if (self.currentToolMode == KDToolModeSticker) {
        CGPoint normalized = CGPointMake(point.x / MAX(CGRectGetWidth(self.bounds), 1.0),
                                         point.y / MAX(CGRectGetHeight(self.bounds), 1.0));
        [self insertStickerSymbol:self.currentStickerSymbol atNormalizedPoint:normalized];
        return;
    }

    self.pendingStrokeState = [self canvasStateSnapshot];
    self.activeStrokeDidMutate = NO;
    self.activeStroke = [[KDStroke alloc] init];
    self.activeStroke.color = self.currentColor;
    self.activeStroke.lineWidth = self.currentToolMode == KDToolModeEraser ? MAX(16.0, self.currentLineWidth * 1.35) : self.currentLineWidth;
    self.activeStroke.toolMode = self.currentToolMode;
    self.activeStroke.brushStyle = self.currentBrushStyle;
    self.activeStroke.eraserShape = self.currentEraserShape;
    self.activeStroke.path = [UIBezierPath bezierPath];
    self.activeStroke.path.lineWidth = self.activeStroke.lineWidth;
    self.activeStroke.startPoint = point;
    [self addPressureSampleFromTouch:touch toStroke:self.activeStroke];
    [self.activeStroke.path moveToPoint:point];

    [self deselectSticker];
    [self setNeedsDisplay];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (event.allTouches.count > 1) {
        self.activeStroke = nil;
        self.pendingStrokeState = nil;
        self.activeStrokeDidMutate = NO;
        [self setNeedsDisplay];
        return;
    }

    if (!self.activeStroke) {
        return;
    }

    UITouch *touch = touches.anyObject;
    NSArray<UITouch *> *coalescedTouches = [event coalescedTouchesForTouch:touch] ?: @[touch];
    for (UITouch *coalescedTouch in coalescedTouches) {
        CGPoint point = [coalescedTouch locationInView:self];
        CGFloat dx = point.x - self.activeStroke.startPoint.x;
        CGFloat dy = point.y - self.activeStroke.startPoint.y;
        if (!self.activeStrokeDidMutate && hypot(dx, dy) < 2.0) {
            continue;
        }

        [self.activeStroke.path addLineToPoint:point];
        [self addPressureSampleFromTouch:coalescedTouch toStroke:self.activeStroke];
        self.activeStrokeDidMutate = YES;
    }
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.activeStroke) {
        return;
    }

    UITouch *touch = touches.anyObject;
    CGPoint point = [touch locationInView:self];
    if (self.activeStrokeDidMutate) {
        [self.activeStroke.path addLineToPoint:point];
        [self addPressureSampleFromTouch:touch toStroke:self.activeStroke];
    } else {
        CGFloat dotRadius = MAX(1.0, self.activeStroke.lineWidth * 0.5);
        self.activeStroke.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(self.activeStroke.startPoint.x - dotRadius,
                                                                                   self.activeStroke.startPoint.y - dotRadius,
                                                                                   dotRadius * 2.0,
                                                                                   dotRadius * 2.0)];
        self.activeStroke.path.lineWidth = self.activeStroke.lineWidth;
        self.activeStroke.dotStroke = YES;
        self.activeStrokeDidMutate = YES;
        [self addPressureSampleFromTouch:touch toStroke:self.activeStroke];
    }
    [self commitUndoStateSnapshot:self.pendingStrokeState];
    [self.strokes addObject:self.activeStroke];
    self.activeStroke = nil;
    self.pendingStrokeState = nil;
    self.activeStrokeDidMutate = NO;
    [self setNeedsDisplay];
    [self notifyContentChanged];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.activeStroke = nil;
    self.pendingStrokeState = nil;
    self.activeStrokeDidMutate = NO;
    [self setNeedsDisplay];
}

- (void)addPressureSampleFromTouch:(UITouch *)touch toStroke:(KDStroke *)stroke {
    stroke.pressureTotal += [self normalizedPressureForTouch:touch];
    stroke.pressureSampleCount += 1;
}

- (CGFloat)normalizedPressureForTouch:(UITouch *)touch {
    return [KCDrawingEngineBridge normalizedPressureWithForce:touch.force
                                     maximumPossibleForce:touch.maximumPossibleForce
                                                 isPencil:(touch.type == UITouchTypePencil)];
}

- (void)undoLastAction {
    if (self.undoStates.count == 0) {
        return;
    }

    KDCanvasState *currentState = [self canvasStateSnapshot];
    [self.redoStates addObject:currentState];
    [self trimHistoryStack:self.redoStates];

    KDCanvasState *state = self.undoStates.lastObject;
    [self.undoStates removeLastObject];
    [self applyCanvasState:state];
    [self notifyContentChanged];
}

- (void)redoLastAction {
    if (self.redoStates.count == 0) {
        return;
    }

    KDCanvasState *currentState = [self canvasStateSnapshot];
    [self.undoStates addObject:currentState];
    [self trimHistoryStack:self.undoStates];

    KDCanvasState *state = self.redoStates.lastObject;
    [self.redoStates removeLastObject];
    [self applyCanvasState:state];
    [self notifyContentChanged];
}

- (void)clearCanvas {
    if (![self canvasHasVisibleContent]) {
        return;
    }
    [self commitCurrentStateForUndo];
    [self resetCanvasContents];
    [self setNeedsDisplay];
    [self notifyContentChanged];
}

- (void)startBlankCanvas {
    [self resetCanvasContents];
    [self clearHistoryStacks];
    [self setNeedsDisplay];
    [self notifyContentChanged];
}

- (UIImage *)snapshotImage {
    KDStickerView *selectedSticker = self.selectedStickerView;
    CGFloat selectedBorderWidth = selectedSticker.layer.borderWidth;
    CGColorRef selectedBorderColor = selectedSticker.layer.borderColor;
    selectedSticker.layer.borderWidth = 0.0;

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:self.bounds];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [self.layer renderInContext:rendererContext.CGContext];
    }];

    selectedSticker.layer.borderWidth = selectedBorderWidth;
    selectedSticker.layer.borderColor = selectedBorderColor;
    return image;
}

- (UIImage *)rasterImageExcludingStickers {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:self.bounds];
    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [[UIColor whiteColor] setFill];
        UIRectFill(self.bounds);
        [self drawImage:self.backgroundImage aspectFitInRect:self.bounds];

        for (KDStroke *stroke in self.strokes) {
            [self drawStroke:stroke];
        }
    }];
}

- (void)drawImage:(UIImage *)image aspectFitInRect:(CGRect)rect {
    if (!image) {
        return;
    }

    CGSize imageSize = image.size;
    if (imageSize.width <= 0.0 || imageSize.height <= 0.0 || CGRectIsEmpty(rect)) {
        return;
    }

    CGFloat scale = MIN(CGRectGetWidth(rect) / imageSize.width, CGRectGetHeight(rect) / imageSize.height);
    CGSize drawSize = CGSizeMake(imageSize.width * scale, imageSize.height * scale);
    CGRect drawRect = CGRectMake(CGRectGetMidX(rect) - drawSize.width / 2.0,
                                 CGRectGetMidY(rect) - drawSize.height / 2.0,
                                 drawSize.width,
                                 drawSize.height);
    [image drawInRect:drawRect];
}

- (void)replaceCanvasWithImage:(UIImage *)image {
    [self resetCanvasContents];
    [self clearHistoryStacks];
    self.backgroundImage = image;
    [self setNeedsDisplay];
    [self notifyContentChanged];
}

- (void)restoreCanvasWithImage:(UIImage *)image {
    [self resetCanvasContents];
    [self clearHistoryStacks];
    self.backgroundImage = image;
    [self setNeedsDisplay];
    [self notifyContentChanged];
}

- (void)insertStickerSymbol:(NSString *)symbol atNormalizedPoint:(CGPoint)normalizedPoint {
    [self commitCurrentStateForUndo];
    KDStickerView *sticker = [self makeStickerViewWithSymbol:(symbol.length > 0 ? symbol : @"star.fill") color:self.currentColor];
    sticker.center = CGPointMake(normalizedPoint.x * CGRectGetWidth(self.bounds), normalizedPoint.y * CGRectGetHeight(self.bounds));
    [self constrainStickerView:sticker];
    [self.stickers addObject:sticker];
    [self addSubview:sticker];
    [self bringSubviewToFront:sticker];
    [self selectStickerView:sticker];
    [self setNeedsDisplay];
    [self notifyContentChanged];
}

- (void)deleteSelectedSticker {
    if (!self.selectedStickerView) {
        return;
    }

    [self commitCurrentStateForUndo];
    [self.stickers removeObject:self.selectedStickerView];
    [self.selectedStickerView removeFromSuperview];
    [self deselectSticker];
    [self setNeedsDisplay];
    [self notifyContentChanged];
}

- (void)bringSelectedStickerToFront {
    if (!self.selectedStickerView) {
        return;
    }

    [self commitCurrentStateForUndo];
    [self bringSubviewToFront:self.selectedStickerView];
    [self.stickers removeObject:self.selectedStickerView];
    [self.stickers addObject:self.selectedStickerView];
    [self notifySelectionChanged];
    [self notifyContentChanged];
}

- (BOOL)hasSelectedSticker {
    return self.selectedStickerView != nil;
}

- (void)loadLineArtImage:(UIImage *)image {
    [self resetCanvasContents];
    [self clearHistoryStacks];
    self.backgroundImage = image;
    [self setNeedsDisplay];
    [self notifyContentChanged];
}

- (KDCanvasState *)canvasStateSnapshot {
    KDCanvasState *state = [[KDCanvasState alloc] init];
    state.backgroundImage = self.backgroundImage;

    NSMutableArray<KDStroke *> *strokeCopies = [NSMutableArray arrayWithCapacity:self.strokes.count];
    for (KDStroke *stroke in self.strokes) {
        [strokeCopies addObject:[self copyOfStroke:stroke]];
    }
    state.strokes = strokeCopies;

    NSMutableArray<KDStickerState *> *stickerStates = [NSMutableArray arrayWithCapacity:self.stickers.count];
    for (KDStickerView *sticker in self.stickers) {
        [stickerStates addObject:[self stickerStateFromView:sticker]];
    }
    state.stickers = stickerStates;
    return state;
}

- (void)commitCurrentStateForUndo {
    [self commitUndoStateSnapshot:[self canvasStateSnapshot]];
}

- (void)commitUndoStateSnapshot:(KDCanvasState *)state {
    if (!state) {
        return;
    }
    [self.undoStates addObject:state];
    [self trimHistoryStack:self.undoStates];
    [self.redoStates removeAllObjects];
}

- (void)clearHistoryStacks {
    [self.undoStates removeAllObjects];
    [self.redoStates removeAllObjects];
}

- (void)trimHistoryStack:(NSMutableArray<KDCanvasState *> *)stack {
    while (stack.count > KDMaximumHistoryStates) {
        [stack removeObjectAtIndex:0];
    }
}

- (void)applyCanvasState:(KDCanvasState *)state {
    [self resetCanvasContents];
    self.backgroundImage = state.backgroundImage;

    for (KDStroke *stroke in state.strokes) {
        [self.strokes addObject:[self copyOfStroke:stroke]];
    }

    for (KDStickerState *stickerState in state.stickers) {
        KDStickerView *sticker = [self stickerViewFromState:stickerState];
        [self.stickers addObject:sticker];
        [self addSubview:sticker];
    }

    [self deselectSticker];
    [self setNeedsDisplay];
}

- (void)resetCanvasContents {
    [self.strokes removeAllObjects];
    for (KDStickerView *sticker in self.stickers) {
        [sticker removeFromSuperview];
    }
    [self.stickers removeAllObjects];
    self.backgroundImage = nil;
    self.activeStroke = nil;
    self.pendingStrokeState = nil;
    self.pendingStickerTransformState = nil;
    self.activeStrokeDidMutate = NO;
    self.stickerTransformDidMutate = NO;
    self.activeStickerGestureCount = 0;
    [self deselectSticker];
}

- (KDStroke *)copyOfStroke:(KDStroke *)stroke {
    KDStroke *copy = [[KDStroke alloc] init];
    copy.path = [stroke.path copy];
    copy.color = stroke.color;
    copy.lineWidth = stroke.lineWidth;
    copy.pressureTotal = stroke.pressureTotal;
    copy.pressureSampleCount = stroke.pressureSampleCount;
    copy.startPoint = stroke.startPoint;
    copy.dotStroke = stroke.dotStroke;
    copy.toolMode = stroke.toolMode;
    copy.brushStyle = stroke.brushStyle;
    copy.eraserShape = stroke.eraserShape;
    return copy;
}

- (KDStickerState *)stickerStateFromView:(KDStickerView *)sticker {
    KDStickerState *state = [[KDStickerState alloc] init];
    state.symbolName = sticker.symbolName;
    state.symbolColor = sticker.symbolColor;
    state.center = sticker.center;
    state.transform = sticker.transform;
    return state;
}

- (KDStickerView *)stickerViewFromState:(KDStickerState *)state {
    KDStickerView *sticker = [self makeStickerViewWithSymbol:state.symbolName color:state.symbolColor];
    sticker.center = state.center;
    sticker.transform = state.transform;
    [self constrainStickerView:sticker];
    return sticker;
}

- (BOOL)canvasHasVisibleContent {
    return [self canvasStateHasVisibleContent:[self canvasStateSnapshot]];
}

- (BOOL)canvasStateHasVisibleContent:(KDCanvasState *)state {
    return state.backgroundImage != nil || state.strokes.count > 0 || state.stickers.count > 0;
}

- (BOOL)performFloodFillAtPoint:(CGPoint)point color:(UIColor *)fillColor {
    UIImage *baseImage = [self rasterImageExcludingStickers];
    CGImageRef sourceImageRef = baseImage.CGImage;
    if (!sourceImageRef) {
        return NO;
    }

    size_t width = CGImageGetWidth(sourceImageRef);
    size_t height = CGImageGetHeight(sourceImageRef);
    if (width == 0 || height == 0) {
        return NO;
    }

    NSInteger startX = (NSInteger)MIN(MAX(point.x * baseImage.scale, 0), (CGFloat)(width - 1));
    NSInteger startY = (NSInteger)MIN(MAX(point.y * baseImage.scale, 0), (CGFloat)(height - 1));

    CGImageRef filledImage = [KCDrawingEngineBridge floodFillImage:sourceImageRef
                                                           startX:startX
                                                           startY:startY
                                                        fillColor:fillColor
                                                       tolerance:self.fillTolerance];
    if (!filledImage) {
        return NO;
    }

    self.backgroundImage = [UIImage imageWithCGImage:filledImage scale:baseImage.scale orientation:UIImageOrientationUp];
    [self.strokes removeAllObjects];
    [self setNeedsDisplay];
    [self notifyContentChanged];
    return YES;
}

- (UIColor *)colorAtPoint:(CGPoint)point {
    UIImage *image = [self snapshotImage];
    CGImageRef imageRef = image.CGImage;
    if (!imageRef) {
        return nil;
    }

    CGSize imageSize = image.size;
    if (imageSize.width <= 0.0 || imageSize.height <= 0.0) {
        return nil;
    }

    if (point.x < 0.0 || point.y < 0.0 || point.x >= imageSize.width || point.y >= imageSize.height) {
        return nil;
    }

    return [KCDrawingEngineBridge sampleColorFromImage:imageRef
                                                    x:(NSInteger)(point.x * image.scale)
                                                    y:(NSInteger)(point.y * image.scale)];
}

- (KDStickerView *)makeStickerViewWithSymbol:(NSString *)symbol color:(UIColor *)color {
    KDStickerView *sticker = [[KDStickerView alloc] initWithImage:[self stickerImageForSymbol:symbol pointSize:56.0 color:color]];
    sticker.symbolName = symbol;
    sticker.symbolColor = color;
    sticker.userInteractionEnabled = YES;
    sticker.bounds = CGRectMake(0, 0, 72, 72);
    sticker.contentMode = UIViewContentModeScaleAspectFit;
    sticker.layer.shadowColor = [UIColor colorWithRed:0.18 green:0.22 blue:0.28 alpha:1.0].CGColor;
    sticker.layer.shadowOpacity = 0.16;
    sticker.layer.shadowRadius = 8.0;
    sticker.layer.shadowOffset = CGSizeMake(0.0, 4.0);

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleStickerPan:)];
    pan.delegate = self;
    [sticker addGestureRecognizer:pan];

    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handleStickerPinch:)];
    pinch.delegate = self;
    [sticker addGestureRecognizer:pinch];

    UIRotationGestureRecognizer *rotation = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleStickerRotation:)];
    rotation.delegate = self;
    [sticker addGestureRecognizer:rotation];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleStickerTap:)];
    [sticker addGestureRecognizer:tap];

    return sticker;
}

- (void)drawStampedEraserStroke:(KDStroke *)stroke color:(UIColor *)strokeColor {
    [[strokeColor colorWithAlphaComponent:1.0] setFill];
    if (stroke.dotStroke) {
        UIBezierPath *stamp = [KCDrawingEngineBridge eraserStampPathWithShape:stroke.eraserShape center:stroke.startPoint size:stroke.lineWidth];
        [stamp fill];
        return;
    }

    NSArray<NSValue *> *stampPoints = [KCDrawingEngineBridge eraserStampPointsAlongPath:stroke.path.CGPath lineWidth:stroke.lineWidth];
    for (NSValue *value in stampPoints) {
        UIBezierPath *stamp = [KCDrawingEngineBridge eraserStampPathWithShape:stroke.eraserShape center:value.CGPointValue size:stroke.lineWidth];
        [stamp fill];
    }
}

- (void)handleStickerTap:(UITapGestureRecognizer *)recognizer {
    KDStickerView *sticker = (KDStickerView *)recognizer.view;
    [self selectStickerView:sticker];
}

- (void)handleStickerPan:(UIPanGestureRecognizer *)recognizer {
    KDStickerView *sticker = (KDStickerView *)recognizer.view;
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self beginStickerTransformIfNeededForSticker:sticker];
    }
    CGPoint translation = [recognizer translationInView:self];
    sticker.center = CGPointMake(sticker.center.x + translation.x, sticker.center.y + translation.y);
    [self constrainStickerCenter:sticker];
    [recognizer setTranslation:CGPointZero inView:self];
    self.stickerTransformDidMutate = YES;
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self endStickerTransformIfNeeded];
        [self notifySelectionChanged];
    }
    if (recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed) {
        [self endStickerTransformIfNeeded];
    }
}

- (void)handleStickerPinch:(UIPinchGestureRecognizer *)recognizer {
    KDStickerView *sticker = (KDStickerView *)recognizer.view;
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self beginStickerTransformIfNeededForSticker:sticker];
    }
    sticker.transform = CGAffineTransformScale(sticker.transform, recognizer.scale, recognizer.scale);
    [self constrainStickerScale:sticker];
    [self constrainStickerCenter:sticker];
    recognizer.scale = 1.0;
    self.stickerTransformDidMutate = YES;
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self endStickerTransformIfNeeded];
        [self notifySelectionChanged];
    }
    if (recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed) {
        [self endStickerTransformIfNeeded];
    }
}

- (void)handleStickerRotation:(UIRotationGestureRecognizer *)recognizer {
    KDStickerView *sticker = (KDStickerView *)recognizer.view;
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self beginStickerTransformIfNeededForSticker:sticker];
    }
    sticker.transform = CGAffineTransformRotate(sticker.transform, recognizer.rotation);
    [self constrainStickerView:sticker];
    recognizer.rotation = 0.0;
    self.stickerTransformDidMutate = YES;
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        [self endStickerTransformIfNeeded];
        [self notifySelectionChanged];
    }
    if (recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed) {
        [self endStickerTransformIfNeeded];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)constrainStickerView:(KDStickerView *)sticker {
    [self constrainStickerScale:sticker];
    [self constrainStickerCenter:sticker];
}

- (void)constrainStickerScale:(KDStickerView *)sticker {
    CGFloat currentScale = hypot(sticker.transform.a, sticker.transform.c);
    if (currentScale <= 0.0) {
        sticker.transform = CGAffineTransformIdentity;
        currentScale = 1.0;
    }

    CGFloat clampedScale = MIN(KDStickerMaximumScale, MAX(KDStickerMinimumScale, currentScale));
    if (fabs(clampedScale - currentScale) < 0.001) {
        return;
    }

    CGFloat correction = clampedScale / currentScale;
    sticker.transform = CGAffineTransformScale(sticker.transform, correction, correction);
}

- (void)constrainStickerCenter:(KDStickerView *)sticker {
    if (CGRectIsEmpty(self.bounds)) {
        return;
    }

    CGRect frame = sticker.frame;
    CGFloat halfWidth = MIN(CGRectGetWidth(self.bounds) * 0.5, MAX(24.0, CGRectGetWidth(frame) * 0.5));
    CGFloat halfHeight = MIN(CGRectGetHeight(self.bounds) * 0.5, MAX(24.0, CGRectGetHeight(frame) * 0.5));
    CGFloat minX = halfWidth;
    CGFloat maxX = MAX(minX, CGRectGetWidth(self.bounds) - halfWidth);
    CGFloat minY = halfHeight;
    CGFloat maxY = MAX(minY, CGRectGetHeight(self.bounds) - halfHeight);
    sticker.center = CGPointMake(MIN(maxX, MAX(minX, sticker.center.x)),
                                 MIN(maxY, MAX(minY, sticker.center.y)));
}

- (BOOL)hitTestStickerAtPoint:(CGPoint)point {
    for (KDStickerView *sticker in [self.stickers reverseObjectEnumerator]) {
        CGPoint localPoint = [self convertPoint:point toView:sticker];
        if ([sticker pointInside:localPoint withEvent:nil]) {
            [self selectStickerView:sticker];
            return YES;
        }
    }
    [self deselectSticker];
    return NO;
}

- (void)selectStickerView:(KDStickerView *)sticker {
    [self deselectSticker];
    self.selectedStickerView = sticker;
    sticker.layer.borderWidth = 2.0;
    sticker.layer.borderColor = [UIColor colorWithRed:0.42 green:0.74 blue:0.97 alpha:0.65].CGColor;
    sticker.layer.cornerRadius = 16.0;
    [self notifySelectionChanged];
}

- (void)deselectSticker {
    self.selectedStickerView.layer.borderWidth = 0.0;
    self.selectedStickerView = nil;
    [self notifySelectionChanged];
}

- (void)notifySelectionChanged {
    if ([self.delegate respondsToSelector:@selector(drawingCanvasViewSelectionDidChange:)]) {
        [self.delegate drawingCanvasViewSelectionDidChange:self];
    }
}

- (void)beginStickerTransformIfNeededForSticker:(KDStickerView *)sticker {
    if (self.activeStickerGestureCount == 0) {
        self.pendingStickerTransformState = [self canvasStateSnapshot];
        self.stickerTransformDidMutate = NO;
        [self selectStickerView:sticker];
    }
    self.activeStickerGestureCount += 1;
}

- (void)endStickerTransformIfNeeded {
    if (self.activeStickerGestureCount > 0) {
        self.activeStickerGestureCount -= 1;
    }

    if (self.activeStickerGestureCount == 0) {
        if (self.stickerTransformDidMutate) {
            [self commitUndoStateSnapshot:self.pendingStickerTransformState];
            [self notifyContentChanged];
        }
        self.pendingStickerTransformState = nil;
        self.stickerTransformDidMutate = NO;
    }
}

- (BOOL)canUndo {
    return self.undoStates.count > 0;
}

- (BOOL)canRedo {
    return self.redoStates.count > 0;
}

- (BOOL)hasVisibleContent {
    return [self canvasHasVisibleContent];
}

- (void)notifyContentChanged {
    if ([self.delegate respondsToSelector:@selector(drawingCanvasViewContentDidChange:)]) {
        [self.delegate drawingCanvasViewContentDidChange:self];
    }
}

- (UIImage *)stickerImageForSymbol:(NSString *)symbol pointSize:(CGFloat)pointSize color:(UIColor *)color {
    CGSize imageSize = CGSizeMake(72.0, 72.0);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:imageSize];
    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        NSString *resolvedSymbol = [UIImage systemImageNamed:symbol] ? symbol : @"star.fill";
        UIImageSymbolConfiguration *outlineConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize + 8.0 weight:UIImageSymbolWeightBold];
        UIImage *outlineImage = [[UIImage systemImageNamed:resolvedSymbol withConfiguration:outlineConfiguration] imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (outlineImage) {
            CGRect outlineRect = CGRectMake((imageSize.width - outlineImage.size.width) / 2.0,
                                            (imageSize.height - outlineImage.size.height) / 2.0,
                                            outlineImage.size.width,
                                            outlineImage.size.height);
            [outlineImage drawInRect:outlineRect];
        }

        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:UIImageSymbolWeightSemibold];
        UIImage *symbolImage = [[UIImage systemImageNamed:resolvedSymbol withConfiguration:configuration] imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
        if (symbolImage) {
            CGRect symbolRect = CGRectMake((imageSize.width - symbolImage.size.width) / 2.0,
                                           (imageSize.height - symbolImage.size.height) / 2.0,
                                           symbolImage.size.width,
                                           symbolImage.size.height);
            [symbolImage drawInRect:symbolRect];
        }
    }];
}

- (UIBezierPath *)eraserShapePathForShape:(KDEraserShape)shape center:(CGPoint)center size:(CGFloat)size {
    return [KCDrawingEngineBridge eraserStampPathWithShape:shape center:center size:size];
}

@end
