import json
import plistlib
import re
import sys
from pathlib import Path
import struct
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]


def fail(message):
    print(f"FAIL: {message}")
    return False


def ok(message):
    print(f"OK: {message}")
    return True


def balanced_text(path, pairs):
    text = path.read_text(encoding="utf-8")
    for label, open_char, close_char in pairs:
        open_count = text.count(open_char)
        close_count = text.count(close_char)
        if open_count != close_count:
            return fail(f"{path.relative_to(ROOT)} has unbalanced {label}: {open_count}/{close_count}")
    return ok(f"{path.relative_to(ROOT)} structure is balanced")


def no_chinese_text(paths):
    pattern = re.compile(r"[\u4e00-\u9fff]")
    offenders = []
    for path in paths:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        if pattern.search(text):
            offenders.append(path.relative_to(ROOT).as_posix())
    if offenders:
        return fail("Chinese characters found in UI/source files: " + ", ".join(offenders))
    return ok("No Chinese characters in app UI/source files")


def preview_checks(preview_text):
    checks = []
    checks.append(require_text(preview_text, 'class="canvas"', "Preview includes a full-screen canvas layer"))
    checks.append(require_count_at_least(preview_text, r'class="[^"]*float-panel', 7, "Preview includes floating controls"))
    checks.append(require_count_at_least(preview_text, r'class="[^"]*brush-card', 3, "Preview bottom dock shows brush cards"))
    checks.append(require_count_at_least(preview_text, r'class="[^"]*brush-tip', 3, "Preview brush cards show colored tips"))
    checks.append(require_count_at_least(preview_text, r'class="[^"]*color-dot', 12, "Preview color panel shows visible color dots"))
    checks.append(require_count_at_least(preview_text, r'class="[^"]*sticker-cat', 4, "Preview sticker panel shows category icons"))
    checks.append(require_count_at_least(preview_text, r'class="[^"]*sticker-pill', 4, "Preview sticker panel shows stickers for the active category"))
    return checks


def project_file_references_exist(pbx_text):
    missing = []
    for match in re.finditer(r"/\* ([^*]+) \*/ = \{isa = PBXFileReference; [^;]+; path = ([^;]+); sourceTree = \"?<group>\"?;", pbx_text):
        display_name = match.group(1)
        path_value = match.group(2).strip('"')
        if display_name.endswith(".app"):
            continue
        expected_path = ROOT / "KidCanvas" / path_value
        if not expected_path.exists():
            missing.append(path_value)
    if missing:
        return fail("Project references missing files: " + ", ".join(sorted(missing)))
    return ok("Project file references exist")


def source_files_in_build_phase(pbx_text):
    sources_match = re.search(r"/\* Begin PBXSourcesBuildPhase section \*/(?P<section>.*?)/\* End PBXSourcesBuildPhase section \*/", pbx_text, re.S)
    if not sources_match:
        return fail("Sources build phase not found")
    sources_section = sources_match.group("section")
    built_sources = set(re.findall(r"/\* ([^*]+\.m) in Sources \*/", sources_section))
    source_files = {path.name for path in (ROOT / "KidCanvas").glob("*.m")}
    missing = sorted(source_files - built_sources)
    if missing:
        return fail("Objective-C source files missing from build phase: " + ", ".join(missing))
    return ok("All Objective-C source files are in Sources build phase")


def resources_in_build_phase(pbx_text):
    resources_match = re.search(r"/\* Begin PBXResourcesBuildPhase section \*/(?P<section>.*?)/\* End PBXResourcesBuildPhase section \*/", pbx_text, re.S)
    if not resources_match:
        return fail("Resources build phase not found")
    resources_section = resources_match.group("section")
    if "Assets.xcassets in Resources" not in resources_section:
        return fail("Assets.xcassets missing from Resources build phase")
    return ok("Resources build phase includes asset catalog")


def shared_scheme_is_valid(scheme_path):
    checks = []
    if not scheme_path.exists():
        return [fail("Shared Xcode scheme is missing")]
    try:
        root = ET.parse(scheme_path).getroot()
    except Exception as exc:
        return [fail(f"Shared Xcode scheme parse failed: {exc}")]

    references = root.findall(".//BuildableReference")
    has_target = any(
        reference.get("BlueprintIdentifier") == "A10000410000000000000001" and
        reference.get("BlueprintName") == "KidCanvas" and
        reference.get("BuildableName") == "KidCanvas.app"
        for reference in references
    )
    checks.append(ok("Shared Xcode scheme references KidCanvas target") if has_target else fail("Shared Xcode scheme does not reference KidCanvas target"))
    checks.append(ok("Shared Xcode scheme has build action") if root.find("BuildAction") is not None else fail("Shared Xcode scheme is missing BuildAction"))
    checks.append(ok("Shared Xcode scheme has launch action") if root.find("LaunchAction") is not None else fail("Shared Xcode scheme is missing LaunchAction"))
    checks.append(ok("Shared Xcode scheme has archive action") if root.find("ArchiveAction") is not None else fail("Shared Xcode scheme is missing ArchiveAction"))
    return checks


def app_icon_assets_exist(contents_path):
    try:
        contents = json.loads(contents_path.read_text(encoding="utf-8"))
    except Exception as exc:
        return [fail(f"{contents_path.relative_to(ROOT)} parse failed: {exc}")]

    checks = []
    missing = []
    incomplete = []
    wrong_size = []
    alpha_icons = []
    for image in contents.get("images", []):
        filename = image.get("filename")
        if not filename:
            incomplete.append(f"{image.get('idiom')} {image.get('size')} @{image.get('scale')}")
            continue
        image_path = contents_path.parent / filename
        if not image_path.exists():
            missing.append(filename)
            continue
        expected_px = int(round(float(image.get("size", "0x0").split("x")[0]) * float(image.get("scale", "1x").rstrip("x"))))
        actual_size = png_size(image_path)
        if actual_size != (expected_px, expected_px):
            wrong_size.append(f"{filename}: {actual_size[0]}x{actual_size[1]} expected {expected_px}x{expected_px}")
        if png_color_type(image_path) in {4, 6}:
            alpha_icons.append(filename)

    checks.append(ok("AppIcon entries include filenames") if not incomplete else fail("AppIcon entries missing filenames: " + ", ".join(incomplete)))
    checks.append(ok("AppIcon PNG files exist") if not missing else fail("AppIcon PNG files missing: " + ", ".join(missing)))
    checks.append(ok("AppIcon PNG dimensions match Contents.json") if not wrong_size else fail("AppIcon PNG size mismatch: " + ", ".join(wrong_size)))
    checks.append(ok("AppIcon PNG files do not include alpha channels") if not alpha_icons else fail("AppIcon PNG files include alpha channels: " + ", ".join(alpha_icons)))
    checks.append(ok("AppIcon includes iOS marketing icon") if any(image.get("idiom") == "ios-marketing" and image.get("filename") for image in contents.get("images", [])) else fail("AppIcon marketing image is missing"))
    return checks


def png_size(path):
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        return (-1, -1)
    return struct.unpack(">II", header[16:24])


def png_color_type(path):
    with path.open("rb") as handle:
        header = handle.read(26)
    if len(header) < 26 or header[:8] != b"\x89PNG\r\n\x1a\n":
        return -1
    return header[25]


def require_text(text, needle, message):
    if needle not in text:
        return fail(message)
    return ok(message)


def require_regex(text, pattern, message, flags=0):
    if not re.search(pattern, text, flags):
        return fail(message)
    return ok(message)


def require_count_at_least(text, pattern, minimum, message, flags=0):
    count = len(re.findall(pattern, text, flags))
    if count < minimum:
        return fail(f"{message}: found {count}, expected at least {minimum}")
    return ok(f"{message}: found {count}")


def forbid_text(text, needle, message):
    if needle in text:
        return fail(message)
    return ok(message)


def app_feature_checks(main_text, canvas_text, store_text, session_text, scene_text, header_text, store_header_text, plist, pbx_text):
    checks = []
    expected_bundle_keys = {
        "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
        "CFBundleDisplayName": "KidCanvas",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
    }
    for key, expected_value in expected_bundle_keys.items():
        checks.append(ok(f"{key} is configured") if plist.get(key) == expected_value else fail(f"{key} is missing or incorrect"))
    checks.append(ok("Project targets iPhone and iPad") if 'TARGETED_DEVICE_FAMILY = "1,2"' in pbx_text else fail("Project is not configured for iPhone and iPad"))
    checks.append(ok("ARC is enabled") if "CLANG_ENABLE_OBJC_ARC = YES" in pbx_text else fail("ARC is not enabled"))
    checks.append(ok("Deployment target is iOS 16") if "IPHONEOS_DEPLOYMENT_TARGET = 16.0" in pbx_text else fail("Deployment target is not iOS 16"))
    checks.append(ok("Manual Info.plist is configured") if "GENERATE_INFOPLIST_FILE = NO" in pbx_text and "INFOPLIST_FILE = KidCanvas/Info.plist" in pbx_text else fail("Manual Info.plist build settings are not configured"))
    bundle_ids = re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", pbx_text)
    checks.append(ok("Bundle identifier is configured") if bundle_ids else fail("Bundle identifier is missing"))
    checks.append(ok("Bundle identifier is not the example placeholder") if bundle_ids and all("example" not in bundle_id for bundle_id in bundle_ids) else fail("Bundle identifier still uses the example placeholder"))
    checks.append(ok("Photo import permission exists") if plist.get("NSPhotoLibraryUsageDescription") else fail("Photo import permission is missing"))
    checks.append(ok("Photo save permission exists") if plist.get("NSPhotoLibraryAddUsageDescription") else fail("Photo save permission is missing"))
    checks.append(ok("Photo import permission mentions painting") if "paint" in plist.get("NSPhotoLibraryUsageDescription", "").lower() else fail("Photo import permission should explain painting use"))
    checks.append(ok("Photo save permission mentions artwork") if "artwork" in plist.get("NSPhotoLibraryAddUsageDescription", "").lower() else fail("Photo save permission should explain artwork save use"))
    checks.append(ok("App locks to light appearance in Info.plist") if plist.get("UIUserInterfaceStyle") == "Light" else fail("UIUserInterfaceStyle is not locked to Light"))
    checks.append(require_text(scene_text, "self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight", "Window locks to light appearance"))
    checks.append(require_text(scene_text, "mainViewController.overrideUserInterfaceStyle = UIUserInterfaceStyleLight", "Root view controller locks to light appearance"))
    checks.append(require_text(main_text, "[canvasContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor]", "Canvas is pinned to the left screen edge"))
    checks.append(require_text(main_text, "[canvasContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]", "Canvas is pinned to the right screen edge"))
    checks.append(require_text(main_text, "[canvasContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor]", "Canvas is pinned to the top screen edge"))
    checks.append(require_text(main_text, "[canvasContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]", "Canvas is pinned to the bottom screen edge"))
    checks.append(require_count_at_least(main_text, r"floatingPanel", 7, "Floating control panels are used"))
    checks.append(require_text(main_text, "- (NSArray<UIColor *> *)makePalette24", "24-color palette exists"))
    checks.append(require_text(main_text, "- (NSArray<UIColor *> *)makePalette36", "36-color palette exists"))
    checks.append(require_text(main_text, "UIColorPickerViewController", "Custom color picker exists"))
    checks.append(require_regex(main_text, r"UIColorPickerViewController[\s\S]*modalPresentationStyle = UIModalPresentationPopover", "Custom color picker is presented as an iPad popover"))
    checks.append(require_text(main_text, "@property (nonatomic, strong) UIButton *customColorButton;", "Custom color button is retained for popover anchoring"))
    checks.append(require_text(main_text, "popover.sourceView = self.customColorButton ?: self.view;", "Custom color picker anchors to the Custom button"))
    checks.append(require_text(main_text, "@property (nonatomic, strong) UIStackView *recentColorRowStack;", "Recent colors have a retained row for dynamic updates"))
    checks.append(require_regex(main_text, r"UIScrollView \*recentScrollView[\s\S]*recentScrollView\.showsHorizontalScrollIndicator = NO;[\s\S]*\[recentScrollView addSubview:recentRow\];", "Recent colors are presented in a horizontal scroll row"))
    checks.append(require_text(main_text, "while (self.recentColors.count > 8)", "Recent colors keep up to eight colors"))
    checks.append(require_text(canvas_text, "KDToolModePicker", "Eyedropper tool mode exists"))
    checks.append(require_regex(canvas_text, r"colorAtPoint:[\s\S]*\[image drawInRect:drawRect\]", "Eyedropper samples pixels via aligned image drawing"))
    checks.append(require_regex(canvas_text, r"colorAtPoint:[\s\S]*UIGraphicsPushContext\(context\);[\s\S]*CGRect drawRect = CGRectMake\(-point\.x, -point\.y, imageSize\.width, imageSize\.height\);[\s\S]*UIGraphicsPopContext\(\);", "Eyedropper renders into its 1x1 sampling context using point coordinates"))
    checks.append(forbid_text(canvas_text, "CGContextTranslateCTM(context, -pixelPoint.x", "Eyedropper avoids fragile manual context flipping"))
    checks.append(require_text(header_text, "KDBrushStylePencil", "Pencil brush style exists"))
    checks.append(require_text(header_text, "KDBrushStylePen", "Pen brush style exists"))
    checks.append(require_text(header_text, "KDBrushStyleCrayon", "Crayon brush style exists"))
    checks.append(require_regex(canvas_text, r"KDBrushStyleCrayon[\s\S]*drawCrayonGrainForPath:renderPath", "Crayon brush adds clipped grain texture"))
    checks.append(require_regex(canvas_text, r"- \(void\)drawCrayonGrainForPath:[\s\S]*\[clipPath addClip\];[\s\S]*NSUInteger seed = \(NSUInteger\)\(row \* 37 \+ column \* 17\);", "Crayon grain is deterministic and clipped to the stroke"))
    checks.append(require_text(canvas_text, "NSInteger columnCount = MIN(220", "Crayon grain has a column safety cap"))
    checks.append(require_text(canvas_text, "NSInteger rowCount = MIN(180", "Crayon grain has a row safety cap"))
    checks.append(require_text(main_text, "[bottomDock.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]", "Bottom brush dock is centered as a floating control"))
    checks.append(require_regex(main_text, r"- \(void\)buildBottomDock:\(UIView \*\)panel \{(?:(?!KDToolModeEraser|KDToolModeFill|KDToolModePicker|KDToolModeSticker).)*?NSArray<NSDictionary \*> \*brushItems = @\[[\s\S]*?KDBrushStylePencil[\s\S]*?KDBrushStylePen[\s\S]*?KDBrushStyleCrayon[\s\S]*?\];", "Bottom dock contains brush choices only", re.S))
    checks.append(require_text(header_text, "KDEraserShapeCircle", "Circle eraser shape exists"))
    checks.append(require_text(header_text, "KDEraserShapeCloud", "Cloud eraser shape exists"))
    checks.append(require_text(header_text, "KDEraserShapeStar", "Star eraser shape exists"))
    checks.append(require_text(canvas_text, "performFloodFillAtPoint", "Flood fill implementation exists"))
    checks.append(require_text(canvas_text, "#import <stdint.h>", "Flood fill has fixed-width integer support"))
    checks.append(require_text(canvas_text, "#import <limits.h>", "Flood fill has size limit constants available"))
    checks.append(require_text(canvas_text, "pixelCount > UINT32_MAX", "Flood fill rejects unsupported oversized bitmaps"))
    checks.append(require_text(canvas_text, "width > SIZE_MAX / height", "Flood fill guards pixel-count multiplication overflow"))
    checks.append(require_text(canvas_text, "pixelCount > SIZE_MAX / bytesPerPixel", "Flood fill guards byte-count multiplication overflow"))
    checks.append(require_regex(canvas_text, r"size_t pixelCount = width \* height;[\s\S]*unsigned char \*rawData = calloc", "Flood fill validates pixel count before raw bitmap allocation"))
    checks.append(require_text(canvas_text, "uint32_t *queue", "Flood fill queue uses compact 32-bit indices"))
    checks.append(forbid_text(canvas_text, "NSUInteger *queue", "Flood fill avoids pointer-width queue indices"))
    checks.append(require_regex(canvas_text, r"performFloodFillAtPoint:[\s\S]*UIGraphicsPushContext\(context\);[\s\S]*\[baseImage drawInRect:CGRectMake\(0, 0, width, height\)\]", "Flood fill draws bitmap using UIKit-aligned pixel dimensions"))
    checks.append(forbid_text(canvas_text, "[baseImage drawInRect:CGRectMake(0, 0, baseImage.size.width, baseImage.size.height)]", "Flood fill avoids point-sized draw rect in pixel bitmap context"))
    checks.append(forbid_text(canvas_text, "CGContextDrawImage(context, CGRectMake(0, 0, width, height), sourceImageRef)", "Flood fill avoids direct Core Graphics image drawing flip"))
    checks.append(require_count_at_least(main_text, r"itemWithTitle:@\"", 8, "Built-in line-art templates exist"))
    checks.append(require_count_at_least(main_text, r"@\"[a-z0-9.]+\.fill\"|@\"rainbow\"|@\"camera\.macro\"", 12, "Built-in sticker symbols exist"))
    checks.append(require_text(main_text, "@property (nonatomic, strong) NSDictionary<NSString *, NSArray<NSString *> *> *stickerSymbolsByCategory;", "Built-in stickers are organized by category"))
    checks.append(require_regex(main_text, r"self\.stickerCategories = @\[@\"Animals\", @\"Nature\", @\"Decor\", @\"Faces\"\];", "Sticker categories cover animals, nature, decor, and faces"))
    checks.append(require_text(main_text, "stickerCategorySymbolForCategory:", "Sticker category controls use compact icon labels"))
    checks.append(require_regex(main_text, r"\[button setImage:categoryImage forState:UIControlStateNormal\];[\s\S]*button\.accessibilityLabel = \[NSString stringWithFormat:@\"%@ Stickers\", category\];", "Sticker category buttons are icon-first while retaining accessibility labels"))
    checks.append(require_regex(main_text, r"- \(void\)reloadStickerButtons \{[\s\S]*for \(UIView \*view in \[self\.stickerRowStack\.arrangedSubviews copy\]\)[\s\S]*for \(NSString \*symbol in \[self currentStickerSymbols\]\)[\s\S]*\[self refreshStickerCategoryButtons\];", "Sticker panel reloads built-in stickers for the selected category"))
    checks.append(require_regex(main_text, r"- \(NSString \*\)stickerCategoryFromButton:\(UIButton \*\)button \{[\s\S]*NSString \*prefix = @\"sticker\.category\.\";[\s\S]*return category;[\s\S]*\}", "Sticker category buttons resolve categories from stable identifiers"))
    checks.append(require_regex(main_text, r"- \(void\)didTapStickerCategoryButton:\(UIButton \*\)button \{[\s\S]*NSString \*category = \[self stickerCategoryFromButton:button\];[\s\S]*self\.selectedStickerCategory = category;[\s\S]*\[self reloadStickerButtons\];", "Sticker category buttons switch the visible sticker set"))
    checks.append(require_text(main_text, "UIImagePickerControllerSourceTypePhotoLibrary", "Album import exists"))
    checks.append(require_text(main_text, "isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary", "Album import availability is checked"))
    uses_modern_original_key = "UIImagePickerControllerInfoKeyOriginalImage" in main_text
    uses_legacy_original_key = "UIImagePickerControllerOriginalImage" in main_text
    checks.append(
        ok("Album import extracts the original selected image")
        if uses_modern_original_key or uses_legacy_original_key
        else fail("Album import does not extract the original selected image")
    )
    checks.append(require_regex(main_text, r"- \(void\)imagePickerController:[\s\S]*UIImage \*normalizedImage = \[self normalizedImageFromImage:image\];[\s\S]*if \(normalizedImage\)[\s\S]*BOOL preservedDraft = \[self preserveUnsavedActiveSessionDraftIfNeeded\];[\s\S]*\[self\.canvasView replaceCanvasWithImage:normalizedImage\];[\s\S]*else \{[\s\S]*\[self showSaveToastWithSuccess:NO\];", "Album import validates and normalizes images before replacing the canvas"))
    checks.append(require_regex(main_text, r"- \(UIImage \*\)normalizedImageFromImage:\(UIImage \*\)image \{[\s\S]*!image \|\| image\.size\.width <= 0\.0 \|\| image\.size\.height <= 0\.0[\s\S]*return nil;[\s\S]*targetSize\.width <= 0\.0 \|\| targetSize\.height <= 0\.0[\s\S]*return nil;", "Album import rejects invalid image dimensions"))
    checks.append(require_text(main_text, "UIImageWriteToSavedPhotosAlbum", "Save to Photos exists"))
    checks.append(require_regex(main_text, r"- \(void\)didTapSaveSession \{[\s\S]*if \(!\[self\.canvasView hasVisibleContent\]\) \{[\s\S]*\[self showSaveToastWithSuccess:NO\];[\s\S]*return;[\s\S]*UIImage \*snapshot", "Save action refuses empty canvas before creating history or Photos output"))
    checks.append(require_regex(main_text, r"- \(void\)refreshActionButtons \{[\s\S]*self\.saveButton\.enabled = \[self\.canvasView hasVisibleContent\];", "Save button is disabled for empty canvas"))
    checks.append(require_regex(main_text, r"self\.saveButton\.tintColor = self\.saveButton\.enabled[\s\S]*0\.55 green:0\.60 blue:0\.67 alpha:0\.7", "Disabled save button icon is visually muted"))
    checks.append(require_text(store_text, "thumbnailImageFromImage", "History thumbnails are generated"))
    checks.append(require_text(store_text, "draft.png", "Draft session persistence exists"))
    checks.append(require_text(store_header_text, "- (BOOL)saveDraftImage:(UIImage *)image;", "Draft save reports write success"))
    checks.append(require_regex(store_text, r"- \(KDArtworkSession \*\)saveImage:[\s\S]*if \(!\[self isValidImage:image\]\)[\s\S]*return nil;", "Session save rejects invalid images"))
    checks.append(require_regex(store_text, r"- \(BOOL\)persistSessions:[\s\S]*return \[data writeToURL:self\.metadataURL atomically:YES\];[\s\S]*return NO;", "Session metadata persistence reports failure"))
    checks.append(require_regex(store_text, r"previousArtworkData[\s\S]*previousThumbnailData[\s\S]*restoreFileAtURL:artworkURL[\s\S]*restoreFileAtURL:thumbnailURL", "Failed session saves restore previous artwork files"))
    checks.append(require_regex(store_text, r"- \(UIImage \*\)thumbnailImageFromImage:[\s\S]*if \(!\[self isValidImage:image\]\)[\s\S]*return nil;", "Thumbnail generation rejects invalid images"))
    checks.append(require_text(store_text, "[NSDate distantPast]", "History sorting tolerates missing modified dates"))
    checks.append(require_text(main_text, "deleteSession:", "History delete flow exists"))
    checks.append(require_text(main_text, "@property (nonatomic, strong) KDArtworkSession *selectedHistorySession;", "History thumbnails track the selected saved item"))
    checks.append(require_regex(main_text, r"- \(void\)didTapHistoryThumb:\(UIButton \*\)button \{[\s\S]*KDArtworkSession \*session = self\.sessions\[index\];[\s\S]*self\.selectedHistorySession = session;[\s\S]*\[self openSession:session\];", "Tapping a saved thumbnail selects and opens that session"))
    checks.append(require_regex(main_text, r"- \(KDArtworkSession \*\)currentSelectedHistorySession \{[\s\S]*self\.selectedHistorySession\.sessionIdentifier[\s\S]*return session;[\s\S]*self\.selectedHistorySession = nil;", "Selected history sessions are validated against current saved sessions"))
    checks.append(require_regex(main_text, r"- \(void\)didTapDeleteLatestSession \{[\s\S]*KDArtworkSession \*selectedSession = \[self currentSelectedHistorySession\];[\s\S]*KDArtworkSession \*session = shouldDeleteDraft \? nil : \(selectedSession \?: \(self\.activeSession \?: self\.sessions\.firstObject\)\);[\s\S]*\[self\.sessionStore deleteSession:session\];", "Delete action prioritizes the selected saved thumbnail before falling back to current/latest"))
    checks.append(require_regex(main_text, r"BOOL deletingActiveSession = \[self\.activeSession\.sessionIdentifier isEqualToString:session\.sessionIdentifier\];[\s\S]*if \(deletingActiveSession\) \{[\s\S]*self\.suppressNextDraftSave = YES;[\s\S]*\[self\.canvasView startBlankCanvas\];[\s\S]*\[self\.sessionStore clearDraftImage\];[\s\S]*\}", "Deleting the open saved session clears the canvas without creating a draft"))
    checks.append(require_text(canvas_text, "coalescedTouchesForTouch", "Coalesced touch drawing exists"))
    checks.append(require_text(canvas_text, "UITouchTypePencil", "Apple Pencil pressure handling exists"))
    checks.append(require_text(canvas_text, "undoLastAction", "Undo implementation exists"))
    checks.append(require_text(canvas_text, "redoLastAction", "Redo implementation exists"))
    checks.append(require_text(canvas_text, "KDMaximumHistoryStates", "Undo/redo history has a bounded capacity"))
    checks.append(require_text(canvas_text, "trimHistoryStack:", "Undo/redo history stacks are trimmed"))
    checks.append(require_text(header_text, "- (void)startBlankCanvas;", "Canvas exposes clean blank-session reset"))
    checks.append(require_regex(canvas_text, r"- \(void\)startBlankCanvas \{[\s\S]*?\[self resetCanvasContents\];[\s\S]*?\[self clearHistoryStacks\];[\s\S]*?\}", "New blank canvas clears content and undo/redo history"))
    checks.append(require_regex(canvas_text, r"- \(void\)restoreCanvasWithImage:\(UIImage \*\)image \{[\s\S]*?\[self clearHistoryStacks\];[\s\S]*?\}", "Restoring/opening artwork clears undo/redo history"))
    checks.append(require_regex(canvas_text, r"- \(void\)replaceCanvasWithImage:\(UIImage \*\)image \{[\s\S]*?\[self resetCanvasContents\];[\s\S]*?\[self clearHistoryStacks\];[\s\S]*?\}", "Imported photos start a clean canvas session"))
    checks.append(require_regex(canvas_text, r"- \(void\)loadLineArtImage:\(UIImage \*\)image \{[\s\S]*?\[self resetCanvasContents\];[\s\S]*?\[self clearHistoryStacks\];[\s\S]*?\}", "Line-art templates start a clean canvas session"))
    checks.append(require_regex(canvas_text, r"- \(void\)clearHistoryStacks \{[\s\S]*?\[self\.undoStates removeAllObjects\];[\s\S]*?\[self\.redoStates removeAllObjects\];[\s\S]*?\}", "Canvas history stacks can be fully cleared"))
    checks.append(require_regex(main_text, r"- \(void\)openSession:\(KDArtworkSession \*\)session \{(?:(?!replaceCanvasWithImage).)*\[self\.canvasView restoreCanvasWithImage:image\];", "Opening saved history restores a clean canvas session", re.S))
    checks.append(require_text(main_text, "@property (nonatomic, assign) BOOL suppressNextDraftSave;", "Programmatic restore can suppress one draft save"))
    checks.append(require_text(main_text, "@property (nonatomic, assign) BOOL activeSessionHasUnsavedChanges;", "Saved sessions track unsaved edits"))
    checks.append(require_regex(main_text, r"self\.suppressNextDraftSave = YES;\s*\[self\.canvasView restoreCanvasWithImage:image\]", "Opening saved history suppresses the restore-triggered draft save"))
    checks.append(require_regex(main_text, r"drawingCanvasViewContentDidChange:[\s\S]*if \(self\.suppressNextDraftSave\)[\s\S]*self\.suppressNextDraftSave = NO;[\s\S]*return;[\s\S]*\[self scheduleDraftSave\];", "Draft autosave ignores suppressed programmatic restore notifications"))
    checks.append(require_regex(main_text, r"drawingCanvasViewContentDidChange:[\s\S]*if \(self\.activeSession != nil\) \{[\s\S]*self\.activeSessionHasUnsavedChanges = YES;[\s\S]*\}", "User edits mark opened saved sessions as dirty"))
    checks.append(require_regex(main_text, r"self\.activeSession = session;\s*self\.selectedHistorySession = session;\s*self\.activeSessionHasUnsavedChanges = NO;[\s\S]*self\.suppressNextDraftSave = YES;", "Opening a saved session starts clean until the next user edit"))
    checks.append(require_regex(main_text, r"self\.activeSession = savedSession;\s*self\.selectedHistorySession = savedSession;\s*self\.activeSessionHasUnsavedChanges = NO;", "Saving clears saved-session dirty state"))
    checks.append(require_regex(main_text, r"BOOL isDirtyActiveSession = isActiveSession && self\.activeSessionHasUnsavedChanges;[\s\S]*Unsaved Saved Thumbnail[\s\S]*button\.layer\.borderWidth = isDirtyActiveSession \? 3\.0 : 2\.0;", "History thumbnails show unsaved edits on active saved sessions"))
    checks.append(require_regex(main_text, r"- \(void\)openSession:\(KDArtworkSession \*\)session \{[\s\S]*BOOL preservedDraft = \[self preserveUnsavedActiveSessionDraftIfNeeded\];[\s\S]*if \(!preservedDraft\) \{[\s\S]*\[self\.sessionStore clearDraftImage\];[\s\S]*\}", "Opening another history item preserves dirty edits without clearing their draft"))
    checks.append(require_regex(main_text, r"- \(BOOL\)preserveUnsavedActiveSessionDraftIfNeeded \{[\s\S]*self\.activeSession == nil \|\| !self\.activeSessionHasUnsavedChanges \|\| !\[self\.canvasView hasVisibleContent\][\s\S]*return NO;[\s\S]*\[self\.draftSaveTimer invalidate\];[\s\S]*\[self\.sessionStore saveDraftImage:snapshot\];[\s\S]*return YES;[\s\S]*\}", "Dirty active saved sessions can be synchronously preserved as draft"))
    checks.append(require_regex(main_text, r"didTapNewCanvas[\s\S]*self\.suppressNextDraftSave = YES;[\s\S]*\[self\.canvasView startBlankCanvas\];", "New canvas starts a clean blank session without creating a draft"))
    checks.append(require_regex(main_text, r"didTapDeleteLatestSession[\s\S]*shouldDeleteDraft[\s\S]*self\.suppressNextDraftSave = YES;[\s\S]*\[self\.canvasView startBlankCanvas\];", "Deleting the active draft starts a clean blank session"))
    checks.append(require_regex(main_text, r"- \(void\)saveDraftIfNeeded \{[\s\S]*if \(self\.activeSession != nil && !self\.activeSessionHasUnsavedChanges\) \{[\s\S]*return;[\s\S]*if \(!\[self\.canvasView hasVisibleContent\]\)", "Draft autosave skips only unchanged saved sessions"))
    checks.append(require_text(main_text, "line-art.picker", "Line-art picker has an automation identifier"))
    checks.append(require_text(main_text, "[self.draftSaveTimer invalidate];", "Draft save timer is invalidated during destructive state changes"))
    checks.append(require_regex(main_text, r"- \(void\)loadLineArtItem:[\s\S]*BOOL preservedDraft = \[self preserveUnsavedActiveSessionDraftIfNeeded\];[\s\S]*if \(!preservedDraft\) \{[\s\S]*\[self\.sessionStore clearDraftImage\];[\s\S]*\}[\s\S]*\[self\.canvasView loadLineArtImage:lineArt\]", "Line-art loading preserves dirty edits before replacing the canvas", re.S))
    checks.append(require_text(session_text, "_modifiedAt = [NSDate date];", "Artwork sessions get a default modified date"))
    checks.append(require_text(canvas_text, "KDStickerMinimumScale", "Sticker minimum scale is enforced"))
    checks.append(require_text(canvas_text, "KDStickerMaximumScale", "Sticker maximum scale is enforced"))
    checks.append(require_text(canvas_text, "constrainStickerView:", "Sticker views are constrained after insert/restore"))
    checks.append(require_text(canvas_text, "constrainStickerCenter:", "Sticker centers are constrained to the canvas"))
    checks.append(require_regex(canvas_text, r"handleStickerPinch:[\s\S]*constrainStickerScale:[\s\S]*constrainStickerCenter:", "Sticker pinch keeps scale and position bounded"))
    return checks


def main():
    checks = []
    plist = {}

    try:
        with (ROOT / "KidCanvas" / "Info.plist").open("rb") as plist_file:
            plist = plistlib.load(plist_file)
        checks.append(ok("Info.plist parses"))
        checks.append(ok("iPhone and iPad device families are configured") if plist.get("UIDeviceFamily") == [1, 2] else fail("UIDeviceFamily is not configured for iPhone and iPad"))
        iphone_orientations = plist.get("UISupportedInterfaceOrientations", [])
        expected = {"UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"}
        checks.append(ok("Landscape-only iPhone orientations") if set(iphone_orientations) == expected else fail("iPhone orientations are not landscape-only"))
        orientations = plist.get("UISupportedInterfaceOrientations~ipad", [])
        checks.append(ok("Landscape-only iPad orientations") if set(orientations) == expected else fail("iPad orientations are not landscape-only"))
    except Exception as exc:
        checks.append(fail(f"Info.plist parse failed: {exc}"))

    for asset_json in [
        ROOT / "KidCanvas" / "Assets.xcassets" / "Contents.json",
        ROOT / "KidCanvas" / "Assets.xcassets" / "AppIcon.appiconset" / "Contents.json",
    ]:
        try:
            json.loads(asset_json.read_text(encoding="utf-8"))
            checks.append(ok(f"{asset_json.relative_to(ROOT)} parses"))
        except Exception as exc:
            checks.append(fail(f"{asset_json.relative_to(ROOT)} parse failed: {exc}"))

    pbxproj = ROOT / "KidCanvas.xcodeproj" / "project.pbxproj"
    pbx_text = pbxproj.read_text(encoding="utf-8")
    checks.append(balanced_text(pbxproj, [("braces", "{", "}")]))
    checks.append(ok("Assets.xcassets is referenced by project") if "Assets.xcassets in Resources" in pbx_text else fail("Assets.xcassets is not in Resources"))
    checks.append(ok("AppIcon build setting is enabled") if "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon" in pbx_text else fail("AppIcon build setting is missing"))
    checks.extend(app_icon_assets_exist(ROOT / "KidCanvas" / "Assets.xcassets" / "AppIcon.appiconset" / "Contents.json"))
    checks.append(project_file_references_exist(pbx_text))
    checks.append(source_files_in_build_phase(pbx_text))
    checks.append(resources_in_build_phase(pbx_text))
    checks.extend(shared_scheme_is_valid(ROOT / "KidCanvas.xcodeproj" / "xcshareddata" / "xcschemes" / "KidCanvas.xcscheme"))

    objc_files = [
        ROOT / "KidCanvas" / "KDMainViewController.m",
        ROOT / "KidCanvas" / "KDDrawingCanvasView.m",
        ROOT / "KidCanvas" / "KDSessionStore.m",
        ROOT / "KidCanvas" / "KDArtworkSession.m",
        ROOT / "KidCanvas" / "KDSceneDelegate.m",
        ROOT / "KidCanvas" / "KDAppDelegate.m",
        ROOT / "KidCanvas" / "main.m",
    ]
    for path in objc_files:
        checks.append(balanced_text(path, [("braces", "{", "}"), ("parentheses", "(", ")")]))

    main_text = (ROOT / "KidCanvas" / "KDMainViewController.m").read_text(encoding="utf-8")
    canvas_text = (ROOT / "KidCanvas" / "KDDrawingCanvasView.m").read_text(encoding="utf-8")
    store_text = (ROOT / "KidCanvas" / "KDSessionStore.m").read_text(encoding="utf-8")
    store_header_text = (ROOT / "KidCanvas" / "KDSessionStore.h").read_text(encoding="utf-8")
    session_text = (ROOT / "KidCanvas" / "KDArtworkSession.m").read_text(encoding="utf-8")
    scene_text = (ROOT / "KidCanvas" / "KDSceneDelegate.m").read_text(encoding="utf-8")
    header_text = (ROOT / "KidCanvas" / "KDDrawingCanvasView.h").read_text(encoding="utf-8")
    preview_text = (ROOT / "docs" / "product" / "mockups" / "ui-preview.html").read_text(encoding="utf-8")
    checks.extend(app_feature_checks(main_text, canvas_text, store_text, session_text, scene_text, header_text, store_header_text, plist, pbx_text))
    checks.extend(preview_checks(preview_text))

    checks.append(no_chinese_text([
        ROOT / "KidCanvas" / "KDMainViewController.m",
        ROOT / "KidCanvas" / "KDDrawingCanvasView.m",
        ROOT / "KidCanvas" / "Info.plist",
        ROOT / "docs" / "product" / "mockups" / "ui-preview.html",
    ]))

    if all(checks):
        print("Validation passed.")
        return 0

    print("Validation failed.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
