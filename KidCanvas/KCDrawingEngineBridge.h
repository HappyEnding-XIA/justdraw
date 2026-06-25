#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C interface for the Swift `KCDrawingEngineBridge` class
/// (declared in `KCDrawingEngineBridge.swift` with `@objc(KCDrawingEngineBridge)`).
///
/// This header is hand-authored to mirror what the auto-generated
/// `KidCanvas-Swift.h` would expose. It is required because, in this project's
/// current Xcode configuration, the auto-generated Swift header is emitted empty
/// (an Xcode 16 `-experimental-emit-module-separately` quirk). The method
/// selectors below are verified against the compiled Swift object file.
///
/// Once the auto-generated header issue is resolved (or the canvas is migrated
/// fully to Swift), this header can be removed in favor of
/// `#import "KidCanvas-Swift.h"`.
///
/// Selector verification command:
///   strings <DerivedData>/.../KCDrawingEngineBridge.o | grep "With..."
@interface KCDrawingEngineBridge : NSObject

// MARK: - Flood fill

/// Flood fills `image`, seeded at pixel coordinates (`startX`, `startY`), with
/// `fillColor`, using the prototype's `tolerance * 4` Manhattan-delta rule.
/// Returns the filled image, or `nil` if no pixels changed.
+ (CGImageRef _Nullable)floodFillImage:(CGImageRef)image
                                startX:(NSInteger)startX
                                startY:(NSInteger)startY
                             fillColor:(UIColor *)fillColor
                             tolerance:(double)tolerance;

// MARK: - Color sampling

/// Samples a single pixel color from `image` at pixel coordinates (`x`, `y`),
/// using the same 1x1 bitmap-context approach as the prototype's eyedropper.
+ (UIColor *_Nullable)sampleColorFromImage:(CGImageRef)image
                                        x:(NSInteger)x
                                        y:(NSInteger)y;

// MARK: - Pressure normalization

/// Normalizes raw force values into the prototype's pressure range
/// (0.65–1.45 for Pencil, 0.92–1.18 for finger). Returns 1.0 when the device
/// does not report force (`maximumPossibleForce <= 0`).
+ (double)normalizedPressureWithForce:(double)force
                maximumPossibleForce:(double)maximumPossibleForce
                            isPencil:(BOOL)isPencil;

// MARK: - Stroke rendering metrics

/// Returns the rendered line width for the given brush configuration.
/// The caller (`drawStroke:`) handles the eraser pressure override
/// (forces pressure = 1.0 for eraser) before calling this method.
/// `brushStyle` matches OC `KDBrushStyle`: 0 = pencil, 1 = pen, 2 = crayon.
+ (CGFloat)renderedStrokeLineWidthWithBrushStyle:(NSInteger)brushStyle
                                       lineWidth:(CGFloat)lineWidth
                                averagePressure:(CGFloat)pressure;

/// Returns the rendered alpha for the given brush configuration.
+ (CGFloat)renderedStrokeAlphaWithBrushStyle:(NSInteger)brushStyle
                                   lineWidth:(CGFloat)lineWidth
                            averagePressure:(CGFloat)pressure;

// MARK: - Eraser stamp path

/// Returns a `UIBezierPath` for the given eraser shape at `center` and `size`.
/// `shape` matches OC `KDEraserShape`: 0 = circle, 1 = cloud, 2 = star.
+ (UIBezierPath *_Nullable)eraserStampPathWithShape:(NSInteger)shape
                                             center:(CGPoint)center
                                               size:(CGFloat)size;

// MARK: - Eraser stamp interpolation

/// Returns interpolated stamp center positions along `path`, spaced by
/// `max(6, lineWidth * 0.38)`. Returns NSValue-wrapped CGPoint array.
+ (NSArray<NSValue *> *)eraserStampPointsAlongPath:(CGPathRef)path
                                         lineWidth:(CGFloat)lineWidth;

@end

NS_ASSUME_NONNULL_END
