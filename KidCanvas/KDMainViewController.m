#import "KDMainViewController.h"

#import "KDArtworkSession.h"
#import "KDDrawingCanvasView.h"
#import "KDSessionStore.h"
#import <math.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static const void *KDPressBaseTransformKey = &KDPressBaseTransformKey;
static const void *KDPressBaseAlphaKey = &KDPressBaseAlphaKey;

@interface KDToolButton : UIButton

@property (nonatomic, assign) KDToolMode toolMode;

@end

@implementation KDToolButton

@end

@interface KDBrushButton : UIButton

@property (nonatomic, assign) KDBrushStyle brushStyle;
@property (nonatomic, assign) KDToolMode toolMode;
@property (nonatomic, assign) BOOL representsBrushStyle;

@end

@implementation KDBrushButton

@end

@interface KDLineArtItem : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) void (^drawingBlock)(CGRect rect);

+ (instancetype)itemWithTitle:(NSString *)title drawingBlock:(void (^)(CGRect rect))drawingBlock;

@end

@implementation KDLineArtItem

+ (instancetype)itemWithTitle:(NSString *)title drawingBlock:(void (^)(CGRect rect))drawingBlock {
    KDLineArtItem *item = [[KDLineArtItem alloc] init];
    item.title = title;
    item.drawingBlock = drawingBlock;
    return item;
}

@end

@interface KDMainViewController () <KDDrawingCanvasViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIColorPickerViewControllerDelegate>

@property (nonatomic, strong) UIView *canvasContainerView;
@property (nonatomic, strong) KDDrawingCanvasView *canvasView;
@property (nonatomic, strong) UISlider *sizeSlider;
@property (nonatomic, strong) NSArray<UIColor *> *palette24;
@property (nonatomic, strong) NSArray<UIColor *> *palette36;
@property (nonatomic, strong) NSMutableArray<UIColor *> *recentColors;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<NSString *> *> *stickerSymbolsByCategory;
@property (nonatomic, strong) NSArray<NSString *> *stickerCategories;
@property (nonatomic, copy) NSString *selectedStickerCategory;
@property (nonatomic, strong) NSArray<KDLineArtItem *> *lineArtItems;
@property (nonatomic, strong) NSMutableArray<UIButton *> *colorButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *recentColorButtons;
@property (nonatomic, strong) NSMutableArray<KDToolButton *> *toolButtons;
@property (nonatomic, strong) NSMutableArray<KDBrushButton *> *brushButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *historyThumbButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *stickerButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *stickerCategoryButtons;
@property (nonatomic, strong) UIButton *activeColorButton;
@property (nonatomic, strong) UIButton *palette24Button;
@property (nonatomic, strong) UIButton *palette36Button;
@property (nonatomic, strong) UIButton *customColorButton;
@property (nonatomic, strong) NSLayoutConstraint *paletteGridHeightConstraint;
@property (nonatomic, strong) UIStackView *recentColorRowStack;
@property (nonatomic, strong) UIButton *deleteHistoryButton;
@property (nonatomic, strong) UIButton *previousHistoryButton;
@property (nonatomic, strong) UIButton *nextHistoryButton;
@property (nonatomic, strong) UIButton *undoButton;
@property (nonatomic, strong) UIButton *redoButton;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIView *saveToastView;
@property (nonatomic, strong) UIView *sizePreviewView;
@property (nonatomic, strong) CAShapeLayer *sizePreviewShapeLayer;
@property (nonatomic, strong) UIButton *draftThumbButton;
@property (nonatomic, strong) UIButton *circleEraserButton;
@property (nonatomic, strong) UIButton *cloudEraserButton;
@property (nonatomic, strong) UIButton *starEraserButton;
@property (nonatomic, strong) UIButton *deleteStickerButton;
@property (nonatomic, strong) UIButton *frontStickerButton;
@property (nonatomic, strong) UIStackView *stickerRowStack;
@property (nonatomic, strong) KDSessionStore *sessionStore;
@property (nonatomic, strong) NSArray<KDArtworkSession *> *sessions;
@property (nonatomic, strong) KDArtworkSession *activeSession;
@property (nonatomic, strong) KDArtworkSession *selectedHistorySession;
@property (nonatomic, assign) BOOL showing36Palette;
@property (nonatomic, assign) NSInteger historyPageIndex;
@property (nonatomic, strong) NSTimer *draftSaveTimer;
@property (nonatomic, assign) BOOL suppressNextDraftSave;
@property (nonatomic, assign) BOOL activeSessionHasUnsavedChanges;
@property (nonatomic, assign) CGFloat lineArtStrokeScale;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *brushWidthsByStyle;
@property (nonatomic, assign) CGFloat eraserSliderValue;

@end

@implementation KDMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithRed:0.97 green:0.94 blue:0.89 alpha:1.0];
    self.lineArtStrokeScale = 1.0;
    self.palette24 = [self makePalette24];
    self.palette36 = [self makePalette36];
    self.recentColors = [[self loadRecentColors] mutableCopy];
    self.stickerCategories = @[@"Animals", @"Nature", @"Decor", @"Faces"];
    self.selectedStickerCategory = self.stickerCategories.firstObject;
    self.stickerSymbolsByCategory = @{
        @"Animals": @[@"butterfly.fill", @"pawprint.fill", @"tortoise.fill", @"hare.fill"],
        @"Nature": @[@"leaf.fill", @"camera.macro", @"sun.max.fill", @"cloud.fill"],
        @"Decor": @[@"star.fill", @"heart.fill", @"moon.stars.fill", @"rainbow", @"gift.fill"],
        @"Faces": @[@"face.smiling.fill", @"figure.2", @"hand.thumbsup.fill", @"sparkles"]
    };
    self.lineArtItems = [self makeLineArtItems];
    self.colorButtons = [NSMutableArray array];
    self.recentColorButtons = [NSMutableArray array];
    self.toolButtons = [NSMutableArray array];
    self.brushButtons = [NSMutableArray array];
    self.historyThumbButtons = [NSMutableArray array];
    self.stickerButtons = [NSMutableArray array];
    self.stickerCategoryButtons = [NSMutableArray array];
    self.sessionStore = [[KDSessionStore alloc] init];
    self.sessions = [self.sessionStore loadSessions];
    [self loadBrushWidthPreferences];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sceneWillResignActiveNotification:) name:UISceneWillDeactivateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sceneDidEnterBackgroundNotification:) name:UISceneDidEnterBackgroundNotification object:nil];

    [self buildInterface];
    [self updatePaletteButtons];
    [self reloadPaletteGrid];
    [self reloadStickerButtons];
    [self selectToolMode:KDToolModeBrush];
    [self selectBrushStyle:KDBrushStylePencil];
    [self selectColor:self.palette24.firstObject sender:nil];
    [self selectStickerSymbol:[self currentStickerSymbols].firstObject];
    [self refreshEraserShapeButtons];
    [self refreshStickerEditButtons];
    [self refreshHistoryUI];
    [self restoreDraftIfNeeded];
    [self refreshActionButtons];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self refreshSizePreview];
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

- (void)buildInterface {
    UIView *canvasContainer = [[UIView alloc] init];
    canvasContainer.translatesAutoresizingMaskIntoConstraints = NO;
    canvasContainer.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:canvasContainer];
    self.canvasContainerView = canvasContainer;

    self.canvasView = [[KDDrawingCanvasView alloc] init];
    self.canvasView.translatesAutoresizingMaskIntoConstraints = NO;
    self.canvasView.delegate = self;
    self.canvasView.clipsToBounds = YES;
    [canvasContainer addSubview:self.canvasView];
    [self installCanvasGesturesOnView:self.canvasView];

    UIView *topLeft = [self floatingPanel];
    UIView *topRight = [self floatingPanel];
    UIView *leftRail = [self floatingPanel];
    UIView *colorsPanel = [self floatingPanel];
    UIView *sizePanel = [self floatingPanel];
    UIView *historyPanel = [self floatingPanel];
    UIView *bottomDock = [self floatingPanel];
    UIScrollView *rightScrollView = [[UIScrollView alloc] init];
    UIStackView *rightStack = [[UIStackView alloc] init];

    topLeft.translatesAutoresizingMaskIntoConstraints = NO;
    topRight.translatesAutoresizingMaskIntoConstraints = NO;
    leftRail.translatesAutoresizingMaskIntoConstraints = NO;
    bottomDock.translatesAutoresizingMaskIntoConstraints = NO;
    rightScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    rightStack.translatesAutoresizingMaskIntoConstraints = NO;
    rightScrollView.showsVerticalScrollIndicator = NO;
    rightScrollView.alwaysBounceVertical = YES;
    rightScrollView.clipsToBounds = NO;
    rightStack.axis = UILayoutConstraintAxisVertical;
    rightStack.spacing = 16.0;

    [self.view addSubview:topLeft];
    [self.view addSubview:topRight];
    [self.view addSubview:leftRail];
    [self.view addSubview:rightScrollView];
    [rightScrollView addSubview:rightStack];
    [rightStack addArrangedSubview:colorsPanel];
    [rightStack addArrangedSubview:sizePanel];
    [rightStack addArrangedSubview:historyPanel];
    [self.view addSubview:bottomDock];

    [NSLayoutConstraint activateConstraints:@[
        [canvasContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [canvasContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [canvasContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [canvasContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.canvasView.leadingAnchor constraintEqualToAnchor:canvasContainer.leadingAnchor],
        [self.canvasView.trailingAnchor constraintEqualToAnchor:canvasContainer.trailingAnchor],
        [self.canvasView.topAnchor constraintEqualToAnchor:canvasContainer.topAnchor],
        [self.canvasView.bottomAnchor constraintEqualToAnchor:canvasContainer.bottomAnchor],

        [topLeft.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:34.0],
        [topLeft.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:30.0],

        [topRight.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-34.0],
        [topRight.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:30.0],

        [leftRail.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:38.0],
        [leftRail.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:170.0],
        [leftRail.widthAnchor constraintEqualToConstant:96.0],

        [rightScrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40.0],
        [rightScrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:150.0],
        [rightScrollView.bottomAnchor constraintEqualToAnchor:bottomDock.topAnchor constant:-16.0],
        [rightScrollView.widthAnchor constraintEqualToConstant:272.0],

        [rightStack.leadingAnchor constraintEqualToAnchor:rightScrollView.contentLayoutGuide.leadingAnchor constant:12.0],
        [rightStack.trailingAnchor constraintEqualToAnchor:rightScrollView.contentLayoutGuide.trailingAnchor constant:-12.0],
        [rightStack.topAnchor constraintEqualToAnchor:rightScrollView.contentLayoutGuide.topAnchor constant:12.0],
        [rightStack.bottomAnchor constraintEqualToAnchor:rightScrollView.contentLayoutGuide.bottomAnchor constant:-12.0],
        [rightStack.widthAnchor constraintEqualToAnchor:rightScrollView.frameLayoutGuide.widthAnchor constant:-24.0],

        [colorsPanel.widthAnchor constraintEqualToConstant:248.0],
        [sizePanel.widthAnchor constraintEqualToConstant:248.0],
        [historyPanel.widthAnchor constraintEqualToConstant:248.0],

        [bottomDock.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [bottomDock.widthAnchor constraintEqualToConstant:560.0],
        [bottomDock.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-22.0],
        [bottomDock.heightAnchor constraintEqualToConstant:98.0]
    ]];

    [self buildTopLeftPanel:topLeft];
    [self buildTopRightPanel:topRight];
    [self buildLeftRail:leftRail];
    [self buildColorsPanel:colorsPanel];
    [self buildSizePanel:sizePanel];
    [self buildHistoryPanel:historyPanel];
    [self buildBottomDock:bottomDock];
}

- (UIView *)floatingPanel {
    UIView *panel = [[UIView alloc] init];
    panel.backgroundColor = [UIColor clearColor];
    panel.layer.cornerRadius = 30.0;
    panel.layer.shadowColor = [UIColor colorWithRed:0.34 green:0.26 blue:0.14 alpha:1.0].CGColor;
    panel.layer.shadowOpacity = 0.14;
    panel.layer.shadowRadius = 26.0;
    panel.layer.shadowOffset = CGSizeMake(0, 14);

    UIVisualEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.layer.cornerRadius = 30.0;
    blurView.layer.masksToBounds = YES;
    blurView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.66].CGColor;
    blurView.layer.borderWidth = 1.0;
    blurView.contentView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.28];
    [panel addSubview:blurView];

    [NSLayoutConstraint activateConstraints:@[
        [blurView.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor],
        [blurView.topAnchor constraintEqualToAnchor:panel.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor]
    ]];

    return panel;
}

- (UIButton *)iconButtonWithSymbolName:(NSString *)symbolName accentColor:(UIColor *)accentColor {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = accentColor ?: [UIColor colorWithWhite:1.0 alpha:0.76];
    button.layer.cornerRadius = 18.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.72].CGColor;
    button.layer.shadowColor = [UIColor colorWithRed:0.47 green:0.40 blue:0.29 alpha:1.0].CGColor;
    button.layer.shadowOpacity = 0.12;
    button.layer.shadowRadius = 10.0;
    button.layer.shadowOffset = CGSizeMake(0, 6);
    button.tintColor = [UIColor colorWithRed:0.19 green:0.26 blue:0.33 alpha:1.0];
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightBold];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:configuration];
    [button setImage:image forState:UIControlStateNormal];
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:56.0],
        [button.heightAnchor constraintEqualToConstant:50.0]
    ]];
    [self registerPressFeedbackForControl:button];
    return button;
}

- (void)installCanvasGesturesOnView:(UIView *)view {
    UITapGestureRecognizer *twoFingerUndo = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerUndoTap:)];
    twoFingerUndo.numberOfTouchesRequired = 2;
    twoFingerUndo.numberOfTapsRequired = 1;

    UITapGestureRecognizer *twoFingerRedo = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerRedoTap:)];
    twoFingerRedo.numberOfTouchesRequired = 2;
    twoFingerRedo.numberOfTapsRequired = 2;

    [twoFingerUndo requireGestureRecognizerToFail:twoFingerRedo];
    [view addGestureRecognizer:twoFingerUndo];
    [view addGestureRecognizer:twoFingerRedo];
}

- (UIButton *)historyThumbButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 20.0;
    button.clipsToBounds = YES;
    button.layer.borderWidth = 2.0;
    button.layer.borderColor = [UIColor colorWithRed:0.17 green:0.22 blue:0.30 alpha:0.08].CGColor;
    button.backgroundColor = [UIColor colorWithRed:1.0 green:0.995 blue:0.98 alpha:1.0];
    button.imageView.contentMode = UIViewContentModeScaleAspectFill;
    button.layer.shadowColor = [UIColor colorWithRed:0.40 green:0.32 blue:0.22 alpha:1.0].CGColor;
    button.layer.shadowOpacity = 0.08;
    button.layer.shadowRadius = 10.0;
    button.layer.shadowOffset = CGSizeMake(0, 6);
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:24.0 weight:UIImageSymbolWeightSemibold];
    UIImage *placeholder = [[UIImage systemImageNamed:@"photo" withConfiguration:configuration] imageWithTintColor:[UIColor colorWithRed:0.62 green:0.67 blue:0.74 alpha:0.52] renderingMode:UIImageRenderingModeAlwaysOriginal];
    [button setImage:placeholder forState:UIControlStateNormal];
    button.imageView.contentMode = UIViewContentModeCenter;
    [self registerPressFeedbackForControl:button];
    return button;
}

- (UIButton *)railToolButtonWithSymbolName:(NSString *)symbolName slim:(BOOL)slim {
    KDToolButton *button = [KDToolButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = [UIColor colorWithRed:0.19 green:0.26 blue:0.33 alpha:1.0];
    button.backgroundColor = slim
        ? [UIColor colorWithRed:0.96 green:0.85 blue:0.48 alpha:1.0]
        : [UIColor colorWithWhite:1.0 alpha:0.82];
    button.layer.cornerRadius = slim ? 18.0 : 24.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.72].CGColor;
    button.layer.shadowColor = [UIColor colorWithRed:0.47 green:0.40 blue:0.29 alpha:1.0].CGColor;
    button.layer.shadowOpacity = 0.1;
    button.layer.shadowRadius = 10.0;
    button.layer.shadowOffset = CGSizeMake(0, 6);
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:(slim ? 18.0 : 22.0) weight:UIImageSymbolWeightBold];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:configuration];
    [button setImage:image forState:UIControlStateNormal];

    CGFloat height = slim ? 42.0 : 68.0;
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:68.0],
        [button.heightAnchor constraintEqualToConstant:height]
    ]];
    [self registerPressFeedbackForControl:button];
    return button;
}

- (void)buildTopLeftPanel:(UIView *)panel {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 10.0;
    [panel addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:12.0],
        [stack.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-12.0],
        [stack.topAnchor constraintEqualToAnchor:panel.topAnchor constant:12.0],
        [stack.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-12.0]
    ]];

    UIButton *brandButton = [self iconButtonWithSymbolName:@"paintpalette.fill" accentColor:[UIColor colorWithRed:0.96 green:0.85 blue:0.48 alpha:1.0]];
    UIButton *newButton = [self iconButtonWithSymbolName:@"plus" accentColor:nil];
    self.undoButton = [self iconButtonWithSymbolName:@"arrow.uturn.backward" accentColor:nil];
    self.redoButton = [self iconButtonWithSymbolName:@"arrow.uturn.forward" accentColor:nil];
    [self applyAccessibilityLabel:@"Palette" identifier:@"top.palette" toControl:brandButton];
    [self applyAccessibilityLabel:@"New Canvas" identifier:@"top.new-canvas" toControl:newButton];
    [self applyAccessibilityLabel:@"Undo" identifier:@"top.undo" toControl:self.undoButton];
    [self applyAccessibilityLabel:@"Redo" identifier:@"top.redo" toControl:self.redoButton];

    [newButton addTarget:self action:@selector(didTapNewCanvas) forControlEvents:UIControlEventTouchUpInside];
    [self.undoButton addTarget:self action:@selector(didTapUndo) forControlEvents:UIControlEventTouchUpInside];
    [self.redoButton addTarget:self action:@selector(didTapRedo) forControlEvents:UIControlEventTouchUpInside];

    [stack addArrangedSubview:brandButton];
    [stack addArrangedSubview:newButton];
    [stack addArrangedSubview:self.undoButton];
    [stack addArrangedSubview:self.redoButton];
}

- (void)buildTopRightPanel:(UIView *)panel {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 10.0;
    [panel addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:12.0],
        [stack.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-12.0],
        [stack.topAnchor constraintEqualToAnchor:panel.topAnchor constant:12.0],
        [stack.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-12.0]
    ]];

    UIButton *historyButton = [self iconButtonWithSymbolName:@"clock.arrow.circlepath" accentColor:nil];
    UIButton *lineArtButton = [self iconButtonWithSymbolName:@"square.on.circle" accentColor:nil];
    UIButton *importButton = [self iconButtonWithSymbolName:@"photo.on.rectangle" accentColor:nil];
    self.saveButton = [self iconButtonWithSymbolName:@"square.and.arrow.down.fill" accentColor:[UIColor colorWithRed:0.54 green:0.80 blue:0.98 alpha:1.0]];
    [self applyAccessibilityLabel:@"Open Latest" identifier:@"top.open-latest" toControl:historyButton];
    [self applyAccessibilityLabel:@"Line Art" identifier:@"top.line-art" toControl:lineArtButton];
    [self applyAccessibilityLabel:@"Import Photo" identifier:@"top.import-photo" toControl:importButton];
    [self applyAccessibilityLabel:@"Save" identifier:@"top.save" toControl:self.saveButton];

    [historyButton addTarget:self action:@selector(didTapOpenLatestSession) forControlEvents:UIControlEventTouchUpInside];
    [lineArtButton addTarget:self action:@selector(didTapLineArtPicker) forControlEvents:UIControlEventTouchUpInside];
    [importButton addTarget:self action:@selector(didTapImportImage) forControlEvents:UIControlEventTouchUpInside];
    [self.saveButton addTarget:self action:@selector(didTapSaveSession) forControlEvents:UIControlEventTouchUpInside];

    [stack addArrangedSubview:historyButton];
    [stack addArrangedSubview:lineArtButton];
    [stack addArrangedSubview:importButton];
    [stack addArrangedSubview:self.saveButton];
}

- (void)buildLeftRail:(UIView *)panel {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    [panel addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:14.0],
        [stack.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-14.0],
        [stack.topAnchor constraintEqualToAnchor:panel.topAnchor constant:14.0],
        [stack.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-14.0]
    ]];

    NSArray<NSDictionary *> *items = @[
        @{@"symbol": @"pencil.tip", @"mode": @(KDToolModeBrush), @"label": @"Brush"},
        @{@"symbol": @"eraser", @"mode": @(KDToolModeEraser), @"label": @"Eraser"},
        @{@"symbol": @"paintbrush.pointed", @"mode": @(KDToolModeFill), @"label": @"Fill"},
        @{@"symbol": @"star.circle", @"mode": @(KDToolModeSticker), @"label": @"Sticker"},
        @{@"symbol": @"eyedropper.halffull", @"mode": @(KDToolModePicker), @"label": @"Eyedropper"}
    ];

    for (NSDictionary *item in items) {
        BOOL slim = [item[@"mode"] integerValue] == KDToolModePicker;
        KDToolButton *button = (KDToolButton *)[self railToolButtonWithSymbolName:item[@"symbol"] slim:slim];
        button.toolMode = [item[@"mode"] integerValue];
        [self applyAccessibilityLabel:item[@"label"] identifier:[NSString stringWithFormat:@"tool.%@", [item[@"label"] lowercaseString]] toControl:button];
        [button addTarget:self action:@selector(didTapToolButton:) forControlEvents:UIControlEventTouchUpInside];

        [self.toolButtons addObject:button];
        [stack addArrangedSubview:button];
    }
}

- (void)buildColorsPanel:(UIView *)panel {
    UILabel *titleLabel = [self panelTitleLabel:@"Colors"];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:titleLabel];

    UIView *segmentContainer = [[UIView alloc] init];
    segmentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    segmentContainer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.76];
    segmentContainer.layer.cornerRadius = 18.0;
    [panel addSubview:segmentContainer];

    self.palette24Button = [self segmentButtonWithTitle:@"24" active:YES];
    self.palette36Button = [self segmentButtonWithTitle:@"36" active:NO];
    [self applyAccessibilityLabel:@"24 Colors" identifier:@"palette.24" toControl:self.palette24Button];
    [self applyAccessibilityLabel:@"36 Colors" identifier:@"palette.36" toControl:self.palette36Button];
    [self.palette24Button addTarget:self action:@selector(didTapPalette24) forControlEvents:UIControlEventTouchUpInside];
    [self.palette36Button addTarget:self action:@selector(didTapPalette36) forControlEvents:UIControlEventTouchUpInside];
    [segmentContainer addSubview:self.palette24Button];
    [segmentContainer addSubview:self.palette36Button];

    UIView *grid = [[UIView alloc] init];
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    grid.tag = 701;
    [panel addSubview:grid];

    UIButton *customButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.customColorButton = customButton;
    customButton.translatesAutoresizingMaskIntoConstraints = NO;
    [customButton setTitle:@"Custom" forState:UIControlStateNormal];
    customButton.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    [customButton setTitleColor:[UIColor colorWithRed:0.23 green:0.28 blue:0.35 alpha:1.0] forState:UIControlStateNormal];
    customButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.82];
    customButton.layer.cornerRadius = 18.0;
    customButton.layer.borderWidth = 1.0;
    customButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.72].CGColor;
    [self applyAccessibilityLabel:@"Custom Color" identifier:@"palette.custom-color" toControl:customButton];
    [customButton addTarget:self action:@selector(didTapCustomColor) forControlEvents:UIControlEventTouchUpInside];
    [self registerPressFeedbackForControl:customButton];
    [panel addSubview:customButton];

    UIScrollView *recentScrollView = [[UIScrollView alloc] init];
    recentScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    recentScrollView.showsHorizontalScrollIndicator = NO;
    recentScrollView.alwaysBounceHorizontal = YES;
    recentScrollView.clipsToBounds = NO;
    [panel addSubview:recentScrollView];

    UIStackView *recentRow = [[UIStackView alloc] init];
    recentRow.translatesAutoresizingMaskIntoConstraints = NO;
    recentRow.axis = UILayoutConstraintAxisHorizontal;
    recentRow.spacing = 8.0;
    recentRow.distribution = UIStackViewDistributionEqualSpacing;
    recentRow.tag = 702;
    [recentScrollView addSubview:recentRow];
    self.recentColorRowStack = recentRow;

    UIView *ringView = [[UIView alloc] init];
    ringView.translatesAutoresizingMaskIntoConstraints = NO;
    ringView.layer.cornerRadius = 22.0;
    ringView.backgroundColor = [UIColor colorWithPatternImage:[self colorWheelImage]];
    [panel addSubview:ringView];

    UIView *ringHole = [[UIView alloc] init];
    ringHole.translatesAutoresizingMaskIntoConstraints = NO;
    ringHole.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.94];
    ringHole.layer.cornerRadius = 14.0;
    [ringView addSubview:ringHole];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [titleLabel.topAnchor constraintEqualToAnchor:panel.topAnchor constant:18.0],

        [segmentContainer.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [segmentContainer.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12.0],
        [segmentContainer.widthAnchor constraintEqualToConstant:146.0],
        [segmentContainer.heightAnchor constraintEqualToConstant:42.0],

        [self.palette24Button.leadingAnchor constraintEqualToAnchor:segmentContainer.leadingAnchor constant:6.0],
        [self.palette24Button.centerYAnchor constraintEqualToAnchor:segmentContainer.centerYAnchor],
        [self.palette24Button.widthAnchor constraintEqualToConstant:68.0],
        [self.palette24Button.heightAnchor constraintEqualToConstant:32.0],

        [self.palette36Button.trailingAnchor constraintEqualToAnchor:segmentContainer.trailingAnchor constant:-6.0],
        [self.palette36Button.centerYAnchor constraintEqualToAnchor:segmentContainer.centerYAnchor],
        [self.palette36Button.widthAnchor constraintEqualToConstant:68.0],
        [self.palette36Button.heightAnchor constraintEqualToConstant:32.0],

        [grid.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [grid.topAnchor constraintEqualToAnchor:segmentContainer.bottomAnchor constant:14.0],
        [grid.widthAnchor constraintEqualToConstant:[self paletteGridWidth]],

        [customButton.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [customButton.topAnchor constraintEqualToAnchor:grid.bottomAnchor constant:12.0],
        [customButton.widthAnchor constraintEqualToConstant:92.0],
        [customButton.heightAnchor constraintEqualToConstant:36.0],

        [recentScrollView.leadingAnchor constraintEqualToAnchor:customButton.trailingAnchor constant:12.0],
        [recentScrollView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
        [recentScrollView.centerYAnchor constraintEqualToAnchor:customButton.centerYAnchor],
        [recentScrollView.heightAnchor constraintEqualToConstant:30.0],

        [recentRow.leadingAnchor constraintEqualToAnchor:recentScrollView.contentLayoutGuide.leadingAnchor],
        [recentRow.trailingAnchor constraintEqualToAnchor:recentScrollView.contentLayoutGuide.trailingAnchor],
        [recentRow.topAnchor constraintEqualToAnchor:recentScrollView.contentLayoutGuide.topAnchor],
        [recentRow.bottomAnchor constraintEqualToAnchor:recentScrollView.contentLayoutGuide.bottomAnchor],
        [recentRow.heightAnchor constraintEqualToAnchor:recentScrollView.frameLayoutGuide.heightAnchor],

        [ringView.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [ringView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
        [ringView.topAnchor constraintEqualToAnchor:customButton.bottomAnchor constant:12.0],
        [ringView.heightAnchor constraintEqualToConstant:64.0],
        [ringView.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18.0],

        [ringHole.centerXAnchor constraintEqualToAnchor:ringView.centerXAnchor],
        [ringHole.centerYAnchor constraintEqualToAnchor:ringView.centerYAnchor],
        [ringHole.widthAnchor constraintEqualToConstant:28.0],
        [ringHole.heightAnchor constraintEqualToConstant:28.0]
    ]];
    self.paletteGridHeightConstraint = [grid.heightAnchor constraintEqualToConstant:[self paletteGridHeightForColorCount:self.palette24.count]];
    self.paletteGridHeightConstraint.active = YES;
    [self reloadRecentColorRow];
}

- (void)buildSizePanel:(UIView *)panel {
    UILabel *titleLabel = [self panelTitleLabel:@"Brush / Sticker"];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:titleLabel];

    UIView *shell = [[UIView alloc] init];
    shell.translatesAutoresizingMaskIntoConstraints = NO;
    shell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.58];
    shell.layer.cornerRadius = 24.0;
    [panel addSubview:shell];

    self.sizeSlider = [[UISlider alloc] init];
    self.sizeSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.sizeSlider.minimumValue = 4.0;
    self.sizeSlider.maximumValue = 36.0;
    self.sizeSlider.value = 12.0;
    self.sizeSlider.minimumTrackTintColor = [UIColor colorWithRed:0.93 green:0.83 blue:0.46 alpha:1.0];
    self.sizeSlider.maximumTrackTintColor = [UIColor colorWithRed:0.91 green:0.66 blue:0.45 alpha:0.42];
    self.sizeSlider.accessibilityLabel = @"Brush Size";
    self.sizeSlider.accessibilityIdentifier = @"size.slider";
    [self.sizeSlider addTarget:self action:@selector(didChangeSizeSlider:) forControlEvents:UIControlEventValueChanged];
    [shell addSubview:self.sizeSlider];

    self.sizePreviewView = [[UIView alloc] init];
    self.sizePreviewView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sizePreviewView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    self.sizePreviewView.layer.cornerRadius = 24.0;
    self.sizePreviewView.layer.borderWidth = 1.0;
    self.sizePreviewView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.74].CGColor;
    [shell addSubview:self.sizePreviewView];

    self.sizePreviewShapeLayer = [CAShapeLayer layer];
    self.sizePreviewShapeLayer.lineCap = kCALineCapRound;
    self.sizePreviewShapeLayer.lineJoin = kCALineJoinRound;
    [self.sizePreviewView.layer addSublayer:self.sizePreviewShapeLayer];

    UIStackView *dots = [[UIStackView alloc] init];
    dots.translatesAutoresizingMaskIntoConstraints = NO;
    dots.axis = UILayoutConstraintAxisHorizontal;
    dots.distribution = UIStackViewDistributionEqualSpacing;
    dots.alignment = UIStackViewAlignmentBottom;
    [shell addSubview:dots];

    NSArray<NSNumber *> *sizes = @[@8.0, @14.0, @20.0, @28.0];
    for (NSNumber *size in sizes) {
        UIView *dot = [[UIView alloc] init];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.backgroundColor = [UIColor colorWithRed:0.91 green:0.64 blue:0.42 alpha:1.0];
        dot.layer.cornerRadius = size.floatValue / 2.0;
        [dot.widthAnchor constraintEqualToConstant:size.floatValue].active = YES;
        [dot.heightAnchor constraintEqualToConstant:size.floatValue].active = YES;
        [dots addArrangedSubview:dot];
    }

    UILabel *stickerTitle = [self panelTitleLabel:@"Stickers"];
    stickerTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:stickerTitle];

    UIStackView *stickerCategoryRow = [[UIStackView alloc] init];
    stickerCategoryRow.translatesAutoresizingMaskIntoConstraints = NO;
    stickerCategoryRow.axis = UILayoutConstraintAxisHorizontal;
    stickerCategoryRow.spacing = 8.0;
    stickerCategoryRow.distribution = UIStackViewDistributionFillEqually;
    [panel addSubview:stickerCategoryRow];

    for (NSString *category in self.stickerCategories) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:15.0 weight:UIImageSymbolWeightBold];
        UIImage *categoryImage = [UIImage systemImageNamed:[self stickerCategorySymbolForCategory:category] withConfiguration:configuration] ?: [self safeSystemImageNamed:@"star.fill"];
        [button setImage:categoryImage forState:UIControlStateNormal];
        button.accessibilityLabel = [NSString stringWithFormat:@"%@ Stickers", category];
        button.accessibilityIdentifier = [NSString stringWithFormat:@"sticker.category.%@", [category lowercaseString]];
        button.tintColor = [UIColor colorWithRed:0.47 green:0.52 blue:0.58 alpha:1.0];
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.62];
        button.layer.cornerRadius = 15.0;
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.70].CGColor;
        [button addTarget:self action:@selector(didTapStickerCategoryButton:) forControlEvents:UIControlEventTouchUpInside];
        [self registerPressFeedbackForControl:button];
        [stickerCategoryRow addArrangedSubview:button];
        [self.stickerCategoryButtons addObject:button];
    }

    UIScrollView *stickerScrollView = [[UIScrollView alloc] init];
    stickerScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    stickerScrollView.showsHorizontalScrollIndicator = NO;
    stickerScrollView.alwaysBounceHorizontal = YES;
    stickerScrollView.clipsToBounds = NO;
    [panel addSubview:stickerScrollView];

    UIStackView *stickerRow = [[UIStackView alloc] init];
    stickerRow.translatesAutoresizingMaskIntoConstraints = NO;
    stickerRow.axis = UILayoutConstraintAxisHorizontal;
    stickerRow.spacing = 10.0;
    stickerRow.distribution = UIStackViewDistributionFill;
    [stickerScrollView addSubview:stickerRow];
    self.stickerRowStack = stickerRow;

    UILabel *eraserTitle = [self panelTitleLabel:@"Eraser"];
    eraserTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:eraserTitle];

    UIStackView *eraserRow = [[UIStackView alloc] init];
    eraserRow.translatesAutoresizingMaskIntoConstraints = NO;
    eraserRow.axis = UILayoutConstraintAxisHorizontal;
    eraserRow.spacing = 10.0;
    eraserRow.distribution = UIStackViewDistributionFillEqually;
    [panel addSubview:eraserRow];

    self.circleEraserButton = [self smallToolButtonWithSymbolName:@"circle.fill" accent:NO];
    self.cloudEraserButton = [self smallToolButtonWithSymbolName:@"cloud.fill" accent:NO];
    self.starEraserButton = [self smallToolButtonWithSymbolName:@"star.fill" accent:NO];
    [self applyAccessibilityLabel:@"Circle Eraser" identifier:@"eraser.circle" toControl:self.circleEraserButton];
    [self applyAccessibilityLabel:@"Cloud Eraser" identifier:@"eraser.cloud" toControl:self.cloudEraserButton];
    [self applyAccessibilityLabel:@"Star Eraser" identifier:@"eraser.star" toControl:self.starEraserButton];
    [self.circleEraserButton addTarget:self action:@selector(didTapCircleEraser) forControlEvents:UIControlEventTouchUpInside];
    [self.cloudEraserButton addTarget:self action:@selector(didTapCloudEraser) forControlEvents:UIControlEventTouchUpInside];
    [self.starEraserButton addTarget:self action:@selector(didTapStarEraser) forControlEvents:UIControlEventTouchUpInside];
    [eraserRow addArrangedSubview:self.circleEraserButton];
    [eraserRow addArrangedSubview:self.cloudEraserButton];
    [eraserRow addArrangedSubview:self.starEraserButton];

    UILabel *editTitle = [self panelTitleLabel:@"Sticker Edit"];
    editTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:editTitle];

    UIStackView *editRow = [[UIStackView alloc] init];
    editRow.translatesAutoresizingMaskIntoConstraints = NO;
    editRow.axis = UILayoutConstraintAxisHorizontal;
    editRow.spacing = 10.0;
    editRow.distribution = UIStackViewDistributionFillEqually;
    [panel addSubview:editRow];

    self.frontStickerButton = [self smallToolButtonWithSymbolName:@"square.2.layers.3d.top.filled" accent:NO];
    self.deleteStickerButton = [self smallToolButtonWithSymbolName:@"trash.fill" accent:NO];
    [self applyAccessibilityLabel:@"Bring Sticker Forward" identifier:@"sticker.bring-forward" toControl:self.frontStickerButton];
    [self applyAccessibilityLabel:@"Delete Sticker" identifier:@"sticker.delete" toControl:self.deleteStickerButton];
    [self.frontStickerButton addTarget:self action:@selector(didTapBringStickerFront) forControlEvents:UIControlEventTouchUpInside];
    [self.deleteStickerButton addTarget:self action:@selector(didTapDeleteSticker) forControlEvents:UIControlEventTouchUpInside];
    [editRow addArrangedSubview:self.frontStickerButton];
    [editRow addArrangedSubview:self.deleteStickerButton];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [titleLabel.topAnchor constraintEqualToAnchor:panel.topAnchor constant:18.0],

        [shell.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [shell.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
        [shell.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12.0],

        [self.sizeSlider.leadingAnchor constraintEqualToAnchor:shell.leadingAnchor constant:14.0],
        [self.sizeSlider.trailingAnchor constraintEqualToAnchor:shell.trailingAnchor constant:-14.0],
        [self.sizeSlider.topAnchor constraintEqualToAnchor:shell.topAnchor constant:18.0],

        [self.sizePreviewView.leadingAnchor constraintEqualToAnchor:shell.leadingAnchor constant:16.0],
        [self.sizePreviewView.topAnchor constraintEqualToAnchor:self.sizeSlider.bottomAnchor constant:14.0],
        [self.sizePreviewView.widthAnchor constraintEqualToConstant:50.0],
        [self.sizePreviewView.heightAnchor constraintEqualToConstant:50.0],

        [dots.leadingAnchor constraintEqualToAnchor:self.sizePreviewView.trailingAnchor constant:18.0],
        [dots.trailingAnchor constraintEqualToAnchor:shell.trailingAnchor constant:-22.0],
        [dots.topAnchor constraintEqualToAnchor:self.sizeSlider.bottomAnchor constant:16.0],
        [dots.bottomAnchor constraintEqualToAnchor:shell.bottomAnchor constant:-14.0],

        [stickerTitle.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [stickerTitle.topAnchor constraintEqualToAnchor:shell.bottomAnchor constant:14.0],

        [stickerCategoryRow.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [stickerCategoryRow.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
        [stickerCategoryRow.topAnchor constraintEqualToAnchor:stickerTitle.bottomAnchor constant:9.0],
        [stickerCategoryRow.heightAnchor constraintEqualToConstant:32.0],

        [stickerScrollView.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [stickerScrollView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
        [stickerScrollView.topAnchor constraintEqualToAnchor:stickerCategoryRow.bottomAnchor constant:10.0],
        [stickerScrollView.heightAnchor constraintEqualToConstant:48.0],

        [stickerRow.leadingAnchor constraintEqualToAnchor:stickerScrollView.contentLayoutGuide.leadingAnchor],
        [stickerRow.trailingAnchor constraintEqualToAnchor:stickerScrollView.contentLayoutGuide.trailingAnchor],
        [stickerRow.topAnchor constraintEqualToAnchor:stickerScrollView.contentLayoutGuide.topAnchor],
        [stickerRow.bottomAnchor constraintEqualToAnchor:stickerScrollView.contentLayoutGuide.bottomAnchor],
        [stickerRow.heightAnchor constraintEqualToAnchor:stickerScrollView.frameLayoutGuide.heightAnchor],

        [eraserTitle.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [eraserTitle.topAnchor constraintEqualToAnchor:stickerScrollView.bottomAnchor constant:14.0],

        [eraserRow.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [eraserRow.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
        [eraserRow.topAnchor constraintEqualToAnchor:eraserTitle.bottomAnchor constant:10.0],

        [editTitle.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [editTitle.topAnchor constraintEqualToAnchor:eraserRow.bottomAnchor constant:14.0],

        [editRow.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [editRow.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
        [editRow.topAnchor constraintEqualToAnchor:editTitle.bottomAnchor constant:10.0],
        [editRow.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18.0]
    ]];
}

- (void)buildHistoryPanel:(UIView *)panel {
    UILabel *titleLabel = [self panelTitleLabel:@"History"];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:titleLabel];

    UILabel *draftLabel = [[UILabel alloc] init];
    draftLabel.translatesAutoresizingMaskIntoConstraints = NO;
    draftLabel.text = @"Draft";
    draftLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    draftLabel.textColor = [UIColor colorWithRed:0.47 green:0.52 blue:0.58 alpha:1.0];
    [panel addSubview:draftLabel];

    self.draftThumbButton = [self historyThumbButton];
    [self applyAccessibilityLabel:@"Draft Thumbnail" identifier:@"history.draft" toControl:self.draftThumbButton];
    [self.draftThumbButton addTarget:self action:@selector(didTapDraftThumb) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:self.draftThumbButton];

    UILabel *savedLabel = [[UILabel alloc] init];
    savedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    savedLabel.text = @"Saved";
    savedLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    savedLabel.textColor = [UIColor colorWithRed:0.47 green:0.52 blue:0.58 alpha:1.0];
    [panel addSubview:savedLabel];

    for (NSInteger index = 0; index < 4; index++) {
        UIButton *thumb = [self historyThumbButton];
        thumb.tag = index;
        [self applyAccessibilityLabel:[NSString stringWithFormat:@"Saved Thumbnail %ld", (long)index + 1] identifier:[NSString stringWithFormat:@"history.saved.%ld", (long)index + 1] toControl:thumb];
        [thumb addTarget:self action:@selector(didTapHistoryThumb:) forControlEvents:UIControlEventTouchUpInside];
        [panel addSubview:thumb];
        [self.historyThumbButtons addObject:thumb];
    }

    self.previousHistoryButton = [self smallToolButtonWithSymbolName:@"chevron.left" accent:NO];
    self.nextHistoryButton = [self smallToolButtonWithSymbolName:@"chevron.right" accent:NO];
    [self applyAccessibilityLabel:@"Previous History Page" identifier:@"history.previous-page" toControl:self.previousHistoryButton];
    [self applyAccessibilityLabel:@"Next History Page" identifier:@"history.next-page" toControl:self.nextHistoryButton];
    self.previousHistoryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.nextHistoryButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.previousHistoryButton addTarget:self action:@selector(didTapPreviousHistoryPage) forControlEvents:UIControlEventTouchUpInside];
    [self.nextHistoryButton addTarget:self action:@selector(didTapNextHistoryPage) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:self.previousHistoryButton];
    [panel addSubview:self.nextHistoryButton];

    UIButton *openButton = [self historyActionButtonWithTitle:@"Open" accent:NO];
    UIButton *importButton = [self historyActionButtonWithTitle:@"Import" accent:YES];
    self.deleteHistoryButton = [self historyActionButtonWithTitle:@"Delete" accent:NO];
    [self applyAccessibilityLabel:@"Open Latest" identifier:@"history.open-latest" toControl:openButton];
    [self applyAccessibilityLabel:@"Import Photo" identifier:@"history.import-photo" toControl:importButton];
    [self applyAccessibilityLabel:@"Delete Latest" identifier:@"history.delete-latest" toControl:self.deleteHistoryButton];
    openButton.translatesAutoresizingMaskIntoConstraints = NO;
    importButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteHistoryButton.translatesAutoresizingMaskIntoConstraints = NO;

    [openButton addTarget:self action:@selector(didTapOpenLatestSession) forControlEvents:UIControlEventTouchUpInside];
    [importButton addTarget:self action:@selector(didTapImportImage) forControlEvents:UIControlEventTouchUpInside];
    [self.deleteHistoryButton addTarget:self action:@selector(didTapDeleteLatestSession) forControlEvents:UIControlEventTouchUpInside];

    [panel addSubview:openButton];
    [panel addSubview:importButton];
    [panel addSubview:self.deleteHistoryButton];

    UIButton *thumbOne = self.historyThumbButtons[0];
    UIButton *thumbTwo = self.historyThumbButtons[1];
    UIButton *thumbThree = self.historyThumbButtons[2];
    UIButton *thumbFour = self.historyThumbButtons[3];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [titleLabel.topAnchor constraintEqualToAnchor:panel.topAnchor constant:18.0],

        [draftLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [draftLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12.0],

        [self.draftThumbButton.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [self.draftThumbButton.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
        [self.draftThumbButton.topAnchor constraintEqualToAnchor:draftLabel.bottomAnchor constant:8.0],
        [self.draftThumbButton.heightAnchor constraintEqualToConstant:86.0],

        [savedLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [savedLabel.topAnchor constraintEqualToAnchor:self.draftThumbButton.bottomAnchor constant:12.0],

        [thumbOne.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [thumbOne.topAnchor constraintEqualToAnchor:savedLabel.bottomAnchor constant:8.0],
        [thumbOne.widthAnchor constraintEqualToConstant:92.0],
        [thumbOne.heightAnchor constraintEqualToConstant:92.0],

        [thumbTwo.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
        [thumbTwo.topAnchor constraintEqualToAnchor:savedLabel.bottomAnchor constant:8.0],
        [thumbTwo.widthAnchor constraintEqualToConstant:92.0],
        [thumbTwo.heightAnchor constraintEqualToConstant:92.0],

        [thumbThree.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [thumbThree.topAnchor constraintEqualToAnchor:thumbOne.bottomAnchor constant:10.0],
        [thumbThree.widthAnchor constraintEqualToConstant:92.0],
        [thumbThree.heightAnchor constraintEqualToConstant:92.0],

        [thumbFour.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
        [thumbFour.topAnchor constraintEqualToAnchor:thumbTwo.bottomAnchor constant:10.0],
        [thumbFour.widthAnchor constraintEqualToConstant:92.0],
        [thumbFour.heightAnchor constraintEqualToConstant:92.0],

        [self.previousHistoryButton.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [self.previousHistoryButton.topAnchor constraintEqualToAnchor:thumbThree.bottomAnchor constant:12.0],
        [self.previousHistoryButton.widthAnchor constraintEqualToConstant:46.0],

        [self.nextHistoryButton.leadingAnchor constraintEqualToAnchor:self.previousHistoryButton.trailingAnchor constant:8.0],
        [self.nextHistoryButton.topAnchor constraintEqualToAnchor:thumbThree.bottomAnchor constant:12.0],
        [self.nextHistoryButton.widthAnchor constraintEqualToConstant:46.0],

        [openButton.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18.0],
        [openButton.topAnchor constraintEqualToAnchor:self.previousHistoryButton.bottomAnchor constant:10.0],
        [openButton.widthAnchor constraintEqualToConstant:68.0],
        [openButton.heightAnchor constraintEqualToConstant:38.0],

        [importButton.leadingAnchor constraintEqualToAnchor:openButton.trailingAnchor constant:8.0],
        [importButton.topAnchor constraintEqualToAnchor:self.previousHistoryButton.bottomAnchor constant:10.0],
        [importButton.widthAnchor constraintEqualToConstant:78.0],
        [importButton.heightAnchor constraintEqualToConstant:38.0],

        [self.deleteHistoryButton.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
        [self.deleteHistoryButton.topAnchor constraintEqualToAnchor:self.nextHistoryButton.bottomAnchor constant:10.0],
        [self.deleteHistoryButton.widthAnchor constraintEqualToConstant:78.0],
        [self.deleteHistoryButton.heightAnchor constraintEqualToConstant:38.0],
        [self.deleteHistoryButton.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18.0]
    ]];
}

- (void)buildBottomDock:(UIView *)panel {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"Brushes";
    label.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    label.textColor = [UIColor colorWithRed:0.34 green:0.39 blue:0.45 alpha:1.0];
    [panel addSubview:label];

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.alwaysBounceHorizontal = YES;
    scrollView.clipsToBounds = NO;
    [panel addSubview:scrollView];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 12.0;
    [scrollView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:22.0],
        [label.centerYAnchor constraintEqualToAnchor:panel.centerYAnchor],
        [label.widthAnchor constraintEqualToConstant:88.0],

        [scrollView.leadingAnchor constraintEqualToAnchor:label.trailingAnchor constant:8.0],
        [scrollView.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18.0],
        [scrollView.topAnchor constraintEqualToAnchor:panel.topAnchor constant:12.0],
        [scrollView.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-12.0],

        [stack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [stack.heightAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.heightAnchor]
    ]];

    NSArray<NSDictionary *> *brushItems = @[
        @{@"title": @"Pencil", @"style": @(KDBrushStylePencil), @"mode": @(KDToolModeBrush), @"brush": @YES, @"symbol": @"pencil.tip", @"accent": [self brushColorForTitle:@"Pencil"]},
        @{@"title": @"Pen", @"style": @(KDBrushStylePen), @"mode": @(KDToolModeBrush), @"brush": @YES, @"symbol": @"pencil", @"accent": [self brushColorForTitle:@"Pen"]},
        @{@"title": @"Crayon", @"style": @(KDBrushStyleCrayon), @"mode": @(KDToolModeBrush), @"brush": @YES, @"symbol": @"paintbrush.pointed.fill", @"accent": [self brushColorForTitle:@"Crayon"]}
    ];

    for (NSInteger index = 0; index < brushItems.count; index++) {
        NSDictionary *item = brushItems[index];
        KDBrushButton *button = [self toolCardButtonWithSymbolName:item[@"symbol"] accentColor:item[@"accent"] title:item[@"title"]];
        button.brushStyle = [item[@"style"] integerValue];
        button.toolMode = [item[@"mode"] integerValue];
        button.representsBrushStyle = [item[@"brush"] boolValue];
        button.tag = index;
        [self applyAccessibilityLabel:item[@"title"] identifier:[NSString stringWithFormat:@"dock.%@", [item[@"title"] lowercaseString]] toControl:button];
        [button addTarget:self action:@selector(didTapBrushButton:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:button];
        [self.brushButtons addObject:button];
    }
}

- (void)addCanvasBadges {
    UILabel *leftBadge = [self badgeLabelWithText:@"Canvas"];
    UILabel *rightBadge = [self badgeLabelWithText:@"Line Art"];
    leftBadge.translatesAutoresizingMaskIntoConstraints = NO;
    rightBadge.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:leftBadge];
    [self.view addSubview:rightBadge];

    [NSLayoutConstraint activateConstraints:@[
        [leftBadge.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:214.0],
        [leftBadge.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:94.0],
        [leftBadge.heightAnchor constraintEqualToConstant:40.0],

        [rightBadge.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-322.0],
        [rightBadge.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:94.0],
        [rightBadge.heightAnchor constraintEqualToConstant:40.0]
    ]];
}

- (UILabel *)badgeLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    label.textColor = [UIColor colorWithRed:0.49 green:0.53 blue:0.59 alpha:1.0];
    label.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.92];
    label.layer.cornerRadius = 18.0;
    label.clipsToBounds = YES;
    label.layer.borderWidth = 1.0;
    label.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.7].CGColor;
    return label;
}

- (UILabel *)panelTitleLabel:(NSString *)title {
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    label.textColor = [UIColor colorWithRed:0.12 green:0.16 blue:0.23 alpha:1.0];
    return label;
}

- (void)strokePath:(UIBezierPath *)path width:(CGFloat)width {
    path.lineWidth = width * self.lineArtStrokeScale;
    path.lineCapStyle = kCGLineCapRound;
    path.lineJoinStyle = kCGLineJoinRound;
    [path stroke];
}

- (UIButton *)segmentButtonWithTitle:(NSString *)title active:(BOOL)active {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    [button setTitleColor:active ? [UIColor colorWithRed:0.39 green:0.26 blue:0.0 alpha:1.0] : [UIColor colorWithRed:0.49 green:0.53 blue:0.59 alpha:1.0] forState:UIControlStateNormal];
    button.backgroundColor = active ? [UIColor colorWithRed:0.97 green:0.86 blue:0.48 alpha:1.0] : [UIColor clearColor];
    button.layer.cornerRadius = 16.0;
    button.layer.borderWidth = active ? 1.0 : 0.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.76].CGColor;
    [self registerPressFeedbackForControl:button];
    return button;
}

- (UIButton *)historyActionButtonWithTitle:(NSString *)title accent:(BOOL)accent {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    [button setTitleColor:accent ? [UIColor colorWithRed:0.39 green:0.26 blue:0.0 alpha:1.0] : [UIColor colorWithRed:0.23 green:0.28 blue:0.35 alpha:1.0] forState:UIControlStateNormal];
    button.backgroundColor = accent ? [UIColor colorWithRed:0.97 green:0.86 blue:0.48 alpha:1.0] : [UIColor colorWithWhite:1.0 alpha:0.82];
    button.layer.cornerRadius = 18.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.72].CGColor;
    [self registerPressFeedbackForControl:button];
    return button;
}

- (UIButton *)smallToolButtonWithSymbolName:(NSString *)symbolName accent:(BOOL)accent {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = accent
        ? [UIColor colorWithRed:0.39 green:0.26 blue:0.0 alpha:1.0]
        : [UIColor colorWithRed:0.23 green:0.28 blue:0.35 alpha:1.0];
    button.backgroundColor = accent
        ? [UIColor colorWithRed:0.97 green:0.86 blue:0.48 alpha:1.0]
        : [UIColor colorWithWhite:1.0 alpha:0.82];
    button.layer.cornerRadius = 16.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.72].CGColor;
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightBold];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:configuration];
    [button setImage:image forState:UIControlStateNormal];
    [button.heightAnchor constraintEqualToConstant:36.0].active = YES;
    [self registerPressFeedbackForControl:button];
    return button;
}

- (void)applyAccessibilityLabel:(NSString *)label identifier:(NSString *)identifier toControl:(UIControl *)control {
    control.accessibilityLabel = label;
    control.accessibilityIdentifier = identifier;
}

- (UIImage *)safeSystemImageNamed:(NSString *)symbolName {
    UIImage *image = [UIImage systemImageNamed:symbolName];
    return image ?: [UIImage systemImageNamed:@"star.fill"];
}

- (NSString *)stickerAccessibilityLabelForSymbol:(NSString *)symbol {
    NSDictionary<NSString *, NSString *> *labels = @{
        @"star.fill": @"Star Sticker",
        @"heart.fill": @"Heart Sticker",
        @"sun.max.fill": @"Sun Sticker",
        @"leaf.fill": @"Leaf Sticker",
        @"cloud.fill": @"Cloud Sticker",
        @"moon.stars.fill": @"Moon Sticker",
        @"rainbow": @"Rainbow Sticker",
        @"camera.macro": @"Flower Sticker",
        @"butterfly.fill": @"Butterfly Sticker",
        @"pawprint.fill": @"Paw Sticker",
        @"gift.fill": @"Gift Sticker",
        @"face.smiling.fill": @"Smile Sticker"
    };
    return labels[symbol] ?: @"Sticker";
}

- (NSString *)stickerCategorySymbolForCategory:(NSString *)category {
    NSDictionary<NSString *, NSString *> *symbols = @{
        @"Animals": @"pawprint.fill",
        @"Nature": @"leaf.fill",
        @"Decor": @"sparkles",
        @"Faces": @"face.smiling.fill"
    };
    return symbols[category] ?: @"star.fill";
}

- (KDBrushButton *)toolCardButtonWithSymbolName:(NSString *)symbolName accentColor:(UIColor *)accentColor title:(NSString *)title {
    KDBrushButton *button = [KDBrushButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.84];
    button.layer.cornerRadius = 28.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.72].CGColor;
    button.layer.shadowColor = [UIColor colorWithRed:0.47 green:0.40 blue:0.29 alpha:1.0].CGColor;
    button.layer.shadowOpacity = 0.12;
    button.layer.shadowRadius = 10.0;
    button.layer.shadowOffset = CGSizeMake(0, 6);
    [button.widthAnchor constraintEqualToConstant:126.0].active = YES;
    [button.heightAnchor constraintEqualToConstant:68.0].active = YES;

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightBold];
    iconView.image = [[UIImage systemImageNamed:symbolName withConfiguration:configuration] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    iconView.tintColor = accentColor;
    iconView.contentMode = UIViewContentModeScaleAspectFit;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    label.textColor = [UIColor colorWithRed:0.16 green:0.22 blue:0.28 alpha:1.0];

    UIView *halo = [[UIView alloc] init];
    halo.translatesAutoresizingMaskIntoConstraints = NO;
    halo.backgroundColor = [accentColor colorWithAlphaComponent:0.16];
    halo.layer.cornerRadius = 18.0;

    [button addSubview:halo];
    [button addSubview:iconView];
    [button addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [halo.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:14.0],
        [halo.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [halo.widthAnchor constraintEqualToConstant:36.0],
        [halo.heightAnchor constraintEqualToConstant:36.0],
        [iconView.centerXAnchor constraintEqualToAnchor:halo.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:halo.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:22.0],
        [iconView.heightAnchor constraintEqualToConstant:22.0],
        [label.leadingAnchor constraintEqualToAnchor:halo.trailingAnchor constant:14.0],
        [label.centerYAnchor constraintEqualToAnchor:button.centerYAnchor]
    ]];

    [self registerPressFeedbackForControl:button];
    return button;
}

- (UIColor *)brushColorForTitle:(NSString *)title {
    if ([title isEqualToString:@"Pencil"]) {
        return [UIColor colorWithRed:0.94 green:0.43 blue:0.45 alpha:1.0];
    }
    if ([title isEqualToString:@"Pen"]) {
        return [UIColor colorWithRed:0.45 green:0.73 blue:0.97 alpha:1.0];
    }
    if ([title isEqualToString:@"Crayon"]) {
        return [UIColor colorWithRed:0.93 green:0.62 blue:0.41 alpha:1.0];
    }
    if ([title isEqualToString:@"Eraser"]) {
        return [UIColor colorWithWhite:0.88 alpha:1.0];
    }
    if ([title isEqualToString:@"Fill"]) {
        return [UIColor colorWithRed:0.95 green:0.80 blue:0.41 alpha:1.0];
    }
    if ([title isEqualToString:@"Picker"]) {
        return [UIColor colorWithRed:0.55 green:0.54 blue:0.95 alpha:1.0];
    }
    return [UIColor colorWithRed:0.56 green:0.84 blue:0.63 alpha:1.0];
}

- (NSArray<KDLineArtItem *> *)makeLineArtItems {
    __weak typeof(self) weakSelf = self;
    KDLineArtItem *bunny = [KDLineArtItem itemWithTitle:@"Bunny" drawingBlock:^(CGRect rect) {
        CGFloat centerX = CGRectGetMidX(rect);
        CGFloat centerY = CGRectGetMidY(rect) + 18.0;

        UIBezierPath *leftEar = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(centerX - 132.0, centerY - 220.0, 54.0, 150.0) cornerRadius:28.0];
        UIBezierPath *rightEar = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(centerX + 78.0, centerY - 220.0, 54.0, 150.0) cornerRadius:28.0];
        [weakSelf strokePath:leftEar width:12.0];
        [weakSelf strokePath:rightEar width:12.0];

        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(centerX - 138.0, centerY - 108.0, 276.0, 216.0)] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(centerX - 80.0, centerY - 18.0, 160.0, 120.0)] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(centerX - 88.0, centerY + 82.0, 72.0, 52.0)] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(centerX + 16.0, centerY + 82.0, 72.0, 52.0)] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(centerX - 86.0, centerY - 20.0, 36.0, 48.0)] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(centerX + 50.0, centerY - 20.0, 36.0, 48.0)] width:12.0];

        UIBezierPath *nose = [UIBezierPath bezierPath];
        [nose moveToPoint:CGPointMake(centerX, centerY + 20.0)];
        [nose addLineToPoint:CGPointMake(centerX - 24.0, centerY + 46.0)];
        [nose addLineToPoint:CGPointMake(centerX + 24.0, centerY + 46.0)];
        [nose closePath];
        [weakSelf strokePath:nose width:12.0];

        UIBezierPath *mouth = [UIBezierPath bezierPath];
        [mouth moveToPoint:CGPointMake(centerX, centerY + 46.0)];
        [mouth addCurveToPoint:CGPointMake(centerX - 34.0, centerY + 72.0) controlPoint1:CGPointMake(centerX - 2.0, centerY + 63.0) controlPoint2:CGPointMake(centerX - 18.0, centerY + 76.0)];
        [mouth moveToPoint:CGPointMake(centerX, centerY + 46.0)];
        [mouth addCurveToPoint:CGPointMake(centerX + 34.0, centerY + 72.0) controlPoint1:CGPointMake(centerX + 2.0, centerY + 63.0) controlPoint2:CGPointMake(centerX + 18.0, centerY + 76.0)];
        [weakSelf strokePath:mouth width:12.0];
    }];

    KDLineArtItem *car = [KDLineArtItem itemWithTitle:@"Car" drawingBlock:^(CGRect rect) {
        CGFloat baseY = CGRectGetMaxY(rect) - 90.0;
        CGFloat leftX = CGRectGetMinX(rect) + 80.0;

        UIBezierPath *body = [UIBezierPath bezierPath];
        [body moveToPoint:CGPointMake(leftX, baseY)];
        [body addLineToPoint:CGPointMake(leftX + 92.0, baseY - 94.0)];
        [body addLineToPoint:CGPointMake(leftX + 250.0, baseY - 94.0)];
        [body addLineToPoint:CGPointMake(leftX + 334.0, baseY)];
        [body addLineToPoint:CGPointMake(leftX + 402.0, baseY)];
        [body addCurveToPoint:CGPointMake(leftX + 456.0, baseY + 38.0) controlPoint1:CGPointMake(leftX + 430.0, baseY) controlPoint2:CGPointMake(leftX + 456.0, baseY + 10.0)];
        [body addLineToPoint:CGPointMake(leftX + 456.0, baseY + 86.0)];
        [body addLineToPoint:CGPointMake(leftX - 10.0, baseY + 86.0)];
        [body addLineToPoint:CGPointMake(leftX - 10.0, baseY + 24.0)];
        [body addCurveToPoint:CGPointMake(leftX, baseY) controlPoint1:CGPointMake(leftX - 10.0, baseY + 10.0) controlPoint2:CGPointMake(leftX - 4.0, baseY)];
        [body closePath];
        [weakSelf strokePath:body width:12.0];

        [weakSelf strokePath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(leftX + 110.0, baseY - 78.0, 112.0, 76.0) cornerRadius:18.0] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(leftX + 232.0, baseY - 78.0, 90.0, 76.0) cornerRadius:18.0] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(leftX + 52.0, baseY + 32.0, 96.0, 96.0)] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(leftX + 296.0, baseY + 32.0, 96.0, 96.0)] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(leftX + 76.0, baseY + 56.0, 48.0, 48.0)] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(leftX + 320.0, baseY + 56.0, 48.0, 48.0)] width:12.0];
    }];

    KDLineArtItem *fish = [KDLineArtItem itemWithTitle:@"Fish" drawingBlock:^(CGRect rect) {
        CGFloat centerX = CGRectGetMidX(rect);
        CGFloat centerY = CGRectGetMidY(rect);

        UIBezierPath *body = [UIBezierPath bezierPath];
        [body moveToPoint:CGPointMake(centerX - 160.0, centerY)];
        [body addCurveToPoint:CGPointMake(centerX + 74.0, centerY - 118.0) controlPoint1:CGPointMake(centerX - 126.0, centerY - 122.0) controlPoint2:CGPointMake(centerX + 8.0, centerY - 150.0)];
        [body addCurveToPoint:CGPointMake(centerX + 74.0, centerY + 118.0) controlPoint1:CGPointMake(centerX + 148.0, centerY - 80.0) controlPoint2:CGPointMake(centerX + 148.0, centerY + 80.0)];
        [body addCurveToPoint:CGPointMake(centerX - 160.0, centerY) controlPoint1:CGPointMake(centerX + 8.0, centerY + 150.0) controlPoint2:CGPointMake(centerX - 126.0, centerY + 122.0)];
        [body closePath];
        [weakSelf strokePath:body width:12.0];

        UIBezierPath *tail = [UIBezierPath bezierPath];
        [tail moveToPoint:CGPointMake(centerX + 74.0, centerY)];
        [tail addLineToPoint:CGPointMake(centerX + 208.0, centerY - 122.0)];
        [tail addLineToPoint:CGPointMake(centerX + 208.0, centerY + 122.0)];
        [tail closePath];
        [weakSelf strokePath:tail width:12.0];

        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(centerX - 96.0, centerY - 24.0, 46.0, 46.0)] width:12.0];

        UIBezierPath *fin = [UIBezierPath bezierPath];
        [fin moveToPoint:CGPointMake(centerX - 18.0, centerY - 26.0)];
        [fin addCurveToPoint:CGPointMake(centerX + 48.0, centerY - 118.0) controlPoint1:CGPointMake(centerX - 12.0, centerY - 90.0) controlPoint2:CGPointMake(centerX + 26.0, centerY - 112.0)];
        [fin addCurveToPoint:CGPointMake(centerX + 92.0, centerY - 30.0) controlPoint1:CGPointMake(centerX + 74.0, centerY - 116.0) controlPoint2:CGPointMake(centerX + 98.0, centerY - 72.0)];
        [fin closePath];
        [weakSelf strokePath:fin width:12.0];

        UIBezierPath *smile = [UIBezierPath bezierPath];
        [smile moveToPoint:CGPointMake(centerX - 130.0, centerY + 18.0)];
        [smile addCurveToPoint:CGPointMake(centerX - 74.0, centerY + 42.0) controlPoint1:CGPointMake(centerX - 116.0, centerY + 42.0) controlPoint2:CGPointMake(centerX - 90.0, centerY + 54.0)];
        [weakSelf strokePath:smile width:12.0];
    }];

    KDLineArtItem *flower = [KDLineArtItem itemWithTitle:@"Flower" drawingBlock:^(CGRect rect) {
        CGFloat centerX = CGRectGetMidX(rect);
        CGFloat centerY = CGRectGetMidY(rect) - 24.0;
        NSArray<NSValue *> *petalCenters = @[
            [NSValue valueWithCGPoint:CGPointMake(centerX, centerY - 114.0)],
            [NSValue valueWithCGPoint:CGPointMake(centerX + 94.0, centerY - 34.0)],
            [NSValue valueWithCGPoint:CGPointMake(centerX + 58.0, centerY + 86.0)],
            [NSValue valueWithCGPoint:CGPointMake(centerX - 58.0, centerY + 86.0)],
            [NSValue valueWithCGPoint:CGPointMake(centerX - 94.0, centerY - 34.0)]
        ];
        for (NSValue *value in petalCenters) {
            CGPoint point = value.CGPointValue;
            [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(point.x - 54.0, point.y - 62.0, 108.0, 124.0)] width:12.0];
        }

        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(centerX - 52.0, centerY - 52.0, 104.0, 104.0)] width:12.0];

        UIBezierPath *stem = [UIBezierPath bezierPath];
        [stem moveToPoint:CGPointMake(centerX, centerY + 54.0)];
        [stem addCurveToPoint:CGPointMake(centerX - 12.0, CGRectGetMaxY(rect) - 18.0) controlPoint1:CGPointMake(centerX + 8.0, centerY + 136.0) controlPoint2:CGPointMake(centerX - 18.0, centerY + 222.0)];
        [weakSelf strokePath:stem width:12.0];

        UIBezierPath *leftLeaf = [UIBezierPath bezierPath];
        [leftLeaf moveToPoint:CGPointMake(centerX - 8.0, centerY + 166.0)];
        [leftLeaf addCurveToPoint:CGPointMake(centerX - 136.0, centerY + 136.0) controlPoint1:CGPointMake(centerX - 38.0, centerY + 118.0) controlPoint2:CGPointMake(centerX - 110.0, centerY + 112.0)];
        [leftLeaf addCurveToPoint:CGPointMake(centerX - 8.0, centerY + 166.0) controlPoint1:CGPointMake(centerX - 114.0, centerY + 186.0) controlPoint2:CGPointMake(centerX - 44.0, centerY + 194.0)];
        [leftLeaf closePath];
        [weakSelf strokePath:leftLeaf width:12.0];

        UIBezierPath *rightLeaf = [UIBezierPath bezierPath];
        [rightLeaf moveToPoint:CGPointMake(centerX - 4.0, centerY + 232.0)];
        [rightLeaf addCurveToPoint:CGPointMake(centerX + 124.0, centerY + 198.0) controlPoint1:CGPointMake(centerX + 26.0, centerY + 188.0) controlPoint2:CGPointMake(centerX + 96.0, centerY + 174.0)];
        [rightLeaf addCurveToPoint:CGPointMake(centerX - 4.0, centerY + 232.0) controlPoint1:CGPointMake(centerX + 104.0, centerY + 244.0) controlPoint2:CGPointMake(centerX + 38.0, centerY + 258.0)];
        [rightLeaf closePath];
        [weakSelf strokePath:rightLeaf width:12.0];
    }];

    KDLineArtItem *house = [KDLineArtItem itemWithTitle:@"House" drawingBlock:^(CGRect rect) {
        CGFloat centerX = CGRectGetMidX(rect);
        CGFloat baseY = CGRectGetMaxY(rect) - 56.0;
        CGFloat houseWidth = MIN(CGRectGetWidth(rect) - 120.0, 360.0);
        CGFloat leftX = centerX - houseWidth / 2.0;
        CGFloat wallTop = baseY - 190.0;

        UIBezierPath *roof = [UIBezierPath bezierPath];
        [roof moveToPoint:CGPointMake(leftX - 24.0, wallTop + 18.0)];
        [roof addLineToPoint:CGPointMake(centerX, wallTop - 130.0)];
        [roof addLineToPoint:CGPointMake(leftX + houseWidth + 24.0, wallTop + 18.0)];
        [roof closePath];
        [weakSelf strokePath:roof width:12.0];

        [weakSelf strokePath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(leftX, wallTop, houseWidth, 190.0) cornerRadius:22.0] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(centerX - 42.0, baseY - 104.0, 84.0, 104.0) cornerRadius:18.0] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(leftX + 38.0, wallTop + 46.0, 84.0, 72.0) cornerRadius:18.0] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(leftX + houseWidth - 122.0, wallTop + 46.0, 84.0, 72.0) cornerRadius:18.0] width:12.0];
    }];

    KDLineArtItem *rocket = [KDLineArtItem itemWithTitle:@"Rocket" drawingBlock:^(CGRect rect) {
        CGFloat centerX = CGRectGetMidX(rect);
        CGFloat topY = CGRectGetMinY(rect) + 32.0;
        CGFloat bottomY = CGRectGetMaxY(rect) - 54.0;

        UIBezierPath *body = [UIBezierPath bezierPath];
        [body moveToPoint:CGPointMake(centerX, topY)];
        [body addCurveToPoint:CGPointMake(centerX + 74.0, topY + 150.0) controlPoint1:CGPointMake(centerX + 58.0, topY + 38.0) controlPoint2:CGPointMake(centerX + 86.0, topY + 96.0)];
        [body addLineToPoint:CGPointMake(centerX + 54.0, bottomY - 78.0)];
        [body addCurveToPoint:CGPointMake(centerX - 54.0, bottomY - 78.0) controlPoint1:CGPointMake(centerX + 24.0, bottomY - 42.0) controlPoint2:CGPointMake(centerX - 24.0, bottomY - 42.0)];
        [body addLineToPoint:CGPointMake(centerX - 74.0, topY + 150.0)];
        [body addCurveToPoint:CGPointMake(centerX, topY) controlPoint1:CGPointMake(centerX - 86.0, topY + 96.0) controlPoint2:CGPointMake(centerX - 58.0, topY + 38.0)];
        [body closePath];
        [weakSelf strokePath:body width:12.0];

        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(centerX - 34.0, topY + 116.0, 68.0, 68.0)] width:12.0];

        UIBezierPath *leftFin = [UIBezierPath bezierPath];
        [leftFin moveToPoint:CGPointMake(centerX - 58.0, bottomY - 112.0)];
        [leftFin addLineToPoint:CGPointMake(centerX - 142.0, bottomY - 38.0)];
        [leftFin addLineToPoint:CGPointMake(centerX - 44.0, bottomY - 44.0)];
        [leftFin closePath];
        [weakSelf strokePath:leftFin width:12.0];

        UIBezierPath *rightFin = [UIBezierPath bezierPath];
        [rightFin moveToPoint:CGPointMake(centerX + 58.0, bottomY - 112.0)];
        [rightFin addLineToPoint:CGPointMake(centerX + 142.0, bottomY - 38.0)];
        [rightFin addLineToPoint:CGPointMake(centerX + 44.0, bottomY - 44.0)];
        [rightFin closePath];
        [weakSelf strokePath:rightFin width:12.0];

        UIBezierPath *flame = [UIBezierPath bezierPath];
        [flame moveToPoint:CGPointMake(centerX - 30.0, bottomY - 40.0)];
        [flame addCurveToPoint:CGPointMake(centerX, bottomY + 34.0) controlPoint1:CGPointMake(centerX - 14.0, bottomY - 4.0) controlPoint2:CGPointMake(centerX - 6.0, bottomY + 12.0)];
        [flame addCurveToPoint:CGPointMake(centerX + 30.0, bottomY - 40.0) controlPoint1:CGPointMake(centerX + 8.0, bottomY + 10.0) controlPoint2:CGPointMake(centerX + 16.0, bottomY - 6.0)];
        [flame closePath];
        [weakSelf strokePath:flame width:12.0];
    }];

    KDLineArtItem *cupcake = [KDLineArtItem itemWithTitle:@"Cupcake" drawingBlock:^(CGRect rect) {
        CGFloat centerX = CGRectGetMidX(rect);
        CGFloat centerY = CGRectGetMidY(rect) + 20.0;

        UIBezierPath *frosting = [UIBezierPath bezierPath];
        [frosting moveToPoint:CGPointMake(centerX - 142.0, centerY - 18.0)];
        [frosting addCurveToPoint:CGPointMake(centerX - 78.0, centerY - 112.0) controlPoint1:CGPointMake(centerX - 150.0, centerY - 82.0) controlPoint2:CGPointMake(centerX - 112.0, centerY - 116.0)];
        [frosting addCurveToPoint:CGPointMake(centerX, centerY - 136.0) controlPoint1:CGPointMake(centerX - 58.0, centerY - 168.0) controlPoint2:CGPointMake(centerX - 18.0, centerY - 168.0)];
        [frosting addCurveToPoint:CGPointMake(centerX + 78.0, centerY - 112.0) controlPoint1:CGPointMake(centerX + 18.0, centerY - 168.0) controlPoint2:CGPointMake(centerX + 58.0, centerY - 168.0)];
        [frosting addCurveToPoint:CGPointMake(centerX + 142.0, centerY - 18.0) controlPoint1:CGPointMake(centerX + 112.0, centerY - 116.0) controlPoint2:CGPointMake(centerX + 150.0, centerY - 82.0)];
        [frosting addCurveToPoint:CGPointMake(centerX - 142.0, centerY - 18.0) controlPoint1:CGPointMake(centerX + 84.0, centerY + 16.0) controlPoint2:CGPointMake(centerX - 84.0, centerY + 16.0)];
        [frosting closePath];
        [weakSelf strokePath:frosting width:12.0];

        UIBezierPath *cup = [UIBezierPath bezierPath];
        [cup moveToPoint:CGPointMake(centerX - 118.0, centerY)];
        [cup addLineToPoint:CGPointMake(centerX + 118.0, centerY)];
        [cup addLineToPoint:CGPointMake(centerX + 82.0, centerY + 158.0)];
        [cup addLineToPoint:CGPointMake(centerX - 82.0, centerY + 158.0)];
        [cup closePath];
        [weakSelf strokePath:cup width:12.0];

        for (NSInteger index = -1; index <= 1; index++) {
            [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(centerX + index * 58.0 - 12.0, centerY - 70.0 + (index == 0 ? -24.0 : 0.0), 24.0, 24.0)] width:8.0];
        }
    }];

    KDLineArtItem *dino = [KDLineArtItem itemWithTitle:@"Dino" drawingBlock:^(CGRect rect) {
        CGFloat centerX = CGRectGetMidX(rect);
        CGFloat centerY = CGRectGetMidY(rect) + 28.0;

        UIBezierPath *body = [UIBezierPath bezierPath];
        [body moveToPoint:CGPointMake(centerX - 176.0, centerY + 16.0)];
        [body addCurveToPoint:CGPointMake(centerX - 44.0, centerY - 96.0) controlPoint1:CGPointMake(centerX - 166.0, centerY - 68.0) controlPoint2:CGPointMake(centerX - 104.0, centerY - 112.0)];
        [body addLineToPoint:CGPointMake(centerX + 72.0, centerY - 96.0)];
        [body addCurveToPoint:CGPointMake(centerX + 178.0, centerY - 28.0) controlPoint1:CGPointMake(centerX + 132.0, centerY - 96.0) controlPoint2:CGPointMake(centerX + 178.0, centerY - 70.0)];
        [body addCurveToPoint:CGPointMake(centerX + 120.0, centerY + 84.0) controlPoint1:CGPointMake(centerX + 178.0, centerY + 40.0) controlPoint2:CGPointMake(centerX + 156.0, centerY + 82.0)];
        [body addLineToPoint:CGPointMake(centerX - 64.0, centerY + 84.0)];
        [body addCurveToPoint:CGPointMake(centerX - 176.0, centerY + 16.0) controlPoint1:CGPointMake(centerX - 118.0, centerY + 84.0) controlPoint2:CGPointMake(centerX - 160.0, centerY + 60.0)];
        [body closePath];
        [weakSelf strokePath:body width:12.0];

        [weakSelf strokePath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(centerX + 94.0, centerY - 54.0, 28.0, 28.0)] width:9.0];

        UIBezierPath *tail = [UIBezierPath bezierPath];
        [tail moveToPoint:CGPointMake(centerX - 162.0, centerY + 20.0)];
        [tail addLineToPoint:CGPointMake(centerX - 252.0, centerY - 44.0)];
        [tail addLineToPoint:CGPointMake(centerX - 184.0, centerY + 64.0)];
        [tail closePath];
        [weakSelf strokePath:tail width:12.0];

        UIBezierPath *spikes = [UIBezierPath bezierPath];
        for (NSInteger i = 0; i < 4; i++) {
            CGFloat x = centerX - 56.0 + i * 52.0;
            [spikes moveToPoint:CGPointMake(x, centerY - 96.0)];
            [spikes addLineToPoint:CGPointMake(x + 26.0, centerY - 142.0)];
            [spikes addLineToPoint:CGPointMake(x + 52.0, centerY - 96.0)];
        }
        [weakSelf strokePath:spikes width:12.0];

        [weakSelf strokePath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(centerX - 52.0, centerY + 78.0, 42.0, 88.0) cornerRadius:16.0] width:12.0];
        [weakSelf strokePath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(centerX + 58.0, centerY + 78.0, 42.0, 88.0) cornerRadius:16.0] width:12.0];
    }];

    return @[bunny, car, fish, flower, house, rocket, cupcake, dino];
}

- (NSArray<UIColor *> *)makePalette24 {
    return @[
        [UIColor colorWithRed:0.94 green:0.43 blue:0.45 alpha:1.0],
        [UIColor colorWithRed:0.94 green:0.55 blue:0.36 alpha:1.0],
        [UIColor colorWithRed:0.96 green:0.71 blue:0.34 alpha:1.0],
        [UIColor colorWithRed:0.95 green:0.80 blue:0.41 alpha:1.0],
        [UIColor colorWithRed:0.75 green:0.84 blue:0.39 alpha:1.0],
        [UIColor colorWithRed:0.56 green:0.84 blue:0.63 alpha:1.0],
        [UIColor colorWithRed:0.43 green:0.79 blue:0.70 alpha:1.0],
        [UIColor colorWithRed:0.45 green:0.73 blue:0.97 alpha:1.0],
        [UIColor colorWithRed:0.55 green:0.54 blue:0.95 alpha:1.0],
        [UIColor colorWithRed:0.70 green:0.49 blue:0.93 alpha:1.0],
        [UIColor colorWithRed:0.94 green:0.63 blue:0.74 alpha:1.0],
        [UIColor colorWithRed:0.91 green:0.39 blue:0.65 alpha:1.0],
        [UIColor colorWithRed:0.88 green:0.26 blue:0.38 alpha:1.0],
        [UIColor colorWithRed:0.70 green:0.22 blue:0.27 alpha:1.0],
        [UIColor colorWithRed:0.66 green:0.44 blue:0.22 alpha:1.0],
        [UIColor colorWithRed:0.81 green:0.64 blue:0.34 alpha:1.0],
        [UIColor colorWithRed:0.59 green:0.47 blue:0.87 alpha:1.0],
        [UIColor colorWithRed:0.38 green:0.58 blue:0.95 alpha:1.0],
        [UIColor colorWithRed:0.22 green:0.54 blue:0.82 alpha:1.0],
        [UIColor colorWithRed:0.20 green:0.63 blue:0.57 alpha:1.0],
        [UIColor colorWithRed:0.26 green:0.52 blue:0.34 alpha:1.0],
        [UIColor colorWithRed:0.37 green:0.35 blue:0.31 alpha:1.0],
        [UIColor colorWithWhite:0.63 alpha:1.0],
        [UIColor colorWithRed:0.14 green:0.16 blue:0.19 alpha:1.0]
    ];
}

- (NSArray<UIColor *> *)makePalette36 {
    NSMutableArray<UIColor *> *colors = [[self makePalette24] mutableCopy];
    [colors addObjectsFromArray:@[
        [UIColor colorWithRed:0.98 green:0.81 blue:0.81 alpha:1.0],
        [UIColor colorWithRed:0.99 green:0.90 blue:0.76 alpha:1.0],
        [UIColor colorWithRed:0.86 green:0.93 blue:0.73 alpha:1.0],
        [UIColor colorWithRed:0.75 green:0.92 blue:0.89 alpha:1.0],
        [UIColor colorWithRed:0.80 green:0.89 blue:0.99 alpha:1.0],
        [UIColor colorWithRed:0.89 green:0.83 blue:0.98 alpha:1.0],
        [UIColor colorWithRed:0.97 green:0.82 blue:0.91 alpha:1.0],
        [UIColor colorWithRed:0.89 green:0.69 blue:0.56 alpha:1.0],
        [UIColor colorWithRed:0.63 green:0.72 blue:0.79 alpha:1.0],
        [UIColor colorWithWhite:0.86 alpha:1.0],
        [UIColor colorWithWhite:0.96 alpha:1.0],
        [UIColor colorWithWhite:0.05 alpha:1.0]
    ]];
    return colors;
}

- (NSArray<UIColor *> *)currentPalette {
    return self.showing36Palette ? self.palette36 : self.palette24;
}

- (NSInteger)paletteGridColumns {
    return 6;
}

- (CGFloat)paletteColorButtonSize {
    return 30.0;
}

- (CGFloat)paletteColorButtonSpacing {
    return 8.0;
}

- (CGFloat)paletteGridWidth {
    NSInteger columns = [self paletteGridColumns];
    return columns * [self paletteColorButtonSize] + (columns - 1) * [self paletteColorButtonSpacing];
}

- (CGFloat)paletteGridHeightForColorCount:(NSInteger)colorCount {
    NSInteger columns = [self paletteGridColumns];
    NSInteger rows = (colorCount + columns - 1) / columns;
    return rows * [self paletteColorButtonSize] + MAX(0, rows - 1) * [self paletteColorButtonSpacing];
}

- (UIImage *)colorWheelImage {
    static UIImage *cachedImage = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(44.0, 44.0);
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
        cachedImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
            CGPoint center = CGPointMake(size.width * 0.5, size.height * 0.5);
            CGFloat outerRadius = size.width * 0.5;
            CGFloat innerRadius = 14.0;
            NSInteger sliceCount = 120;

            for (NSInteger index = 0; index < sliceCount; index++) {
                CGFloat startAngle = ((CGFloat)index / (CGFloat)sliceCount) * (CGFloat)M_PI * 2.0 - (CGFloat)M_PI_2;
                CGFloat endAngle = ((CGFloat)(index + 1) / (CGFloat)sliceCount) * (CGFloat)M_PI * 2.0 - (CGFloat)M_PI_2;
                UIColor *segmentColor = [UIColor colorWithHue:(CGFloat)index / (CGFloat)sliceCount saturation:0.9 brightness:1.0 alpha:1.0];
                UIBezierPath *segment = [UIBezierPath bezierPath];
                [segment addArcWithCenter:center radius:outerRadius startAngle:startAngle endAngle:endAngle clockwise:YES];
                [segment addArcWithCenter:center radius:innerRadius startAngle:endAngle endAngle:startAngle clockwise:NO];
                [segment closePath];
                [segmentColor setFill];
                [segment fill];
            }
        }];
    });
    return cachedImage;
}

- (void)reloadPaletteGrid {
    UIView *grid = [self.view viewWithTag:701];
    [grid.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.colorButtons removeAllObjects];

    NSArray<UIColor *> *palette = [self currentPalette];
    CGFloat buttonSize = [self paletteColorButtonSize];
    CGFloat spacing = [self paletteColorButtonSpacing];
    NSInteger columns = [self paletteGridColumns];
    self.paletteGridHeightConstraint.constant = [self paletteGridHeightForColorCount:palette.count];

    for (NSInteger index = 0; index < palette.count; index++) {
        UIButton *colorButton = [UIButton buttonWithType:UIButtonTypeCustom];
        colorButton.translatesAutoresizingMaskIntoConstraints = NO;
        colorButton.backgroundColor = palette[index];
        colorButton.layer.cornerRadius = 13.0;
        colorButton.layer.borderWidth = 3.0;
        colorButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.92].CGColor;
        colorButton.tag = index;
        colorButton.accessibilityLabel = [NSString stringWithFormat:@"Color %ld", (long)index + 1];
        colorButton.accessibilityIdentifier = [NSString stringWithFormat:@"palette.color.%ld", (long)index + 1];
        [colorButton addTarget:self action:@selector(didTapColorButton:) forControlEvents:UIControlEventTouchUpInside];
        [self registerPressFeedbackForControl:colorButton];
        [grid addSubview:colorButton];
        [self.colorButtons addObject:colorButton];

        NSInteger row = index / columns;
        NSInteger column = index % columns;
        [NSLayoutConstraint activateConstraints:@[
            [colorButton.leadingAnchor constraintEqualToAnchor:grid.leadingAnchor constant:column * (buttonSize + spacing)],
            [colorButton.topAnchor constraintEqualToAnchor:grid.topAnchor constant:row * (buttonSize + spacing)],
            [colorButton.widthAnchor constraintEqualToConstant:buttonSize],
            [colorButton.heightAnchor constraintEqualToConstant:buttonSize]
        ]];
    }

    if (self.canvasView.currentColor) {
        [self selectColor:self.canvasView.currentColor sender:nil];
    }
}

- (void)reloadRecentColorRow {
    UIStackView *recentRow = self.recentColorRowStack ?: [self.view viewWithTag:702];
    if (![recentRow isKindOfClass:[UIStackView class]]) {
        return;
    }

    for (UIView *view in [recentRow.arrangedSubviews copy]) {
        [recentRow removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.recentColorButtons removeAllObjects];

    for (NSInteger index = 0; index < self.recentColors.count; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.backgroundColor = self.recentColors[index];
        button.layer.cornerRadius = 13.0;
        button.layer.borderWidth = 3.0;
        button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.92].CGColor;
        button.tag = index;
        button.accessibilityLabel = [NSString stringWithFormat:@"Recent Color %ld", (long)index + 1];
        button.accessibilityIdentifier = [NSString stringWithFormat:@"palette.recent.%ld", (long)index + 1];
        [button addTarget:self action:@selector(didTapRecentColorButton:) forControlEvents:UIControlEventTouchUpInside];
        [self registerPressFeedbackForControl:button];
        [NSLayoutConstraint activateConstraints:@[
            [button.widthAnchor constraintEqualToConstant:30.0],
            [button.heightAnchor constraintEqualToConstant:30.0]
        ]];
        [recentRow addArrangedSubview:button];
        [self.recentColorButtons addObject:button];
    }
}

- (NSArray<NSString *> *)currentStickerSymbols {
    NSArray<NSString *> *symbols = self.stickerSymbolsByCategory[self.selectedStickerCategory];
    if (symbols.count > 0) {
        return symbols;
    }
    return self.stickerSymbolsByCategory[self.stickerCategories.firstObject] ?: @[];
}

- (void)reloadStickerButtons {
    for (UIView *view in [self.stickerRowStack.arrangedSubviews copy]) {
        [self.stickerRowStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.stickerButtons removeAllObjects];

    for (NSString *symbol in [self currentStickerSymbols]) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button setImage:[self safeSystemImageNamed:symbol] forState:UIControlStateNormal];
        button.tintColor = [UIColor colorWithRed:0.24 green:0.29 blue:0.35 alpha:1.0];
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.76];
        button.layer.cornerRadius = 18.0;
        button.layer.borderWidth = 1.0;
        button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.72].CGColor;
        [button.widthAnchor constraintEqualToConstant:44.0].active = YES;
        [button.heightAnchor constraintEqualToConstant:44.0].active = YES;
        button.accessibilityIdentifier = symbol;
        button.accessibilityLabel = [self stickerAccessibilityLabelForSymbol:symbol];
        [button addTarget:self action:@selector(didTapStickerButton:) forControlEvents:UIControlEventTouchUpInside];
        [self registerPressFeedbackForControl:button];
        [self.stickerRowStack addArrangedSubview:button];
        [self.stickerButtons addObject:button];
    }

    [self refreshStickerCategoryButtons];
    [self selectStickerSymbol:self.canvasView.currentStickerSymbol ?: [self currentStickerSymbols].firstObject];
}

- (void)refreshStickerCategoryButtons {
    for (UIButton *button in self.stickerCategoryButtons) {
        NSString *category = [self stickerCategoryFromButton:button];
        BOOL active = [category isEqualToString:self.selectedStickerCategory];
        button.backgroundColor = active
            ? [UIColor colorWithRed:0.97 green:0.86 blue:0.48 alpha:1.0]
            : [UIColor colorWithWhite:1.0 alpha:0.62];
        button.tintColor = active
            ? [UIColor colorWithRed:0.39 green:0.26 blue:0.0 alpha:1.0]
            : [UIColor colorWithRed:0.47 green:0.52 blue:0.58 alpha:1.0];
        button.layer.borderColor = (active
            ? [UIColor colorWithWhite:1.0 alpha:0.92]
            : [UIColor colorWithWhite:1.0 alpha:0.70]).CGColor;
    }
}

- (NSString *)stickerCategoryFromButton:(UIButton *)button {
    NSString *prefix = @"sticker.category.";
    NSString *identifier = button.accessibilityIdentifier ?: @"";
    if (![identifier hasPrefix:prefix]) {
        return nil;
    }

    NSString *slug = [identifier substringFromIndex:prefix.length];
    for (NSString *category in self.stickerCategories) {
        if ([[category lowercaseString] isEqualToString:slug]) {
            return category;
        }
    }
    return nil;
}

- (void)addRecentColor:(UIColor *)color {
    if (!color) {
        return;
    }

    for (NSInteger index = self.recentColors.count - 1; index >= 0; index--) {
        if ([self color:self.recentColors[index] matchesColor:color]) {
            [self.recentColors removeObjectAtIndex:index];
        }
    }

    [self.recentColors insertObject:color atIndex:0];
    while (self.recentColors.count > 8) {
        [self.recentColors removeLastObject];
    }

    [self persistRecentColors];
    [self reloadRecentColorRow];
}

- (NSArray<UIColor *> *)loadRecentColors {
    NSArray<NSDictionary *> *storedColors = [[NSUserDefaults standardUserDefaults] arrayForKey:@"KDRecentColors"];
    NSMutableArray<UIColor *> *colors = [NSMutableArray array];
    for (NSDictionary *components in storedColors) {
        if (![components isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSNumber *red = components[@"r"];
        NSNumber *green = components[@"g"];
        NSNumber *blue = components[@"b"];
        NSNumber *alpha = components[@"a"];
        if (!red || !green || !blue || !alpha) {
            continue;
        }
        [colors addObject:[UIColor colorWithRed:red.doubleValue green:green.doubleValue blue:blue.doubleValue alpha:alpha.doubleValue]];
    }
    return colors;
}

- (void)persistRecentColors {
    NSMutableArray<NSDictionary *> *storedColors = [NSMutableArray arrayWithCapacity:self.recentColors.count];
    for (UIColor *color in self.recentColors) {
        CGFloat red = 0.0;
        CGFloat green = 0.0;
        CGFloat blue = 0.0;
        CGFloat alpha = 0.0;
        if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) {
            continue;
        }
        [storedColors addObject:@{@"r": @(red), @"g": @(green), @"b": @(blue), @"a": @(alpha)}];
    }
    [[NSUserDefaults standardUserDefaults] setObject:storedColors forKey:@"KDRecentColors"];
}

- (void)loadBrushWidthPreferences {
    self.brushWidthsByStyle = [@{
        @(KDBrushStylePencil): @12.0,
        @(KDBrushStylePen): @9.0,
        @(KDBrushStyleCrayon): @18.0
    } mutableCopy];
    self.eraserSliderValue = 18.0;

    NSDictionary *storedWidths = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"KDBrushWidthsByStyle"];
    if ([storedWidths isKindOfClass:[NSDictionary class]]) {
        NSNumber *pencil = storedWidths[@"pencil"];
        NSNumber *pen = storedWidths[@"pen"];
        NSNumber *crayon = storedWidths[@"crayon"];
        NSNumber *eraser = storedWidths[@"eraser"];
        if (pencil) {
            self.brushWidthsByStyle[@(KDBrushStylePencil)] = @([self clampedBrushWidth:pencil.doubleValue]);
        }
        if (pen) {
            self.brushWidthsByStyle[@(KDBrushStylePen)] = @([self clampedBrushWidth:pen.doubleValue]);
        }
        if (crayon) {
            self.brushWidthsByStyle[@(KDBrushStyleCrayon)] = @([self clampedBrushWidth:crayon.doubleValue]);
        }
        if (eraser) {
            self.eraserSliderValue = [self clampedBrushWidth:eraser.doubleValue];
        }
    }
}

- (void)persistBrushWidthPreferences {
    NSDictionary *storedWidths = @{
        @"pencil": self.brushWidthsByStyle[@(KDBrushStylePencil)] ?: @12.0,
        @"pen": self.brushWidthsByStyle[@(KDBrushStylePen)] ?: @9.0,
        @"crayon": self.brushWidthsByStyle[@(KDBrushStyleCrayon)] ?: @18.0,
        @"eraser": @(self.eraserSliderValue)
    };
    [[NSUserDefaults standardUserDefaults] setObject:storedWidths forKey:@"KDBrushWidthsByStyle"];
}

- (CGFloat)clampedBrushWidth:(CGFloat)width {
    return MIN(36.0, MAX(4.0, width));
}

- (void)updatePaletteButtons {
    BOOL palette36 = self.showing36Palette;
    [self.palette24Button setTitleColor:palette36 ? [UIColor colorWithRed:0.49 green:0.53 blue:0.59 alpha:1.0] : [UIColor colorWithRed:0.39 green:0.26 blue:0.0 alpha:1.0] forState:UIControlStateNormal];
    self.palette24Button.backgroundColor = palette36 ? [UIColor clearColor] : [UIColor colorWithRed:0.97 green:0.86 blue:0.48 alpha:1.0];
    self.palette24Button.layer.borderWidth = palette36 ? 0.0 : 1.0;
    [self.palette36Button setTitleColor:palette36 ? [UIColor colorWithRed:0.39 green:0.26 blue:0.0 alpha:1.0] : [UIColor colorWithRed:0.49 green:0.53 blue:0.59 alpha:1.0] forState:UIControlStateNormal];
    self.palette36Button.backgroundColor = palette36 ? [UIColor colorWithRed:0.97 green:0.86 blue:0.48 alpha:1.0] : [UIColor clearColor];
    self.palette36Button.layer.borderWidth = palette36 ? 1.0 : 0.0;
}

- (void)refreshHistoryUI {
    self.sessions = [self.sessionStore loadSessions];
    NSInteger maxPageIndex = [self maxHistoryPageIndex];
    self.historyPageIndex = MIN(MAX(0, self.historyPageIndex), maxPageIndex);
    self.previousHistoryButton.enabled = self.historyPageIndex > 0;
    self.nextHistoryButton.enabled = self.historyPageIndex < maxPageIndex;
    self.previousHistoryButton.alpha = self.previousHistoryButton.enabled ? 1.0 : 0.45;
    self.nextHistoryButton.alpha = self.nextHistoryButton.enabled ? 1.0 : 0.45;

    UIImage *draftImage = [self.sessionStore loadDraftImage];
    KDArtworkSession *selectedSession = [self currentSelectedHistorySession];
    BOOL canDeleteHistoryItem = selectedSession != nil || self.sessions.count > 0 || draftImage != nil;
    self.deleteHistoryButton.enabled = canDeleteHistoryItem;
    self.deleteHistoryButton.alpha = canDeleteHistoryItem ? 1.0 : 0.55;

    [self.draftThumbButton setBackgroundImage:draftImage forState:UIControlStateNormal];
    self.draftThumbButton.imageView.hidden = draftImage != nil;
    self.draftThumbButton.enabled = draftImage != nil;
    self.draftThumbButton.alpha = draftImage != nil ? 1.0 : 0.55;
    self.draftThumbButton.accessibilityLabel = draftImage != nil ? @"Draft Thumbnail" : @"No Draft Thumbnail";
    self.draftThumbButton.layer.borderColor = (draftImage != nil && self.activeSession == nil
        ? [UIColor colorWithRed:0.97 green:0.82 blue:0.46 alpha:0.92]
        : [UIColor colorWithRed:0.17 green:0.22 blue:0.30 alpha:0.08]).CGColor;
    self.draftThumbButton.transform = (draftImage != nil && self.activeSession == nil)
        ? CGAffineTransformMakeScale(1.02, 1.02)
        : CGAffineTransformIdentity;
    if (!draftImage) {
        self.draftThumbButton.imageView.hidden = NO;
        self.draftThumbButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.995 blue:0.98 alpha:1.0];
    }

    for (NSInteger index = 0; index < self.historyThumbButtons.count; index++) {
        UIButton *button = self.historyThumbButtons[index];
        NSInteger sessionIndex = [self sessionIndexForHistoryThumbIndex:index];
        if (sessionIndex < self.sessions.count) {
            KDArtworkSession *session = self.sessions[sessionIndex];
            UIImage *image = [self.sessionStore thumbnailImageForSession:session];
            [button setBackgroundImage:image forState:UIControlStateNormal];
            button.imageView.hidden = image != nil;
            button.enabled = YES;
            button.accessibilityLabel = [NSString stringWithFormat:@"Saved Thumbnail %ld", (long)sessionIndex + 1];
            BOOL isActiveSession = self.activeSession != nil &&
                [self.activeSession.sessionIdentifier isEqualToString:session.sessionIdentifier];
            BOOL isSelectedSession = selectedSession != nil &&
                [selectedSession.sessionIdentifier isEqualToString:session.sessionIdentifier];
            BOOL isDirtyActiveSession = isActiveSession && self.activeSessionHasUnsavedChanges;
            if (isDirtyActiveSession) {
                button.accessibilityLabel = [NSString stringWithFormat:@"Unsaved Saved Thumbnail %ld", (long)sessionIndex + 1];
            } else if (isSelectedSession) {
                button.accessibilityLabel = [NSString stringWithFormat:@"Selected Saved Thumbnail %ld", (long)sessionIndex + 1];
            }
            UIColor *borderColor = [UIColor colorWithRed:0.17 green:0.22 blue:0.30 alpha:0.08];
            if (isDirtyActiveSession) {
                borderColor = [UIColor colorWithRed:0.97 green:0.70 blue:0.25 alpha:0.94];
            } else if (isSelectedSession) {
                borderColor = [UIColor colorWithRed:0.50 green:0.78 blue:0.56 alpha:0.90];
            } else if (isActiveSession) {
                borderColor = [UIColor colorWithRed:0.45 green:0.73 blue:0.97 alpha:0.82];
            }
            button.layer.borderColor = borderColor.CGColor;
            button.layer.borderWidth = isDirtyActiveSession ? 3.0 : 2.0;
            BOOL emphasized = isActiveSession || isSelectedSession;
            button.transform = emphasized ? CGAffineTransformMakeScale(isDirtyActiveSession ? 1.05 : 1.03, isDirtyActiveSession ? 1.05 : 1.03) : CGAffineTransformIdentity;
        } else {
            [button setBackgroundImage:nil forState:UIControlStateNormal];
            button.imageView.hidden = NO;
            button.enabled = NO;
            button.accessibilityLabel = [NSString stringWithFormat:@"Empty Saved Thumbnail %ld", (long)index + 1];
            button.backgroundColor = [UIColor colorWithRed:1.0 green:0.995 blue:0.98 alpha:1.0];
            button.layer.borderColor = [UIColor colorWithRed:0.17 green:0.22 blue:0.30 alpha:0.08].CGColor;
            button.layer.borderWidth = 2.0;
            button.transform = CGAffineTransformIdentity;
        }
    }
}

- (NSInteger)historyPageSize {
    return self.historyThumbButtons.count;
}

- (NSInteger)maxHistoryPageIndex {
    NSInteger pageSize = MAX(1, [self historyPageSize]);
    if (self.sessions.count == 0) {
        return 0;
    }
    return (self.sessions.count - 1) / pageSize;
}

- (NSInteger)sessionIndexForHistoryThumbIndex:(NSInteger)thumbIndex {
    return self.historyPageIndex * [self historyPageSize] + thumbIndex;
}

- (KDArtworkSession *)currentSelectedHistorySession {
    if (!self.selectedHistorySession.sessionIdentifier.length) {
        return nil;
    }

    for (KDArtworkSession *session in self.sessions) {
        if ([session.sessionIdentifier isEqualToString:self.selectedHistorySession.sessionIdentifier]) {
            return session;
        }
    }

    self.selectedHistorySession = nil;
    return nil;
}

- (void)selectToolMode:(KDToolMode)mode {
    self.canvasView.currentToolMode = mode;
    [self applyStoredWidthForCurrentTool];
    for (KDToolButton *button in self.toolButtons) {
        BOOL active = button.toolMode == mode;
        button.backgroundColor = active
            ? [UIColor colorWithRed:0.66 green:0.89 blue:0.72 alpha:1.0]
            : (button.toolMode == KDToolModePicker
                ? [UIColor colorWithRed:0.96 green:0.85 blue:0.48 alpha:1.0]
                : [UIColor colorWithWhite:1.0 alpha:0.82]);
        button.layer.borderColor = (active
            ? [UIColor colorWithWhite:1.0 alpha:0.92]
            : [UIColor colorWithWhite:1.0 alpha:0.72]).CGColor;
        button.layer.shadowOpacity = active ? 0.18 : 0.10;
        button.transform = active ? CGAffineTransformMakeScale(1.04, 1.04) : CGAffineTransformIdentity;
    }
    [self refreshStickerEditButtons];
    [self refreshBrushDockSelection];
    [self scrollBrushDockToToolMode:mode];
    [self refreshSizePreview];
}

- (void)selectBrushStyle:(KDBrushStyle)style {
    self.canvasView.currentBrushStyle = style;
    [self applyStoredWidthForCurrentTool];
    [self refreshBrushDockSelection];
    [self refreshSizePreview];
}

- (void)applyStoredWidthForCurrentTool {
    if (!self.sizeSlider) {
        return;
    }

    CGFloat width = self.sizeSlider.value;
    if (self.canvasView.currentToolMode == KDToolModeBrush) {
        NSNumber *storedWidth = self.brushWidthsByStyle[@(self.canvasView.currentBrushStyle)];
        width = storedWidth ? storedWidth.doubleValue : 12.0;
    } else if (self.canvasView.currentToolMode == KDToolModeEraser) {
        width = self.eraserSliderValue;
    }

    width = [self clampedBrushWidth:width];
    self.sizeSlider.value = width;
    self.canvasView.currentLineWidth = width;
    [self refreshSizePreview];
}

- (void)refreshSizePreview {
    if (!self.sizePreviewView || !self.sizePreviewShapeLayer) {
        return;
    }

    CGRect bounds = self.sizePreviewView.bounds;
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    BOOL emphasizesSize = self.canvasView.currentToolMode == KDToolModeBrush || self.canvasView.currentToolMode == KDToolModeEraser;
    CGFloat previewDiameter = MIN(36.0, MAX(8.0, self.sizeSlider.value));
    CGPoint center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    UIBezierPath *path = nil;
    UIColor *fillColor = self.canvasView.currentColor ?: [UIColor colorWithRed:0.94 green:0.43 blue:0.45 alpha:1.0];
    UIColor *strokeColor = [UIColor colorWithWhite:1.0 alpha:0.92];
    CGFloat alpha = 1.0;

    if (self.canvasView.currentToolMode == KDToolModeEraser) {
        previewDiameter = MIN(38.0, MAX(16.0, self.sizeSlider.value * 1.08));
        path = [self previewPathForEraserShape:self.canvasView.currentEraserShape center:center size:previewDiameter];
        fillColor = [UIColor colorWithWhite:1.0 alpha:1.0];
        strokeColor = [UIColor colorWithRed:0.50 green:0.56 blue:0.62 alpha:0.55];
    } else {
        path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(center.x - previewDiameter / 2.0,
                                                                 center.y - previewDiameter / 2.0,
                                                                 previewDiameter,
                                                                 previewDiameter)];
        if (self.canvasView.currentBrushStyle == KDBrushStylePencil) {
            alpha = 0.72;
        } else if (self.canvasView.currentBrushStyle == KDBrushStyleCrayon) {
            alpha = 0.82;
        }
    }

    self.sizePreviewView.alpha = emphasizesSize ? 1.0 : 0.45;
    self.sizePreviewShapeLayer.frame = bounds;
    self.sizePreviewShapeLayer.path = path.CGPath;
    self.sizePreviewShapeLayer.fillColor = [fillColor colorWithAlphaComponent:alpha].CGColor;
    self.sizePreviewShapeLayer.strokeColor = strokeColor.CGColor;
    self.sizePreviewShapeLayer.lineWidth = self.canvasView.currentToolMode == KDToolModeEraser ? 2.0 : 0.0;
}

- (UIBezierPath *)previewPathForEraserShape:(KDEraserShape)shape center:(CGPoint)center size:(CGFloat)size {
    CGFloat radius = size / 2.0;
    if (shape == KDEraserShapeCircle) {
        return [UIBezierPath bezierPathWithOvalInRect:CGRectMake(center.x - radius, center.y - radius, size, size)];
    }

    if (shape == KDEraserShapeCloud) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(center.x - radius * 1.05, center.y - radius * 0.32, radius * 0.95, radius * 0.74)]];
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(center.x - radius * 0.42, center.y - radius * 0.78, radius * 1.02, radius * 0.98)]];
        [path appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(center.x + radius * 0.18, center.y - radius * 0.28, radius * 0.90, radius * 0.70)]];
        return path;
    }

    UIBezierPath *star = [UIBezierPath bezierPath];
    NSInteger points = 5;
    CGFloat innerRadius = radius * 0.45;
    for (NSInteger i = 0; i < points * 2; i++) {
        CGFloat angle = (-M_PI_2) + i * (M_PI / points);
        CGFloat currentRadius = (i % 2 == 0) ? radius : innerRadius;
        CGPoint point = CGPointMake(center.x + currentRadius * cos(angle), center.y + currentRadius * sin(angle));
        if (i == 0) {
            [star moveToPoint:point];
        } else {
            [star addLineToPoint:point];
        }
    }
    [star closePath];
    return star;
}

- (void)refreshBrushDockSelection {
    for (KDBrushButton *button in self.brushButtons) {
        BOOL active = button.representsBrushStyle
            ? (self.canvasView.currentToolMode == KDToolModeBrush && button.brushStyle == self.canvasView.currentBrushStyle)
            : (button.toolMode == self.canvasView.currentToolMode);
        button.backgroundColor = active ? [UIColor colorWithRed:0.66 green:0.89 blue:0.72 alpha:1.0] : [UIColor colorWithWhite:1.0 alpha:0.84];
        button.layer.borderColor = (active
            ? [UIColor colorWithWhite:1.0 alpha:0.94]
            : [UIColor colorWithWhite:1.0 alpha:0.72]).CGColor;
        button.layer.shadowOpacity = active ? 0.20 : 0.12;
        button.transform = active ? CGAffineTransformMakeScale(1.03, 1.03) : CGAffineTransformIdentity;
        if (active) {
            [self scrollBrushDockToButton:button];
        }
    }
}

- (void)scrollBrushDockToToolMode:(KDToolMode)mode {
    for (KDBrushButton *button in self.brushButtons) {
        BOOL matches = button.representsBrushStyle
            ? (mode == KDToolModeBrush && button.brushStyle == self.canvasView.currentBrushStyle)
            : (button.toolMode == mode);
        if (matches) {
            [self scrollBrushDockToButton:button];
            return;
        }
    }
}

- (void)scrollBrushDockToButton:(UIButton *)button {
    UIScrollView *scrollView = [self scrollViewAncestorForView:button];
    if (!scrollView || CGRectIsEmpty(button.bounds)) {
        return;
    }

    CGRect targetRect = [button convertRect:button.bounds toView:scrollView];
    [scrollView scrollRectToVisible:CGRectInset(targetRect, -18.0, 0.0) animated:YES];
}

- (UIScrollView *)scrollViewAncestorForView:(UIView *)view {
    UIView *candidate = view.superview;
    while (candidate) {
        if ([candidate isKindOfClass:[UIScrollView class]]) {
            return (UIScrollView *)candidate;
        }
        candidate = candidate.superview;
    }
    return nil;
}

- (void)selectColor:(UIColor *)color sender:(UIButton *)sender {
    self.canvasView.currentColor = color;
    [self refreshSizePreview];
    if (self.activeColorButton) {
        self.activeColorButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.92].CGColor;
    }
    if (sender) {
        sender.layer.borderColor = [UIColor colorWithRed:0.12 green:0.16 blue:0.23 alpha:0.18].CGColor;
        self.activeColorButton = sender;
        return;
    }

    self.activeColorButton = nil;
    for (UIButton *colorButton in self.colorButtons) {
        NSArray<UIColor *> *palette = [self currentPalette];
        if (colorButton.tag >= palette.count) {
            continue;
        }
        UIColor *paletteColor = palette[colorButton.tag];
        if ([self color:paletteColor matchesColor:color]) {
            colorButton.layer.borderColor = [UIColor colorWithRed:0.12 green:0.16 blue:0.23 alpha:0.18].CGColor;
            self.activeColorButton = colorButton;
            break;
        }
    }

    for (UIButton *button in self.recentColorButtons) {
        if (button.tag < self.recentColors.count && [self color:self.recentColors[button.tag] matchesColor:color]) {
            button.layer.borderColor = [UIColor colorWithRed:0.12 green:0.16 blue:0.23 alpha:0.18].CGColor;
            self.activeColorButton = button;
            break;
        }
    }
}

- (void)selectStickerSymbol:(NSString *)symbol {
    if (symbol.length == 0) {
        symbol = [self currentStickerSymbols].firstObject;
    }
    self.canvasView.currentStickerSymbol = symbol;
    for (UIButton *button in self.stickerButtons) {
        BOOL active = [button.accessibilityIdentifier isEqualToString:symbol];
        button.layer.borderWidth = active ? 2.0 : 1.0;
        button.layer.borderColor = (active
            ? [UIColor colorWithRed:0.45 green:0.73 blue:0.97 alpha:0.55]
            : [UIColor colorWithWhite:1.0 alpha:0.72]).CGColor;
        button.backgroundColor = active
            ? [UIColor colorWithRed:0.86 green:0.94 blue:1.0 alpha:0.94]
            : [UIColor colorWithWhite:1.0 alpha:0.76];
        button.transform = active ? CGAffineTransformMakeScale(1.05, 1.05) : CGAffineTransformIdentity;
    }
}

- (void)didTapPalette24 {
    self.showing36Palette = NO;
    [self updatePaletteButtons];
    [self reloadPaletteGrid];
}

- (void)didTapPalette36 {
    self.showing36Palette = YES;
    [self updatePaletteButtons];
    [self reloadPaletteGrid];
}

- (void)didTapCustomColor {
    UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
    picker.delegate = self;
    picker.selectedColor = self.canvasView.currentColor ?: UIColor.systemRedColor;
    picker.modalPresentationStyle = UIModalPresentationPopover;
    UIPopoverPresentationController *popover = picker.popoverPresentationController;
    popover.sourceView = self.customColorButton ?: self.view;
    popover.sourceRect = self.customColorButton ? self.customColorButton.bounds : CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1.0, 1.0);
    popover.permittedArrowDirections = self.customColorButton ? UIPopoverArrowDirectionAny : 0;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    self.canvasView.currentColor = viewController.selectedColor;
    [self selectColor:viewController.selectedColor sender:nil];
    [self addRecentColor:viewController.selectedColor];
}

- (void)didTapNewCanvas {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear Canvas" message:@"Start a fresh drawing?" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction * _Nonnull action) {
        self.activeSession = nil;
        self.selectedHistorySession = nil;
        self.activeSessionHasUnsavedChanges = NO;
        [self.draftSaveTimer invalidate];
        self.draftSaveTimer = nil;
        self.suppressNextDraftSave = YES;
        [self.canvasView startBlankCanvas];
        [self.sessionStore clearDraftImage];
        [self refreshHistoryUI];
        [self refreshActionButtons];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)didTapUndo {
    [self.canvasView undoLastAction];
    [self refreshActionButtons];
}

- (void)didTapRedo {
    [self.canvasView redoLastAction];
    [self refreshActionButtons];
}

- (void)handleTwoFingerUndoTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateRecognized) {
        [self didTapUndo];
    }
}

- (void)handleTwoFingerRedoTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateRecognized) {
        [self didTapRedo];
    }
}

- (void)didTapImportImage {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [self showSaveToastWithSuccess:NO];
        return;
    }

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    UIPopoverPresentationController *popover = picker.popoverPresentationController;
    popover.sourceView = self.view;
    popover.sourceRect = CGRectMake(CGRectGetMaxX(self.view.bounds) - 110.0, 88.0, 1.0, 1.0);
    popover.permittedArrowDirections = UIPopoverArrowDirectionUp;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)didTapSaveSession {
    if (![self.canvasView hasVisibleContent]) {
        [self showSaveToastWithSuccess:NO];
        return;
    }

    UIImage *snapshot = [self.canvasView snapshotImage];
    KDArtworkSession *savedSession = [self.sessionStore saveImage:snapshot existingSession:self.activeSession];
    if (!savedSession) {
        [self showSaveToastWithSuccess:NO];
        return;
    }

    self.activeSession = savedSession;
    self.selectedHistorySession = savedSession;
    self.activeSessionHasUnsavedChanges = NO;
    [self.draftSaveTimer invalidate];
    self.draftSaveTimer = nil;
    [self.sessionStore clearDraftImage];
    self.historyPageIndex = 0;
    [self refreshHistoryUI];
    [self refreshActionButtons];
    UIImageWriteToSavedPhotosAlbum(snapshot, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    [self showSaveToastWithSuccess:(error == nil)];
}

- (void)didTapOpenLatestSession {
    if (self.sessions.count == 0) {
        return;
    }
    [self openSession:self.sessions.firstObject];
}

- (void)didTapDeleteLatestSession {
    UIImage *draftImage = [self.sessionStore loadDraftImage];
    KDArtworkSession *selectedSession = [self currentSelectedHistorySession];
    BOOL shouldDeleteDraft = selectedSession == nil && self.activeSession == nil && draftImage != nil;
    if (self.sessions.count == 0 && !shouldDeleteDraft) {
        return;
    }

    KDArtworkSession *session = shouldDeleteDraft ? nil : (selectedSession ?: (self.activeSession ?: self.sessions.firstObject));
    NSString *title = shouldDeleteDraft ? @"Delete Draft" : @"Delete Session";
    NSString *message = shouldDeleteDraft ? @"Remove this draft artwork?" : @"Remove this saved artwork?";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction * _Nonnull action) {
        if (shouldDeleteDraft) {
            [self.draftSaveTimer invalidate];
            self.draftSaveTimer = nil;
            [self.sessionStore clearDraftImage];
            if (self.activeSession == nil) {
                self.suppressNextDraftSave = YES;
                [self.canvasView startBlankCanvas];
                [self.sessionStore clearDraftImage];
            }
        } else {
            BOOL deletingActiveSession = [self.activeSession.sessionIdentifier isEqualToString:session.sessionIdentifier];
            [self.sessionStore deleteSession:session];
            if (deletingActiveSession) {
                self.activeSession = nil;
                self.selectedHistorySession = nil;
                self.activeSessionHasUnsavedChanges = NO;
                [self.draftSaveTimer invalidate];
                self.draftSaveTimer = nil;
                self.suppressNextDraftSave = YES;
                [self.canvasView startBlankCanvas];
                [self.sessionStore clearDraftImage];
            }
            if ([self.selectedHistorySession.sessionIdentifier isEqualToString:session.sessionIdentifier]) {
                self.selectedHistorySession = nil;
            }
        }
        if (shouldDeleteDraft) {
            self.activeSession = nil;
            self.selectedHistorySession = nil;
            self.activeSessionHasUnsavedChanges = NO;
        }
        [self refreshHistoryUI];
        [self refreshActionButtons];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)didTapCircleEraser {
    self.canvasView.currentEraserShape = KDEraserShapeCircle;
    [self refreshEraserShapeButtons];
    [self selectToolMode:KDToolModeEraser];
    [self refreshSizePreview];
}

- (void)didTapCloudEraser {
    self.canvasView.currentEraserShape = KDEraserShapeCloud;
    [self refreshEraserShapeButtons];
    [self selectToolMode:KDToolModeEraser];
    [self refreshSizePreview];
}

- (void)didTapStarEraser {
    self.canvasView.currentEraserShape = KDEraserShapeStar;
    [self refreshEraserShapeButtons];
    [self selectToolMode:KDToolModeEraser];
    [self refreshSizePreview];
}

- (void)didTapDeleteSticker {
    [self.canvasView deleteSelectedSticker];
    [self refreshStickerEditButtons];
}

- (void)didTapBringStickerFront {
    [self.canvasView bringSelectedStickerToFront];
    [self refreshStickerEditButtons];
}

- (void)didTapLineArtPicker {
    UIViewController *picker = [[UIViewController alloc] init];
    picker.modalPresentationStyle = UIModalPresentationPopover;
    picker.preferredContentSize = CGSizeMake(450.0, 420.0);
    picker.view.accessibilityIdentifier = @"line-art.picker";

    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.layer.cornerRadius = 28.0;
    panel.clipsToBounds = YES;
    [picker.view addSubview:panel];

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.alwaysBounceVertical = YES;
    [panel.contentView addSubview:scrollView];

    UIStackView *grid = [[UIStackView alloc] init];
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    grid.axis = UILayoutConstraintAxisVertical;
    grid.spacing = 14.0;
    grid.distribution = UIStackViewDistributionFill;
    [scrollView addSubview:grid];

    NSInteger columns = 2;
    NSInteger rows = (self.lineArtItems.count + columns - 1) / columns;
    for (NSInteger row = 0; row < rows; row++) {
        UIStackView *rowStack = [[UIStackView alloc] init];
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.spacing = 14.0;
        rowStack.distribution = UIStackViewDistributionFillEqually;
        [grid addArrangedSubview:rowStack];
        [rowStack.heightAnchor constraintEqualToConstant:132.0].active = YES;

        for (NSInteger column = 0; column < columns; column++) {
            NSInteger index = row * columns + column;
            if (index >= self.lineArtItems.count) {
                UIView *spacer = [[UIView alloc] init];
                [rowStack addArrangedSubview:spacer];
                continue;
            }

            KDLineArtItem *item = self.lineArtItems[index];
            UIButton *button = [self lineArtPreviewButtonForItem:item index:index];
            [button addTarget:self action:@selector(didTapLineArtPreviewButton:) forControlEvents:UIControlEventTouchUpInside];
            [rowStack addArrangedSubview:button];
        }
    }

    [NSLayoutConstraint activateConstraints:@[
        [panel.leadingAnchor constraintEqualToAnchor:picker.view.leadingAnchor],
        [panel.trailingAnchor constraintEqualToAnchor:picker.view.trailingAnchor],
        [panel.topAnchor constraintEqualToAnchor:picker.view.topAnchor],
        [panel.bottomAnchor constraintEqualToAnchor:picker.view.bottomAnchor],

        [scrollView.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:18.0],
        [scrollView.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-18.0],
        [scrollView.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:18.0],
        [scrollView.bottomAnchor constraintEqualToAnchor:panel.contentView.bottomAnchor constant:-18.0],

        [grid.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [grid.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [grid.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [grid.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [grid.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor]
    ]];

    UIPopoverPresentationController *popover = picker.popoverPresentationController;
    popover.sourceView = self.view;
    popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), 104.0, 1.0, 1.0);
    popover.permittedArrowDirections = UIPopoverArrowDirectionUp;
    [self presentViewController:picker animated:YES completion:nil];
}

- (UIButton *)lineArtPreviewButtonForItem:(KDLineArtItem *)item index:(NSInteger)index {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor colorWithRed:1.0 green:0.995 blue:0.98 alpha:0.96];
    button.layer.cornerRadius = 24.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.76].CGColor;
    button.layer.shadowColor = [UIColor colorWithRed:0.40 green:0.32 blue:0.22 alpha:1.0].CGColor;
    button.layer.shadowOpacity = 0.08;
    button.layer.shadowRadius = 10.0;
    button.layer.shadowOffset = CGSizeMake(0, 6);
    button.tag = index;
    [button setImage:[self thumbnailImageForLineArtItem:item] forState:UIControlStateNormal];
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    button.imageEdgeInsets = UIEdgeInsetsMake(14.0, 18.0, 14.0, 18.0);
    [self applyAccessibilityLabel:item.title identifier:[NSString stringWithFormat:@"line-art.%@", [item.title lowercaseString]] toControl:button];
    [self registerPressFeedbackForControl:button];
    return button;
}

- (void)didTapLineArtPreviewButton:(UIButton *)button {
    NSInteger index = button.tag;
    if (index >= self.lineArtItems.count) {
        return;
    }

    KDLineArtItem *item = self.lineArtItems[index];
    [self dismissViewControllerAnimated:YES completion:^{
        [self loadLineArtItem:item];
    }];
}

- (UIImage *)thumbnailImageForLineArtItem:(KDLineArtItem *)item {
    CGSize size = CGSizeMake(160.0, 112.0);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [[UIColor colorWithRed:1.0 green:0.995 blue:0.98 alpha:1.0] setFill];
        UIRectFill((CGRect){CGPointZero, size});
        [[UIColor colorWithRed:0.18 green:0.23 blue:0.30 alpha:1.0] setStroke];

        CGRect drawingRect = CGRectInset((CGRect){CGPointZero, size}, 22.0, 18.0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSaveGState(context);
        CGFloat scale = MIN(drawingRect.size.width / 520.0, drawingRect.size.height / 420.0);
        CGFloat previousStrokeScale = self.lineArtStrokeScale;
        self.lineArtStrokeScale = 0.22;
        @try {
            CGContextTranslateCTM(context, CGRectGetMidX(drawingRect), CGRectGetMidY(drawingRect));
            CGContextScaleCTM(context, scale, scale);
            CGContextTranslateCTM(context, -260.0, -210.0);
            if (item.drawingBlock) {
                item.drawingBlock(CGRectMake(0.0, 0.0, 520.0, 420.0));
            }
        } @finally {
            self.lineArtStrokeScale = previousStrokeScale;
        }
        CGContextRestoreGState(context);
    }];
}

- (void)loadLineArtItem:(KDLineArtItem *)item {
    CGSize canvasSize = self.canvasView.bounds.size;
    if (CGSizeEqualToSize(canvasSize, CGSizeZero)) {
        canvasSize = CGSizeMake(1024.0, 720.0);
    }
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:canvasSize];
    UIImage *lineArt = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [[UIColor whiteColor] setFill];
        UIRectFill((CGRect){CGPointZero, canvasSize});
        CGContextRef context = rendererContext.CGContext;
        CGContextSetLineWidth(context, 12.0);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);

        CGRect drawingRect = CGRectInset((CGRect){CGPointZero, canvasSize}, 110.0, 90.0);
        if (item.drawingBlock) {
            item.drawingBlock(drawingRect);
        }
    }];

    BOOL preservedDraft = [self preserveUnsavedActiveSessionDraftIfNeeded];
    self.activeSession = nil;
    self.selectedHistorySession = nil;
    self.activeSessionHasUnsavedChanges = NO;
    [self.draftSaveTimer invalidate];
    self.draftSaveTimer = nil;
    if (!preservedDraft) {
        [self.sessionStore clearDraftImage];
    }
    [self.canvasView loadLineArtImage:lineArt];
    [self selectToolMode:KDToolModeFill];
    [self refreshHistoryUI];
    [self refreshActionButtons];
}

- (void)didTapToolButton:(KDToolButton *)button {
    [self selectToolMode:button.toolMode];
}

- (void)didTapColorButton:(UIButton *)button {
    NSArray<UIColor *> *palette = [self currentPalette];
    if (button.tag < palette.count) {
        [self selectColor:palette[button.tag] sender:button];
    }
}

- (void)didTapRecentColorButton:(UIButton *)button {
    if (button.tag < self.recentColors.count) {
        [self selectColor:self.recentColors[button.tag] sender:button];
    }
}

- (void)didTapBrushButton:(KDBrushButton *)button {
    if (!button.representsBrushStyle) {
        [self selectToolMode:button.toolMode];
        return;
    }

    [self selectToolMode:KDToolModeBrush];
    [self selectBrushStyle:button.brushStyle];
}

- (void)didTapStickerButton:(UIButton *)button {
    [self selectStickerSymbol:button.accessibilityIdentifier];
    [self selectToolMode:KDToolModeSticker];
    [self refreshStickerEditButtons];
}

- (void)didTapStickerCategoryButton:(UIButton *)button {
    NSString *category = [self stickerCategoryFromButton:button];
    if (!self.stickerSymbolsByCategory[category]) {
        return;
    }

    self.selectedStickerCategory = category;
    NSString *firstSymbol = [self currentStickerSymbols].firstObject;
    if (firstSymbol.length > 0) {
        self.canvasView.currentStickerSymbol = firstSymbol;
    }
    [self reloadStickerButtons];
}

- (void)didTapHistoryThumb:(UIButton *)button {
    NSInteger index = [self sessionIndexForHistoryThumbIndex:button.tag];
    if (index < self.sessions.count) {
        KDArtworkSession *session = self.sessions[index];
        self.selectedHistorySession = session;
        [self openSession:session];
    }
}

- (void)didTapPreviousHistoryPage {
    if (self.historyPageIndex == 0) {
        return;
    }
    self.historyPageIndex -= 1;
    [self refreshHistoryUI];
}

- (void)didTapNextHistoryPage {
    if (self.historyPageIndex >= [self maxHistoryPageIndex]) {
        return;
    }
    self.historyPageIndex += 1;
    [self refreshHistoryUI];
}

- (void)didTapDraftThumb {
    UIImage *draftImage = [self.sessionStore loadDraftImage];
    if (!draftImage) {
        return;
    }

    self.activeSession = nil;
    self.selectedHistorySession = nil;
    self.activeSessionHasUnsavedChanges = NO;
    [self.canvasView restoreCanvasWithImage:draftImage];
    [self refreshHistoryUI];
    [self refreshActionButtons];
}

- (void)didChangeSizeSlider:(UISlider *)slider {
    CGFloat width = [self clampedBrushWidth:slider.value];
    slider.value = width;
    self.canvasView.currentLineWidth = width;
    if (self.canvasView.currentToolMode == KDToolModeBrush) {
        self.brushWidthsByStyle[@(self.canvasView.currentBrushStyle)] = @(width);
    } else if (self.canvasView.currentToolMode == KDToolModeEraser) {
        self.eraserSliderValue = width;
    }
    [self persistBrushWidthPreferences];
    [self refreshSizePreview];
}

- (void)openSession:(KDArtworkSession *)session {
    UIImage *image = [self.sessionStore artworkImageForSession:session];
    if (!image) {
        return;
    }
    BOOL preservedDraft = [self preserveUnsavedActiveSessionDraftIfNeeded];
    self.activeSession = session;
    self.selectedHistorySession = session;
    self.activeSessionHasUnsavedChanges = NO;
    [self.draftSaveTimer invalidate];
    self.draftSaveTimer = nil;
    self.suppressNextDraftSave = YES;
    [self.canvasView restoreCanvasWithImage:image];
    if (!preservedDraft) {
        [self.sessionStore clearDraftImage];
    }
    [self updateHistoryPageForActiveSession];
    [self refreshHistoryUI];
    [self refreshActionButtons];
}

- (BOOL)preserveUnsavedActiveSessionDraftIfNeeded {
    if (self.activeSession == nil || !self.activeSessionHasUnsavedChanges || ![self.canvasView hasVisibleContent]) {
        return NO;
    }

    [self.draftSaveTimer invalidate];
    self.draftSaveTimer = nil;
    UIImage *snapshot = [self.canvasView snapshotImage];
    [self.sessionStore saveDraftImage:snapshot];
    return YES;
}

- (void)updateHistoryPageForActiveSession {
    if (!self.activeSession.sessionIdentifier.length) {
        return;
    }

    NSUInteger index = [self.sessions indexOfObjectPassingTest:^BOOL(KDArtworkSession *candidate, NSUInteger idx, BOOL *stop) {
        return [candidate.sessionIdentifier isEqualToString:self.activeSession.sessionIdentifier];
    }];
    if (index != NSNotFound) {
        self.historyPageIndex = index / MAX(1, [self historyPageSize]);
    }
}

- (void)drawingCanvasView:(KDDrawingCanvasView *)canvasView didPickColor:(UIColor *)color {
    self.canvasView.currentColor = color;
    [self selectColor:color sender:nil];
    [self addRecentColor:color];
}

- (void)drawingCanvasViewSelectionDidChange:(KDDrawingCanvasView *)canvasView {
    [self refreshStickerEditButtons];
}

- (void)drawingCanvasViewContentDidChange:(KDDrawingCanvasView *)canvasView {
    [self refreshActionButtons];
    if (self.suppressNextDraftSave) {
        self.suppressNextDraftSave = NO;
        return;
    }
    if (self.activeSession != nil) {
        self.activeSessionHasUnsavedChanges = YES;
    }
    [self scheduleDraftSave];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    UIImage *normalizedImage = [self normalizedImageFromImage:image];
    if (normalizedImage) {
        BOOL preservedDraft = [self preserveUnsavedActiveSessionDraftIfNeeded];
        self.activeSession = nil;
        self.selectedHistorySession = nil;
        self.activeSessionHasUnsavedChanges = NO;
        [self.draftSaveTimer invalidate];
        self.draftSaveTimer = nil;
        if (!preservedDraft) {
            [self.sessionStore clearDraftImage];
        }
        [self.canvasView replaceCanvasWithImage:normalizedImage];
        [self refreshHistoryUI];
        [self refreshActionButtons];
    } else {
        [self showSaveToastWithSuccess:NO];
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    self.canvasView.currentColor = viewController.selectedColor;
    [self selectColor:viewController.selectedColor sender:nil];
}

- (UIImage *)normalizedImageFromImage:(UIImage *)image {
    if (!image || image.size.width <= 0.0 || image.size.height <= 0.0) {
        return nil;
    }

    CGFloat maxDimension = 2400.0;
    CGSize imageSize = image.size;
    CGFloat scale = MIN(1.0, maxDimension / MAX(imageSize.width, imageSize.height));
    BOOL needsResize = scale < 1.0;

    if (image.imageOrientation == UIImageOrientationUp && !needsResize) {
        return image;
    }

    CGSize targetSize = needsResize ? CGSizeMake(imageSize.width * scale, imageSize.height * scale) : imageSize;
    if (targetSize.width <= 0.0 || targetSize.height <= 0.0) {
        return nil;
    }

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize];
    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [image drawInRect:(CGRect){CGPointZero, targetSize}];
    }];
}

- (void)refreshEraserShapeButtons {
    NSArray<UIButton *> *buttons = @[self.circleEraserButton, self.cloudEraserButton, self.starEraserButton];
    for (NSInteger index = 0; index < buttons.count; index++) {
        UIButton *button = buttons[index];
        BOOL active = index == self.canvasView.currentEraserShape;
        button.backgroundColor = active
            ? [UIColor colorWithRed:0.97 green:0.86 blue:0.48 alpha:1.0]
            : [UIColor colorWithWhite:1.0 alpha:0.82];
        button.layer.borderColor = (active
            ? [UIColor colorWithWhite:1.0 alpha:0.92]
            : [UIColor colorWithWhite:1.0 alpha:0.72]).CGColor;
        button.transform = active ? CGAffineTransformMakeScale(1.05, 1.05) : CGAffineTransformIdentity;
    }
    [self refreshSizePreview];
}

- (void)refreshStickerEditButtons {
    BOOL enabled = [self.canvasView hasSelectedSticker];
    self.frontStickerButton.enabled = enabled;
    self.deleteStickerButton.enabled = enabled;
    self.frontStickerButton.alpha = enabled ? 1.0 : 0.55;
    self.deleteStickerButton.alpha = enabled ? 1.0 : 0.55;
    self.frontStickerButton.backgroundColor = enabled
        ? [UIColor colorWithWhite:1.0 alpha:0.82]
        : [UIColor colorWithWhite:1.0 alpha:0.62];
    self.deleteStickerButton.backgroundColor = enabled
        ? [UIColor colorWithWhite:1.0 alpha:0.82]
        : [UIColor colorWithWhite:1.0 alpha:0.62];
}

- (void)refreshActionButtons {
    self.undoButton.enabled = [self.canvasView canUndo];
    self.redoButton.enabled = [self.canvasView canRedo];
    self.saveButton.enabled = [self.canvasView hasVisibleContent];

    self.undoButton.alpha = self.undoButton.enabled ? 1.0 : 0.55;
    self.redoButton.alpha = self.redoButton.enabled ? 1.0 : 0.55;
    self.saveButton.alpha = self.saveButton.enabled ? 1.0 : 0.6;
    self.undoButton.backgroundColor = self.undoButton.enabled
        ? [UIColor colorWithWhite:1.0 alpha:0.76]
        : [UIColor colorWithWhite:1.0 alpha:0.62];
    self.redoButton.backgroundColor = self.redoButton.enabled
        ? [UIColor colorWithWhite:1.0 alpha:0.76]
        : [UIColor colorWithWhite:1.0 alpha:0.62];
    self.saveButton.backgroundColor = self.saveButton.enabled
        ? [UIColor colorWithRed:0.54 green:0.80 blue:0.98 alpha:1.0]
        : [UIColor colorWithWhite:1.0 alpha:0.72];
    self.saveButton.tintColor = self.saveButton.enabled
        ? [UIColor colorWithRed:0.19 green:0.26 blue:0.33 alpha:1.0]
        : [UIColor colorWithRed:0.55 green:0.60 blue:0.67 alpha:0.7];
}

- (void)registerPressFeedbackForControl:(UIControl *)control {
    [control addTarget:self action:@selector(handleControlPressDown:) forControlEvents:UIControlEventTouchDown];
    [control addTarget:self action:@selector(handleControlPressDown:) forControlEvents:UIControlEventTouchDragEnter];
    [control addTarget:self action:@selector(handleControlPressRelease:) forControlEvents:UIControlEventTouchUpInside];
    [control addTarget:self action:@selector(handleControlPressRelease:) forControlEvents:UIControlEventTouchUpOutside];
    [control addTarget:self action:@selector(handleControlPressRelease:) forControlEvents:UIControlEventTouchCancel];
    [control addTarget:self action:@selector(handleControlPressRelease:) forControlEvents:UIControlEventTouchDragExit];
}

- (void)handleControlPressDown:(UIControl *)control {
    if (!control.enabled || objc_getAssociatedObject(control, KDPressBaseTransformKey) != nil) {
        return;
    }

    objc_setAssociatedObject(control, KDPressBaseTransformKey, [NSValue valueWithCGAffineTransform:control.transform], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(control, KDPressBaseAlphaKey, @(control.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    CGAffineTransform pressedTransform = CGAffineTransformScale(control.transform, 0.96, 0.96);
    [UIView animateWithDuration:0.16
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        control.transform = pressedTransform;
        control.alpha = MAX(0.72, control.alpha * 0.92);
    } completion:nil];
}

- (void)handleControlPressRelease:(UIControl *)control {
    NSValue *storedTransform = objc_getAssociatedObject(control, KDPressBaseTransformKey);
    NSNumber *storedAlpha = objc_getAssociatedObject(control, KDPressBaseAlphaKey);
    if (!storedTransform) {
        return;
    }

    CGAffineTransform baseTransform = storedTransform.CGAffineTransformValue;
    CGFloat baseAlpha = storedAlpha != nil ? storedAlpha.doubleValue : 1.0;
    objc_setAssociatedObject(control, KDPressBaseTransformKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(control, KDPressBaseAlphaKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.68
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        control.transform = baseTransform;
        control.alpha = baseAlpha;
    } completion:nil];
}

- (void)showSaveToastWithSuccess:(BOOL)success {
    [self.saveToastView removeFromSuperview];

    UIVisualEffectView *toast = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    toast.layer.cornerRadius = 24.0;
    toast.clipsToBounds = YES;
    toast.layer.borderWidth = 1.0;
    toast.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.72].CGColor;
    toast.alpha = 0.0;
    toast.transform = CGAffineTransformMakeScale(0.82, 0.82);
    [self.view addSubview:toast];
    self.saveToastView = toast;

    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:24.0 weight:UIImageSymbolWeightBold];
    NSString *symbolName = success ? @"checkmark" : @"exclamationmark.triangle.fill";
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbolName withConfiguration:configuration]];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = success
        ? [UIColor colorWithRed:0.23 green:0.58 blue:0.34 alpha:1.0]
        : [UIColor colorWithRed:0.83 green:0.36 blue:0.24 alpha:1.0];
    [toast.contentView addSubview:iconView];

    [NSLayoutConstraint activateConstraints:@[
        [toast.centerXAnchor constraintEqualToAnchor:self.saveButton.centerXAnchor],
        [toast.topAnchor constraintEqualToAnchor:self.saveButton.bottomAnchor constant:14.0],
        [toast.widthAnchor constraintEqualToConstant:64.0],
        [toast.heightAnchor constraintEqualToConstant:52.0],
        [iconView.centerXAnchor constraintEqualToAnchor:toast.contentView.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:toast.contentView.centerYAnchor]
    ]];

    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.72
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        toast.alpha = 1.0;
        toast.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.22
                              delay:0.85
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            toast.alpha = 0.0;
            toast.transform = CGAffineTransformMakeScale(0.92, 0.92);
        } completion:^(__unused BOOL finished) {
            if (self.saveToastView == toast) {
                [toast removeFromSuperview];
                self.saveToastView = nil;
            }
        }];
    }];
}

- (void)restoreDraftIfNeeded {
    if (self.activeSession != nil) {
        return;
    }

    UIImage *draftImage = [self.sessionStore loadDraftImage];
    if (!draftImage) {
        return;
    }

    [self.canvasView restoreCanvasWithImage:draftImage];
    [self refreshHistoryUI];
    [self refreshActionButtons];
}

- (void)scheduleDraftSave {
    [self.draftSaveTimer invalidate];
    self.draftSaveTimer = [NSTimer scheduledTimerWithTimeInterval:1.2 target:self selector:@selector(handleDraftSaveTimer:) userInfo:nil repeats:NO];
}

- (void)handleDraftSaveTimer:(NSTimer *)timer {
    if (timer != self.draftSaveTimer) {
        return;
    }
    [self saveDraftIfNeeded];
}

- (void)saveDraftIfNeeded {
    [self.draftSaveTimer invalidate];
    self.draftSaveTimer = nil;

    if (self.activeSession != nil && !self.activeSessionHasUnsavedChanges) {
        [self refreshHistoryUI];
        return;
    }

    if (![self.canvasView hasVisibleContent]) {
        [self.sessionStore clearDraftImage];
        [self refreshHistoryUI];
        return;
    }

    UIImage *snapshot = [self.canvasView snapshotImage];
    [self.sessionStore saveDraftImage:snapshot];
    [self refreshHistoryUI];
}

- (void)sceneWillResignActiveNotification:(NSNotification *)notification {
    [self saveDraftIfNeeded];
}

- (void)sceneDidEnterBackgroundNotification:(NSNotification *)notification {
    [self saveDraftIfNeeded];
}

- (void)dealloc {
    [self.draftSaveTimer invalidate];
    [self.saveToastView removeFromSuperview];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)color:(UIColor *)lhs matchesColor:(UIColor *)rhs {
    if (!lhs || !rhs) {
        return NO;
    }

    CGFloat lhsRed = 0.0;
    CGFloat lhsGreen = 0.0;
    CGFloat lhsBlue = 0.0;
    CGFloat lhsAlpha = 0.0;
    CGFloat rhsRed = 0.0;
    CGFloat rhsGreen = 0.0;
    CGFloat rhsBlue = 0.0;
    CGFloat rhsAlpha = 0.0;

    if (![lhs getRed:&lhsRed green:&lhsGreen blue:&lhsBlue alpha:&lhsAlpha]) {
        return [lhs isEqual:rhs];
    }
    if (![rhs getRed:&rhsRed green:&rhsGreen blue:&rhsBlue alpha:&rhsAlpha]) {
        return [lhs isEqual:rhs];
    }

    CGFloat tolerance = 0.01;
    return fabs(lhsRed - rhsRed) < tolerance &&
        fabs(lhsGreen - rhsGreen) < tolerance &&
        fabs(lhsBlue - rhsBlue) < tolerance &&
        fabs(lhsAlpha - rhsAlpha) < tolerance;
}

@end
