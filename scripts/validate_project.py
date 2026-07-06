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


def localization_keys(path):
    """Return the set of localization keys declared in a .strings file (lines like "key" =)."""
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8")
    return set(re.findall(r'^\s*"([^"]+)"\s*=', text, re.M))


def localization_checks(zh_localizable, en_localizable, zh_info_plist, en_info_plist, l10n_entry, pbx_text):
    checks = []
    # T025: localization resources exist for both the default language (zh-Hans) and English.
    checks.append(ok("zh-Hans Localizable.strings exists") if zh_localizable.exists() else fail("zh-Hans Localizable.strings is missing"))
    checks.append(ok("en Localizable.strings exists") if en_localizable.exists() else fail("en Localizable.strings is missing"))
    checks.append(ok("zh-Hans InfoPlist.strings exists") if zh_info_plist.exists() else fail("zh-Hans InfoPlist.strings is missing"))
    checks.append(ok("en InfoPlist.strings exists") if en_info_plist.exists() else fail("en InfoPlist.strings is missing"))
    checks.append(ok("KCLocalizedStrings entry exists") if l10n_entry.exists() else fail("KCLocalizedStrings entry is missing"))

    zh_keys = localization_keys(zh_localizable)
    en_keys = localization_keys(en_localizable)
    if zh_keys is not None:
        checks.append(ok("zh-Hans Localizable.strings declares keys") if zh_keys else fail("zh-Hans Localizable.strings declares no keys"))
    if en_keys is not None:
        checks.append(ok("en Localizable.strings declares keys") if en_keys else fail("en Localizable.strings declares no keys"))
    if zh_keys is not None and en_keys is not None:
        only_zh = sorted(zh_keys - en_keys)
        only_en = sorted(en_keys - zh_keys)
        checks.append(ok("zh-Hans and en Localizable.strings keys are aligned")
                      if not only_zh and not only_en
                      else fail("Localizable.strings keys misaligned \u2014 only zh-Hans: %s; only en: %s" % (only_zh[:6], only_en[:6])))

    # The Swift UI entry must route through NSLocalizedString rather than hardcoding values.
    if l10n_entry.exists():
        entry_text = l10n_entry.read_text(encoding="utf-8")
        checks.append(require_text(entry_text, "NSLocalizedString", "Localization entry routes through NSLocalizedString"))

    # InfoPlist.strings must localize the photo permission keys in both languages.
    for locale_label, info_path in [("zh-Hans", zh_info_plist), ("en", en_info_plist)]:
        if info_path.exists():
            info_text = info_path.read_text(encoding="utf-8")
            checks.append(require_text(info_text, "NSPhotoLibraryUsageDescription", f"{locale_label} InfoPlist.strings localizes the photo import permission"))
            checks.append(require_text(info_text, "NSPhotoLibraryAddUsageDescription", f"{locale_label} InfoPlist.strings localizes the photo save permission"))

    # Project wiring: development region is Chinese (default language), both locales are known,
    # and the string catalogs are wired into the Resources build phase as variant groups.
    checks.append(require_text(pbx_text, "developmentRegion = zh-Hans", "Project development region is zh-Hans (Chinese is the default language)"))
    checks.append(require_text(pbx_text, "PBXVariantGroup", "Localization resources use variant groups"))
    checks.append(require_text(pbx_text, "Localizable.strings in Resources", "Localizable.strings is in the Resources build phase"))
    checks.append(require_text(pbx_text, "InfoPlist.strings in Resources", "InfoPlist.strings is in the Resources build phase"))
    checks.append(require_regex(pbx_text, r"knownRegions = \([\s\S]*?zh-Hans[\s\S]*?en", "zh-Hans and en are both known regions"))
    return checks


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


def app_feature_checks(
    main_text,
    canvas_text,
    session_store_bridge_text,
    kc_session_store_text,
    kc_artwork_session_text,
    scene_text,
    header_text,
    drawing_bridge_text,
    bitmap_buffer_text,
    flood_fill_text,
    color_sampler_text,
    pressure_model_text,
    crayon_grain_text,
    sticker_constraints_text,
    history_paging_text,
    line_art_drawing_text,
    composition_root_text,
    catalog_text,
    content_picker_feature_text,
    canvas_feature_text,
    line_art_feature_text,
    device_layout_metrics_text,
    editor_ui_factory_text,
    brush_dock_feature_text,
    kc_content_picker_layout_text,
    kc_recent_color_queue_text,
    kc_sticker_category_mapping_text,
    editor_panels_feature_text,
    kc_editor_panels_collapse_state_text,
    history_feature_text,
    kc_history_thumb_status_text,
    plist,
    pbx_text,
):
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
    checks.append(ok("App locks to light appearance in Info.plist") if plist.get("UIUserInterfaceStyle") == "Light" else fail("UIUserInterfaceStyle is not locked to Light"))
    checks.append(require_text(scene_text, "window.overrideUserInterfaceStyle = .light", "Window locks to light appearance"))
    checks.append(require_text(scene_text, "mainViewController.overrideUserInterfaceStyle = .light", "Root view controller locks to light appearance"))
    checks.append(require_text(main_text, "canvasContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor)", "Canvas is pinned to the left screen edge"))
    checks.append(require_text(main_text, "canvasContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)", "Canvas is pinned to the right screen edge"))
    checks.append(require_text(main_text, "canvasContainer.topAnchor.constraint(equalTo: self.view.topAnchor)", "Canvas is pinned to the top screen edge"))
    checks.append(require_text(main_text, "canvasContainer.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)", "Canvas is pinned to the bottom screen edge"))
    checks.append(require_count_at_least(main_text, r"floatingPanel", 7, "Floating control panels are used"))
    checks.append(require_text(pbx_text, "KCEditorUIFactory.swift in Sources", "Editor UI factory is included in the app target sources"))
    checks.append(require_text(editor_ui_factory_text, "struct KCEditorUIFactory", "Common editor UI creation is extracted to KCEditorUIFactory"))
    checks.append(require_text(editor_ui_factory_text, "func floatingPanel() -> UIView", "Floating panel creation lives in KCEditorUIFactory"))
    checks.append(require_text(editor_ui_factory_text, "func iconButton(symbolName: String, accentColor: UIColor?) -> UIButton", "Top icon button creation lives in KCEditorUIFactory"))
    checks.append(require_text(editor_ui_factory_text, "func panelTitleLabel(_ title: String) -> UILabel", "Panel title label creation lives in KCEditorUIFactory"))
    checks.append(require_text(editor_ui_factory_text, "func segmentButton(title: String, active: Bool) -> UIButton", "Segment button creation lives in KCEditorUIFactory"))
    checks.append(require_text(editor_ui_factory_text, "func toolCardButton(symbolName: String, accentColor: UIColor, title: String) -> KDBrushButton", "Brush card creation lives in KCEditorUIFactory"))
    checks.append(require_text(main_text, "private var editorUIFactory: KCEditorUIFactory", "Main view controller delegates common UI creation to KCEditorUIFactory"))
    checks.append(require_text(main_text, "return self.editorUIFactory.floatingPanel()", "Floating panel helper delegates to KCEditorUIFactory"))
    checks.append(require_text(main_text, "self.registerPressFeedbackForControl(button)", "Main view controller still owns press-feedback target registration"))
    checks.append(require_text(pbx_text, "KCBrushDockFeature.swift in Sources", "Brush Dock feature is included in the app target sources"))
    checks.append(require_text(brush_dock_feature_text, "final class KCBrushDockFeature", "Brush Dock configuration is extracted to KCBrushDockFeature"))
    checks.append(require_text(brush_dock_feature_text, "struct KCBrushDockItem: Equatable", "Brush Dock item DTO is explicit and comparable"))
    checks.append(require_text(brush_dock_feature_text, "func brushItems() -> [KCBrushDockItem]", "Brush Dock item list lives in KCBrushDockFeature"))
    checks.append(require_text(brush_dock_feature_text, "func brushColor(for style: KDBrushStyle) -> UIColor", "Brush accent colors live in KCBrushDockFeature"))
    checks.append(require_text(brush_dock_feature_text, 'id: "pencil"', "Brush Dock feature declares the pencil item"))
    checks.append(require_text(brush_dock_feature_text, 'id: "pen"', "Brush Dock feature declares the pen item"))
    checks.append(require_text(brush_dock_feature_text, 'id: "crayon"', "Brush Dock feature declares the crayon item"))
    checks.append(require_text(main_text, "private(set) lazy var brushDockFeature: KCBrushDockFeature", "Main view controller owns a Brush Dock feature instance"))
    checks.append(require_text(main_text, "let brushItems = self.brushDockFeature.brushItems()", "Main view controller delegates brush dock item creation to KCBrushDockFeature"))
    checks.append(forbid_text(main_text, "let brushItems: [(id:", "Brush Dock tuple configuration is no longer hardcoded in the main view controller"))
    checks.append(forbid_text(main_text, "func brushColor(for style: KDBrushStyle) -> UIColor", "Brush accent color decisions live outside the main view controller"))
    # T023: collapse state lives in KCEditorPanelsFeature (KCEditorPanelsCollapseState in KCDomain); controller delegates.
    checks.append(require_text(editor_panels_feature_text, "var panelsCollapsed: Bool", "Toolbar collapse state is tracked in the editor panels feature"))
    checks.append(require_text(kc_editor_panels_collapse_state_text, "public struct KCEditorPanelsCollapseState", "Collapse-state decisions are extracted to KCDomain"))
    checks.append(require_text(main_text, "var collapsiblePanels", "Collapsible panel groups are tracked for hide/show"))
    checks.append(require_text(main_text, "self.collapsiblePanels = [topLeft, topRight, leftRail, rightScrollView, bottomDock]", "Collapse hides all five floating panel groups at once"))
    checks.append(require_regex(main_text, r"leftRail\.widthAnchor\.constraint\(equalToConstant: 80\.0\)", "Left tool rail uses compact iPhone-friendly width"))
    checks.append(require_regex(main_text, r"leftRail\.heightAnchor\.constraint\(equalTo: self\.view\.heightAnchor, multiplier: 0\.46\)", "Left tool rail height is viewport-relative for iPhone landscape"))
    checks.append(require_regex(main_text, r"func buildLeftRail[\s\S]*let toolScrollView = UIScrollView\(\)[\s\S]*toolScrollView\.alwaysBounceVertical = true[\s\S]*toolScrollView\.addSubview\(stack\)", "Left tool rail is vertically scrollable on compact iPhone screens"))
    checks.append(require_regex(main_text, r"func buildLeftRail[\s\S]*toolScrollView\.clipsToBounds = true[\s\S]*toolScrollView\.addSubview\(stack\)", "Left tool rail clips scrolling tools inside its capsule"))
    checks.append(require_regex(editor_ui_factory_text, r"func railToolButton[\s\S]*button\.widthAnchor\.constraint\(equalToConstant: 56\.0\)[\s\S]*button\.heightAnchor\.constraint\(equalToConstant: 56\.0\)", "Left tool buttons use compact stable dimensions"))
    checks.append(require_regex(main_text, r"func selectToolMode[\s\S]*button\.transform = \.identity", "Left tool selection does not scale buttons outside the rail"))
    checks.append(require_text(pbx_text, "KCDeviceLayoutMetrics.swift in Sources", "Device layout metrics are included in the app target sources"))
    checks.append(require_text(device_layout_metrics_text, "struct KCDeviceLayoutMetrics", "Device layout metrics are extracted from the main view controller"))
    checks.append(require_text(device_layout_metrics_text, "userInterfaceIdiom == .phone", "Device layout metrics detect compact phone layout"))
    checks.append(require_regex(device_layout_metrics_text, r"var rightPanelWidth: CGFloat[\s\S]*214\.0 : 248\.0", "Right panel uses compact iPhone width without changing iPad width"))
    checks.append(require_regex(device_layout_metrics_text, r"var rightPanelOuterWidth: CGFloat[\s\S]*238\.0 : 272\.0", "Right panel scroll container has compact iPhone width"))
    checks.append(require_regex(device_layout_metrics_text, r"var bottomDockWidth: CGFloat[\s\S]*430\.0 : 560\.0", "Bottom brush dock uses compact iPhone width without changing iPad width"))
    checks.append(require_regex(device_layout_metrics_text, r"var bottomDockHeight: CGFloat[\s\S]*74\.0 : 98\.0", "Bottom brush dock uses compact iPhone height"))
    checks.append(require_regex(device_layout_metrics_text, r"var brushCardWidth: CGFloat[\s\S]*104\.0 : 126\.0", "Bottom brush cards shrink on iPhone"))
    checks.append(require_regex(device_layout_metrics_text, r"var historyThumbSize: CGFloat[\s\S]*82\.0 : 92\.0", "History thumbnails keep compact iPhone sizing"))
    checks.append(require_text(main_text, "private var layoutMetrics: KCDeviceLayoutMetrics", "Main view controller delegates device sizing to KCDeviceLayoutMetrics"))
    checks.append(require_text(main_text, "return self.layoutMetrics.rightPanelWidth", "Right panel width is delegated to KCDeviceLayoutMetrics"))
    checks.append(require_text(main_text, "return self.layoutMetrics.bottomDockWidth", "Bottom dock width is delegated to KCDeviceLayoutMetrics"))
    checks.append(require_text(main_text, "return self.layoutMetrics.brushCardWidth", "Brush card width is delegated to KCDeviceLayoutMetrics"))
    checks.append(require_regex(main_text, r"rightScrollView\.clipsToBounds = true", "Right menu clips content inside its scroll container"))
    checks.append(require_regex(main_text, r"func paletteColorButtonSize\(\) -> CGFloat[\s\S]*return self\.isCompactPhoneLayout \? 26\.0 : self\.contentPicker\.paletteColorButtonSize", "Color swatches shrink inside compact iPhone right menu"))
    checks.append(require_regex(main_text, r"func buildBottomDock[\s\S]*scrollView\.clipsToBounds = true[\s\S]*panel\.addSubview\(scrollView\)", "Bottom brush dock clips horizontal scroll content"))
    checks.append(require_regex(main_text, r"func buildSizePanel[\s\S]*stickerScrollView\.clipsToBounds = true[\s\S]*panel\.addSubview\(stickerScrollView\)", "Right sticker row clips content inside the panel"))
    checks.append(require_text(main_text, "func buildCollapseControls", "A collapse/expand control is built"))
    checks.append(require_text(main_text, "#selector(togglePanelsCollapsed", "Collapse control is wired to a toggle action"))
    checks.append(require_text(main_text, "self.editorPanels.toggleCollapsed()", "Collapse toggle delegates to the editor panels feature"))
    checks.append(require_regex(main_text, r"func applyPanelsCollapsedAnimated[\s\S]*self\.editorPanels\.collapseState[\s\S]*panel\.isHidden = panelHidden", "Collapse applies KCDomain collapse-state decisions without touching tool state"))
    checks.append(require_text(main_text, "refreshToolStateChip", "Collapsed state shows a minimal current-tool indicator"))
    checks.append(require_text(main_text, "self.editorPanels.chipSwatchColor", "Tool-state chip swatch color is delegated to the editor panels feature"))
    # T021/T022: palettes are sourced from KCContentCatalog and owned by KCContentPickerFeature;
    # the main view controller no longer hardcodes makePalette24/36, it delegates to the feature.
    checks.append(require_text(content_picker_feature_text, "contentCatalog.palette(for: .standard)", "24-color palette is sourced from the content catalog via the content picker feature"))
    checks.append(require_text(content_picker_feature_text, "contentCatalog.palette(for: .extended)", "36-color palette is sourced from the content catalog via the content picker feature"))
    checks.append(require_text(content_picker_feature_text, "UIColor(kcHex:", "Palette KCHexColor values are bridged to UIColor in the content picker feature"))
    try:
        content_doc = json.loads(catalog_text)
    except json.JSONDecodeError as exc:
        content_doc = {}
        checks.append(fail(f"Content catalog JSON is invalid: {exc}"))
    palettes = content_doc.get("palettes", []) if isinstance(content_doc, dict) else []
    palette_by_id = {
        palette.get("id"): palette
        for palette in palettes
        if isinstance(palette, dict)
    }
    palette24 = palette_by_id.get("palette.24", {}).get("colors", [])
    palette36 = palette_by_id.get("palette.36", {}).get("colors", [])
    checks.append(ok("24-color palette is stored in the content JSON resource")
                  if len(palette24) == 24 else fail("content.json palette.24 must contain 24 colors"))
    checks.append(ok("36-color palette is stored in the content JSON resource")
                  if len(palette36) == 36 else fail("content.json palette.36 must contain 36 colors"))
    checks.append(ok("Extended palette keeps the 24-color palette as its prefix")
                  if len(palette24) == 24 and palette36[:24] == palette24
                  else fail("content.json palette.36 must start with palette.24 colors"))
    checks.append(require_text(main_text, "self.contentPicker", "Main view controller delegates content selection to KCContentPickerFeature"))
    checks.append(forbid_text(main_text, "func makePalette24", "24-color palette is no longer hardcoded in the main view controller"))
    checks.append(forbid_text(main_text, "func makePalette36", "36-color palette is no longer hardcoded in the main view controller"))
    checks.append(require_text(main_text, "UIColorPickerViewController", "Custom color picker exists"))
    checks.append(require_regex(main_text, r"UIColorPickerViewController[\s\S]*modalPresentationStyle = \.popover", "Custom color picker is presented as an iPad popover"))
    checks.append(require_text(main_text, "var customColorButton", "Custom color button is retained for popover anchoring"))
    checks.append(require_text(main_text, "popover?.sourceView = self.customColorButton ?? self.view", "Custom color picker anchors to the Custom button"))
    checks.append(require_text(main_text, "var recentColorRowStack", "Recent colors have a retained row for dynamic updates"))
    # T027: the Custom color area has a single clear entry (the Custom pill) and no tiled
    # rainbow band; the color picker stays anchored to that single entry and recent colors row remains.
    checks.append(forbid_text(main_text, "UIColor(patternImage:", "Custom color area uses a single entry (no tiled rainbow pattern)"))
    checks.append(forbid_text(main_text, "colorWheelImage", "Decorative rainbow band removed from the custom color area"))
    checks.append(forbid_text(main_text, "ringView", "Custom color area no longer renders repeated rainbow rings"))
    checks.append(require_regex(main_text, r"customButton\.bottomAnchor\.constraint\(equalTo: panel\.bottomAnchor", "Custom color area pins its single entry to the panel bottom (no rainbow band)"))
    checks.append(require_regex(main_text, r"let recentScrollView[\s\S]*showsHorizontalScrollIndicator = false[\s\S]*recentScrollView\.addSubview\(recentRow\)", "Recent colors are presented in a horizontal scroll row"))
    checks.append(require_regex(main_text, r"let recentScrollView[\s\S]*recentScrollView\.clipsToBounds = true[\s\S]*recentScrollView\.addSubview\(recentRow\)", "Recent colors are clipped inside the color panel"))
    # T022: recent-color dedupe/cap logic moved to KCDomain KCRecentColorQueue (tested); controller delegates via the feature.
    checks.append(require_text(kc_recent_color_queue_text, "defaultLimit: Int = 8", "Recent colors keep up to eight colors (KCDomain KCRecentColorQueue)"))
    checks.append(require_text(content_picker_feature_text, "KCRecentColorQueue.inserting(", "Content picker feature delegates recent-color insertion to KCDomain"))
    checks.append(require_text(canvas_text, "case picker", "Eyedropper tool mode exists"))
    checks.append(require_text(canvas_text, "sampleColorFromImage(", "Eyedropper delegates pixel sampling to Swift"))
    checks.append(require_text(drawing_bridge_text, "KCBitmapBuffer(cgImage: image)", "Eyedropper bridge rasterizes the snapshot image"))
    checks.append(require_text(drawing_bridge_text, "KCColorSampler.sample(buffer: buffer, x: x, y: y)", "Eyedropper bridge samples using the Swift sampler"))
    checks.append(forbid_text(canvas_text, "CGContextTranslateCTM", "Eyedropper avoids fragile manual context flipping"))
    # T036: drawing algorithms are accessed through an injected protocol instance.
    checks.append(require_text(drawing_bridge_text, "protocol KCDrawingEngineProviding", "Drawing engine protocol boundary exists"))
    checks.append(require_text(drawing_bridge_text, "final class KCDrawingEngineAdapter: NSObject, KCDrawingEngineProviding", "Default drawing adapter implements the protocol"))
    checks.append(require_text(composition_root_text, "self.drawingEngine = KCDrawingEngineAdapter()", "Composition Root constructs the default drawing engine adapter"))
    checks.append(require_text(main_text, "let drawingEngine: KCDrawingEngineProviding", "Main view controller stores the injected drawing engine"))
    checks.append(require_text(pbx_text, "KCLineArtFeature.swift in Sources", "Line-art feature is included in the app target sources"))
    checks.append(require_text(canvas_text, "var drawingEngine: KCDrawingEngineProviding", "Canvas view depends on the drawing engine protocol"))
    checks.append(require_text(canvas_text, "self.drawingEngine.normalizedPressure", "Drawing canvas delegates to the injected drawing engine"))
    checks.append(require_text(canvas_text, "self.drawingEngine.normalizedPressure", "Pressure normalization is bridged through DI"))
    checks.append(require_text(canvas_text, "self.drawingEngine.floodFillImage", "Flood fill is bridged through DI"))
    checks.append(require_text(canvas_text, "self.drawingEngine.sampleColorFromImage", "Color sampling is bridged through DI"))
    checks.append(require_text(canvas_text, "case pencil", "Pencil brush style exists"))
    checks.append(require_text(canvas_text, "case pen", "Pen brush style exists"))
    checks.append(require_text(canvas_text, "case crayon", "Crayon brush style exists"))
    checks.append(require_regex(canvas_text, r"\.crayon[\s\S]*drawCrayonGrain\(forPath: renderPath", "Crayon brush adds clipped grain texture"))
    checks.append(require_regex(canvas_text, r"func drawCrayonGrain[\s\S]*clipPath\.addClip\(\)", "Crayon grain texture is clipped to the stroke (UIKit drawing in Swift)"))
    checks.append(require_text(canvas_text, "self.drawingEngine.crayonGrainDashPoints(pathBounds:", "Crayon grain geometry is delegated to the injected drawing engine"))
    checks.append(require_regex(crayon_grain_text, r"public enum KCCrayonGrain", "Crayon grain engine is implemented in Swift"))
    checks.append(require_text(crayon_grain_text, "let seed = row * 37 + column * 17", "Crayon grain is deterministic (seed math in Swift)"))
    checks.append(require_text(crayon_grain_text, "let columnCount = min(220", "Crayon grain has a column safety cap"))
    checks.append(require_text(crayon_grain_text, "let rowCount = min(180", "Crayon grain has a row safety cap"))
    checks.append(require_text(main_text, "bottomDock.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)", "Bottom brush dock is centered as a floating control"))
    checks.append(require_regex(main_text, r"func buildBottomDock[\s\S]*\.pencil[\s\S]*\.pen[\s\S]*\.crayon", "Bottom dock contains brush choices only", re.S))
    checks.append(require_text(canvas_text, "case circle", "Circle eraser shape exists"))
    checks.append(require_text(canvas_text, "case cloud", "Cloud eraser shape exists"))
    checks.append(require_text(canvas_text, "case star", "Star eraser shape exists"))
    checks.append(require_text(canvas_text, "func performFloodFill", "Flood fill entry point remains in the Swift canvas"))
    checks.append(require_text(canvas_text, "self.drawingEngine.floodFillImage", "Flood fill delegates to the injected drawing engine"))
    checks.append(require_text(canvas_text, "self.drawingEngine.normalizedPressure", "Pressure normalization delegates to the injected drawing engine"))
    checks.append(require_text(canvas_text, "self.drawingEngine.sampleColorFromImage", "Color sampling delegates to the injected drawing engine"))
    checks.append(require_text(canvas_text, "final class KCDrawingCanvasView", "Canvas is a Swift class (no Objective-C bridge header needed)"))
    checks.append(require_text(drawing_bridge_text, "KCBitmapBuffer(cgImage:", "Flood fill bridge uses Swift bitmap buffer"))
    checks.append(require_text(drawing_bridge_text, "KCFloodFillEngine.fill(", "Flood fill bridge calls the Swift engine"))
    checks.append(require_text(drawing_bridge_text, "KCColorSampler.sample(", "Color sampling bridge calls the Swift sampler"))
    checks.append(require_text(drawing_bridge_text, "KCPressureModel.normalized(", "Pressure bridge calls the Swift model"))
    checks.append(require_text(drawing_bridge_text, "guard let buffer = KCBitmapBuffer(cgImage:", "Swift bridge validates CGImage input before fill"))
    checks.append(require_text(drawing_bridge_text, "guard let buffer = KCBitmapBuffer(cgImage: image),", "Swift bridge validates CGImage input before sampling"))
    checks.append(require_text(drawing_bridge_text, "return UIColor(", "Swift bridge returns UIKit color objects"))
    checks.append(require_text(bitmap_buffer_text, "public init?(cgImage: CGImage)", "Swift bitmap buffer can decode CGImage input"))
    checks.append(require_text(flood_fill_text, "public enum KCFloodFillEngine", "Flood fill engine is implemented in Swift"))
    checks.append(require_text(flood_fill_text, "guard width <= Int.max / height", "Swift flood fill guards pixel-count multiplication overflow"))
    checks.append(require_text(flood_fill_text, "var visited = [Bool]", "Swift flood fill tracks visited pixels"))
    checks.append(require_text(flood_fill_text, "var queue = [Int]()", "Swift flood fill uses an indexed queue"))
    checks.append(require_text(color_sampler_text, "public enum KCColorSampler", "Color sampler is implemented in Swift"))
    checks.append(require_text(pressure_model_text, "public enum KCPressureModel", "Pressure model is implemented in Swift"))
    # T021: built-in sticker/line-art content is externalized to the KCContentCatalog resource (content.json);
    # the main view controller consumes it via contentCatalog instead of hardcoding metadata.
    checks.append(require_count_at_least(catalog_text, r'"category": "', 8, "Built-in line-art templates live in the content catalog"))
    checks.append(require_count_at_least(catalog_text, r'"[a-z0-9.]+\.fill"|"rainbow"|"camera\.macro"', 12, "Built-in sticker symbols live in the content catalog"))
    checks.append(require_text(line_art_feature_text, "final class KCLineArtFeature", "Line-art orchestration is extracted to KCLineArtFeature"))
    checks.append(require_text(line_art_feature_text, "contentCatalog.lineArtTemplates", "Line-art order and titles are driven by the content catalog inside KCLineArtFeature"))
    checks.append(require_text(line_art_drawing_text, "public enum KCLineArtDrawing", "Line-art drawing geometry lives in KCDrawingEngine"))
    checks.append(require_text(line_art_drawing_text, "public static let supportedTemplateIds", "DrawingEngine declares supported line-art ids"))
    checks.append(require_text(drawing_bridge_text, "KCLineArtDrawing.strokes(forTemplateId:", "Drawing adapter bridges line-art geometry from DrawingEngine"))
    checks.append(require_text(line_art_feature_text, "self.drawingEngine.lineArtDrawingBlock(templateId:", "Line-art feature delegates geometry drawing to the drawing engine"))
    checks.append(require_text(line_art_feature_text, "func thumbnailImage(for item: KCLineArtItem) -> UIImage", "KCLineArtFeature renders line-art thumbnails"))
    checks.append(require_text(line_art_feature_text, "func lineArtImage(for item: KCLineArtItem, canvasSize: CGSize) -> UIImage", "KCLineArtFeature renders canvas-sized line-art images"))
    checks.append(require_text(line_art_feature_text, "struct KCLineArtItem: Equatable", "KCLineArtFeature exposes a stable line-art item DTO"))
    checks.append(require_text(main_text, "private(set) lazy var lineArtFeature: KCLineArtFeature", "Main view controller owns a line-art feature instance"))
    checks.append(require_text(main_text, "self.lineArtFeature.makeLineArtItems()", "Main view controller delegates line-art item creation to KCLineArtFeature"))
    checks.append(require_text(main_text, "self.lineArtFeature.thumbnailImage(for: item)", "Main view controller delegates line-art thumbnails to KCLineArtFeature"))
    checks.append(require_text(main_text, "self.lineArtFeature.lineArtImage(for: item, canvasSize: canvasSize)", "Main view controller delegates line-art canvas rendering to KCLineArtFeature"))
    checks.append(forbid_text(main_text, "let bunny: (CGRect) -> Void", "Line-art bunny closure moved out of the main view controller"))
    checks.append(forbid_text(main_text, "\"bunny\": bunny", "Line-art drawing map moved out of the main view controller"))
    checks.append(forbid_text(main_text, "func makeLineArtItems", "Line-art item construction is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "func thumbnailImageForLineArtItem", "Line-art thumbnail rendering is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "var lineArtStrokeScale", "Line-art stroke scale state is no longer stored in the main view controller"))
    checks.append(forbid_text(main_text, "func strokePath(_ path: UIBezierPath", "Line-art path stroking is no longer owned by the main view controller"))
    checks.append(require_text(content_picker_feature_text, "contentCatalog.stickerGroups", "Sticker groups are sourced from the content catalog via the content picker feature"))
    checks.append(require_text(content_picker_feature_text, "map(\\.title)", "Sticker categories are derived from catalog sticker groups in the content picker feature"))
    checks.append(forbid_text(main_text, 'stickerCategories = ["Animals"', "Sticker categories are no longer hardcoded in the main view controller"))
    checks.append(forbid_text(main_text, "KDLineArtItem.item(title:", "Line-art titles are no longer hardcoded via .item(title:) in the main view controller"))
    checks.append(require_text(content_picker_feature_text, "stickerSymbolsByCategory", "Built-in stickers are organized by category in the content picker feature"))
    checks.append(require_text(main_text, "func stickerCategorySymbolForCategory", "Sticker category controls use compact icon labels"))
    checks.append(require_regex(main_text, r'button\.setImage\(categoryImage, for: \.normal\)[\s\S]*button\.accessibilityLabel = KCL10n\.stickerCategoryAccessibility\(category\)', "Sticker category buttons are icon-first with localized accessibility labels"))
    # T026: tool menus/titles/hints are localized through KCL10n; the key English hardcodes
    # must not return to user-visible UI paths, and the controller must route through KCL10n.
    checks.append(require_regex(main_text, r"KCL10n\.", "Main view controller routes user-visible text through the KCL10n localization entry"))
    checks.append(forbid_text(main_text, 'panelTitleLabel("Colors")', "Colors panel title is localized (no hardcoded English)"))
    checks.append(forbid_text(main_text, 'panelTitleLabel("Stickers")', "Stickers panel title is localized (no hardcoded English)"))
    checks.append(forbid_text(main_text, 'panelTitleLabel("Eraser")', "Eraser panel title is localized (no hardcoded English)"))
    checks.append(forbid_text(main_text, 'panelTitleLabel("History")', "History panel title is localized (no hardcoded English)"))
    checks.append(forbid_text(main_text, 'panelTitleLabel("Brush / Sticker")', "Brush/Sticker panel title is localized (no hardcoded English)"))
    checks.append(forbid_text(main_text, 'setTitle("Custom"', "Custom color button title is localized (no hardcoded English)"))
    checks.append(forbid_text(main_text, 'text = "Brushes"', "Bottom dock Brushes label is localized (no hardcoded English)"))
    checks.append(forbid_text(main_text, 'text = "Draft"', "Draft label is localized (no hardcoded English)"))
    checks.append(forbid_text(main_text, 'text = "Saved"', "Saved label is localized (no hardcoded English)"))
    checks.append(forbid_text(main_text, 'brushColorForTitle', "Brush color selection matches on the brush enum, not a localized title"))
    checks.append(require_text(main_text, "func reloadStickerButtons", "Sticker panel reloads built-in stickers for the selected category"))
    checks.append(require_text(main_text, "func stickerCategoryFromButton", "Sticker category buttons resolve categories from stable identifiers"))
    checks.append(require_regex(main_text, r"func didTapStickerCategoryButton[\s\S]*self\.contentPicker\.selectStickerCategory\(category\)[\s\S]*reloadStickerButtons", "Sticker category buttons switch the visible sticker set"))
    # T022: pure content-picker logic is extracted to KCDomain (UIKit-free, tested via swift test).
    checks.append(require_text(kc_sticker_category_mapping_text, "public enum KCStickerCategoryMapping", "Sticker category mapping logic is extracted to KCDomain"))
    checks.append(require_text(kc_content_picker_layout_text, "public struct KCContentPickerLayout", "Palette grid layout math is extracted to KCDomain"))
    checks.append(require_text(kc_recent_color_queue_text, "public enum KCRecentColorQueue", "Recent-color queue logic is extracted to KCDomain"))
    checks.append(require_text(content_picker_feature_text, "KCStickerCategoryMapping.accessibilityLabel", "Content picker feature delegates sticker labels to KCDomain"))
    checks.append(require_text(content_picker_feature_text, "layout: KCContentPickerLayout", "Content picker feature is constructed with the KCDomain palette grid layout"))
    # T021: the App Composition Root assembles the bundled content catalog and injects it into the main view controller.
    checks.append(require_text(composition_root_text, "KCBundledContentCatalog", "Composition Root assembles the bundled content catalog"))
    checks.append(require_text(composition_root_text, "self.contentCatalog = KCBundledContentCatalog()", "Composition Root constructs the content catalog"))
    checks.append(require_text(composition_root_text, "KCMainViewController(", "Composition Root creates the main view controller"))
    checks.append(require_text(composition_root_text, "drawingEngine: drawingEngine", "Composition Root injects the drawing engine into the main view controller"))
    checks.append(require_text(main_text, "drawingEngine: KCDrawingEngineProviding", "Main view controller accepts the drawing engine via constructor injection"))
    checks.append(require_count_at_least(main_text, r"\.photoLibrary", 2, "Album import exists and checks availability"))
    checks.append(require_text(main_text, ".originalImage", "Album import extracts the original selected image"))
    checks.append(require_text(main_text, "func imagePickerController", "Album import validates and normalizes images before replacing the canvas"))
    checks.append(require_text(main_text, "func normalizedImage", "Album import rejects invalid image dimensions"))
    checks.append(require_text(main_text, "UIImageWriteToSavedPhotosAlbum", "Save to Photos exists"))
    checks.append(require_regex(main_text, r"func didTapSaveSession[\s\S]*hasVisibleContent[\s\S]*showSaveToastWithSuccess\(false\)", "Save action refuses empty canvas before creating history or Photos output", re.S))
    checks.append(require_regex(main_text, r"func refreshActionButtons[\s\S]*self\.canvasFeature\.actionState\(for: self\.canvasView\)[\s\S]*saveButton\.isEnabled = actionState\.canSave", "Save button is disabled for empty canvas"))
    checks.append(require_regex(main_text, r"saveButton\.tintColor = self\.saveButton\.isEnabled[\s\S]*0\.55[\s\S]*0\.60[\s\S]*0\.67", "Disabled save button icon is visually muted"))
    checks.append(require_text(session_store_bridge_text, "generateThumbnail", "History thumbnails are generated"))
    checks.append(require_text(kc_session_store_text, '"draft.png"', "Draft session persistence exists"))
    checks.append(require_text(session_store_bridge_text, "func saveDraftImage", "Draft save reports write success"))
    checks.append(require_regex(session_store_bridge_text, r"func saveImage[\s\S]*image\.pngData\(\)[\s\S]*return nil", "Session save rejects invalid images"))
    checks.append(require_regex(kc_session_store_text, r"func writeMetadataDocument[\s\S]*try data\.write\(to: metadataURL", "Session metadata persistence reports failure"))
    checks.append(require_regex(kc_session_store_text, r"previousArtwork[\s\S]*previousThumbnail[\s\S]*restore\(url: artworkURL[\s\S]*restore\(url: thumbnailURL", "Failed session saves restore previous artwork files"))
    checks.append(require_text(session_store_bridge_text, "CGSize(width: 240, height: 180)", "Thumbnail generation uses the 240×180 product size"))
    checks.append(require_text(kc_session_store_text, ".sorted { $0.modifiedAt > $1.modifiedAt }", "History sorts sessions by modified date"))
    checks.append(require_text(main_text, "deleteSession(withId:", "History delete flow exists"))
    checks.append(require_text(main_text, "var selectedHistorySession: KCSessionMetadata", "History thumbnails track the selected saved item"))
    checks.append(require_regex(main_text, r"func didTapHistoryThumb[\s\S]*let session = self\.sessions\[index\][\s\S]*self\.selectedHistorySession = session[\s\S]*self\.openSession\(session\)", "Tapping a saved thumbnail selects and opens that session"))
    checks.append(require_regex(main_text, r"func currentSelectedHistorySession[\s\S]*self\.selectedHistorySession\?\.identifier[\s\S]*self\.selectedHistorySession = nil", "Selected history sessions are validated against current saved sessions"))
    checks.append(require_regex(main_text, r"func didTapDeleteLatestSession[\s\S]*self\.sessionStore\.deleteSession\(withId: session!\.identifier\)", "Delete action prioritizes the selected saved thumbnail before falling back to current/latest"))
    checks.append(require_regex(main_text, r"let deletingActiveSession = self\.activeSession\?\.identifier == session\?\.identifier[\s\S]*self\.suppressNextDraftSave = true[\s\S]*self\.canvasView\.startBlankCanvas\(\)[\s\S]*self\.sessionStore\.clearDraft\(\)", "Deleting the open saved session clears the canvas without creating a draft"))
    checks.append(require_text(canvas_text, "coalescedTouches", "Coalesced touch drawing exists"))
    checks.append(require_text(canvas_text, "touch.type == .pencil", "Apple Pencil pressure handling exists"))
    checks.append(require_text(canvas_text, "func undoLastAction", "Undo implementation exists"))
    checks.append(require_text(canvas_text, "func redoLastAction", "Redo implementation exists"))
    checks.append(require_text(canvas_text, "maximumHistoryStates", "Undo/redo history has a bounded capacity"))
    checks.append(require_text(canvas_text, "func trimHistoryStack", "Undo/redo history stacks are trimmed"))
    checks.append(require_text(canvas_text, "func startBlankCanvas", "Canvas exposes clean blank-session reset"))
    checks.append(require_regex(canvas_text, r"func startBlankCanvas[\s\S]*resetCanvasContents\(\)[\s\S]*clearHistoryStacks\(\)", "New blank canvas clears content and undo/redo history"))
    checks.append(require_regex(canvas_text, r"func restoreCanvas[\s\S]*clearHistoryStacks\(\)", "Restoring/opening artwork clears undo/redo history"))
    checks.append(require_regex(canvas_text, r"func replaceCanvas[\s\S]*resetCanvasContents\(\)[\s\S]*clearHistoryStacks\(\)", "Imported photos start a clean canvas session"))
    checks.append(require_regex(canvas_text, r"func loadLineArtImage[\s\S]*resetCanvasContents\(\)[\s\S]*clearHistoryStacks\(\)", "Line-art templates start a clean canvas session"))
    checks.append(require_regex(canvas_text, r"func clearHistoryStacks[\s\S]*undoStates\.removeAll\(\)[\s\S]*redoStates\.removeAll\(\)", "Canvas history stacks can be fully cleared"))
    checks.append(require_regex(main_text, r"func openSession[\s\S]*self\.canvasView\.restoreCanvas\(with: image\)", "Opening saved history restores a clean canvas session", re.S))
    checks.append(require_text(main_text, "var suppressNextDraftSave", "Programmatic restore can suppress one draft save"))
    checks.append(require_text(main_text, "var activeSessionHasUnsavedChanges", "Saved sessions track unsaved edits"))
    checks.append(require_regex(main_text, r"self\.suppressNextDraftSave = true[\s\S]*self\.canvasView\.restoreCanvas\(with: image\)", "Opening saved history suppresses the restore-triggered draft save"))
    checks.append(require_regex(main_text, r"func drawingCanvasViewContentDidChange[\s\S]*if self\.suppressNextDraftSave[\s\S]*self\.suppressNextDraftSave = false[\s\S]*scheduleDraftSave", "Draft autosave ignores suppressed programmatic restore notifications"))
    checks.append(require_regex(main_text, r"func drawingCanvasViewContentDidChange[\s\S]*if self\.activeSession != nil[\s\S]*self\.activeSessionHasUnsavedChanges = true", "User edits mark opened saved sessions as dirty"))
    checks.append(require_regex(main_text, r"self\.activeSession = session[\s\S]*self\.selectedHistorySession = session[\s\S]*self\.activeSessionHasUnsavedChanges = false[\s\S]*self\.suppressNextDraftSave = true", "Opening a saved session starts clean until the next user edit"))
    checks.append(require_regex(main_text, r"self\.activeSession = savedSession[\s\S]*self\.selectedHistorySession = savedSession[\s\S]*self\.activeSessionHasUnsavedChanges = false", "Saving clears saved-session dirty state"))
    # T024: history thumb dirty/active/selected state decisions moved to KCDomain KCHistoryThumbStatus;
    # the controller applies status.borderWidth / borderColor / emphasisScale via the history feature.
    checks.append(require_text(kc_history_thumb_status_text, "self == .dirtyActive ? 3.0 : 2.0", "History thumbnail dirty-active state uses a thicker border (KCDomain)"))
    checks.append(require_regex(main_text, r"self\.history\.thumbStatus\([\s\S]*status\.borderWidth[\s\S]*status\.isEmphasized", "History thumbnails apply KCDomain thumb-status decisions via the history feature"))
    checks.append(require_text(main_text, "self.history.borderColor(for: status)", "History thumbnail border color is delegated to the history feature"))
    checks.append(require_text(history_feature_text, "func canDeleteHistory(", "Delete-history availability is decided by the history feature"))
    # T033: canvas creation and action-state decisions are now behind the App-layer
    # KCCanvasFeature boundary. The controller keeps UIKit coordination, but it should
    # no longer create the canvas view or compute undo/redo/save availability directly.
    checks.append(require_text(canvas_feature_text, "final class KCCanvasFeature", "Canvas Feature boundary exists"))
    checks.append(require_text(canvas_feature_text, "private let drawingEngine: KCDrawingEngineProviding", "Canvas Feature receives the drawing engine dependency"))
    checks.append(require_text(canvas_feature_text, "canvasView.drawingEngine = drawingEngine", "Canvas Feature injects the drawing engine into the canvas view"))
    checks.append(require_text(canvas_feature_text, "func makeCanvasView(delegate:", "Canvas Feature creates configured canvas views"))
    checks.append(require_text(canvas_feature_text, "struct ActionState", "Canvas Feature exposes a typed action state"))
    checks.append(require_text(canvas_feature_text, "canSave: canvasView.hasVisibleContent()", "Canvas Feature owns visible-content save availability"))
    checks.append(require_text(main_text, "private(set) lazy var canvasFeature: KCCanvasFeature", "Main view controller owns a Canvas Feature instance"))
    checks.append(require_text(main_text, "self.canvasFeature.makeCanvasView(delegate: self)", "Main view controller delegates canvas creation to KCCanvasFeature"))
    checks.append(require_regex(main_text, r"func refreshActionButtons[\s\S]*self\.canvasFeature\.actionState\(for: self\.canvasView\)[\s\S]*self\.saveButton\.isEnabled = actionState\.canSave", "Save button availability is delegated to KCCanvasFeature"))
    checks.append(require_regex(main_text, r"func openSession[\s\S]*preserveUnsavedActiveSessionDraftIfNeeded\(\)[\s\S]*self\.sessionStore\.clearDraft\(\)", "Opening another history item preserves dirty edits without clearing their draft"))
    checks.append(require_regex(main_text, r"func preserveUnsavedActiveSessionDraftIfNeeded[\s\S]*self\.sessionStore\.saveDraftImage\(snapshot\)[\s\S]*return true", "Dirty active saved sessions can be synchronously preserved as draft"))
    checks.append(require_regex(main_text, r"func didTapNewCanvas[\s\S]*self\.suppressNextDraftSave = true[\s\S]*self\.canvasView\.startBlankCanvas\(\)", "New canvas starts a clean blank session without creating a draft"))
    checks.append(require_regex(main_text, r"func didTapDeleteLatestSession[\s\S]*shouldDeleteDraft[\s\S]*self\.suppressNextDraftSave = true[\s\S]*self\.canvasView\.startBlankCanvas\(\)", "Deleting the active draft starts a clean blank session"))
    checks.append(require_regex(main_text, r"func saveDraftIfNeeded[\s\S]*self\.activeSession != nil && !self\.activeSessionHasUnsavedChanges[\s\S]*return[\s\S]*self\.canvasFeature\.hasVisibleContent\(self\.canvasView\)", "Draft autosave skips only unchanged saved sessions"))
    checks.append(require_text(main_text, "line-art.picker", "Line-art picker has an automation identifier"))
    checks.append(require_text(main_text, "draftSaveTimer?.invalidate()", "Draft save timer is invalidated during destructive state changes"))
    checks.append(require_regex(main_text, r"preserveUnsavedActiveSessionDraftIfNeeded\(\)[\s\S]*self\.sessionStore\.clearDraft\(\)[\s\S]*self\.canvasView\.loadLineArtImage\(lineArt\)", "Line-art loading preserves dirty edits before replacing the canvas", re.S))
    checks.append(require_text(kc_artwork_session_text, "modifiedAt: Date = Date()", "Artwork sessions get a default modified date"))
    checks.append(require_text(sticker_constraints_text, "public static let minimumScale: CGFloat = 0.48", "Sticker minimum scale is enforced (Swift)"))
    checks.append(require_text(sticker_constraints_text, "public static let maximumScale: CGFloat = 2.6", "Sticker maximum scale is enforced (Swift)"))
    checks.append(require_text(canvas_text, "self.drawingEngine.stickerTransformByClampingScale", "Sticker scale constraint is delegated to the injected drawing engine"))
    checks.append(require_text(canvas_text, "self.drawingEngine.clampStickerCenter", "Sticker center constraint is delegated to the injected drawing engine"))
    checks.append(require_text(canvas_text, "func constrainStickerView", "Sticker views are constrained after insert/restore"))
    checks.append(require_text(canvas_text, "func constrainStickerCenter", "Sticker centers are constrained to the canvas"))
    checks.append(require_regex(canvas_text, r"func handleStickerPinch[\s\S]*constrainStickerScale[\s\S]*constrainStickerCenter", "Sticker pinch keeps scale and position bounded"))
    checks.append(require_text(history_paging_text, "public struct KCHistoryPaging", "History paging Feature model is implemented in Swift"))
    checks.append(require_text(history_paging_text, "public var maxPageIndex: Int", "History paging computes the max page index"))
    checks.append(require_text(history_paging_text, "public func sessionIndex(forThumb thumbIndex: Int) -> Int", "History paging maps a thumbnail to a session index"))
    checks.append(require_text(main_text, "self.drawingEngine.historyMaxPageIndex(sessionCount:", "Controller delegates history max-page through the injected drawing engine"))
    checks.append(require_text(main_text, "self.drawingEngine.historySessionIndex(", "Controller delegates thumbnail→session mapping through the injected drawing engine"))
    checks.append(require_text(main_text, "self.drawingEngine.historyClampedPageIndex(", "Controller delegates history page clamping through the injected drawing engine"))
    return checks


def main():
    checks = []
    plist = {}

    try:
        with (ROOT / "KidCanvas" / "Info.plist").open("rb") as plist_file:
            plist = plistlib.load(plist_file)
        checks.append(ok("Info.plist parses"))
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
    checks.append(ok("iPhone and iPad device families are configured") if 'TARGETED_DEVICE_FAMILY = "1,2"' in pbx_text else fail("TARGETED_DEVICE_FAMILY is not configured for iPhone and iPad"))
    checks.append(balanced_text(pbxproj, [("braces", "{", "}")]))
    checks.append(ok("Assets.xcassets is referenced by project") if "Assets.xcassets in Resources" in pbx_text else fail("Assets.xcassets is not in Resources"))
    checks.append(ok("AppIcon build setting is enabled") if "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon" in pbx_text else fail("AppIcon build setting is missing"))
    checks.extend(app_icon_assets_exist(ROOT / "KidCanvas" / "Assets.xcassets" / "AppIcon.appiconset" / "Contents.json"))
    checks.append(project_file_references_exist(pbx_text))
    checks.append(source_files_in_build_phase(pbx_text))
    checks.append(resources_in_build_phase(pbx_text))
    checks.extend(shared_scheme_is_valid(ROOT / "KidCanvas.xcodeproj" / "xcshareddata" / "xcschemes" / "KidCanvas.xcscheme"))

    # T014 OC-zero governance: the app target is fully Swift — NO business .m
    # files may remain (legacy KDSessionStore/KDArtworkSession removed in
    # step 2; canvas/controller migrated to Swift in step 3-4).
    oc_whitelist = set()
    removed_legacy_objc = {"KDSessionStore.m", "KDArtworkSession.m", "KDMainViewController.m", "KDDrawingCanvasView.m"}
    remaining_objc = {p.name for p in (ROOT / "KidCanvas").glob("*.m") if not p.name.startswith("._")}
    unexpected_objc = remaining_objc - oc_whitelist
    still_present_legacy = removed_legacy_objc & remaining_objc
    checks.append(ok(f"App target has no Objective-C .m sources ({sorted(remaining_objc) or 'none'})")
                  if not unexpected_objc and not still_present_legacy
                  else fail("Unexpected/legacy OC files remain: " + ", ".join(sorted(unexpected_objc | still_present_legacy))))
    checks.append(ok("All legacy/business OC .m removed (KDMainViewController/KDDrawingCanvasView/KDSessionStore/KDArtworkSession)")
                  if not still_present_legacy
                  else fail("Legacy OC files still present: " + ", ".join(sorted(still_present_legacy))))
    # T015: bridging header removed entirely (app target fully Swift, no OC↔Swift boundary).
    _bridging_header = ROOT / "KidCanvas" / "KidCanvas-Bridging-Header.h"
    checks.append(ok("Bridging header removed (app target fully Swift)")
                  if not _bridging_header.exists()
                  else fail("Bridging header still present: " + _bridging_header.name))

    objc_files = [
        ROOT / "KidCanvas" / "KCMainViewController.swift",
        ROOT / "KidCanvas" / "KCDrawingCanvasView.swift",
    ]
    for path in objc_files:
        if path.exists():
            checks.append(balanced_text(path, [("braces", "{", "}"), ("parentheses", "(", ")")]))
        else:
            checks.append(fail(f"{path.relative_to(ROOT)} is missing"))

    main_text = (ROOT / "KidCanvas" / "KCMainViewController.swift").read_text(encoding="utf-8")
    canvas_text = (ROOT / "KidCanvas" / "KCDrawingCanvasView.swift").read_text(encoding="utf-8")
    session_store_bridge_text = (ROOT / "KidCanvas" / "KCSessionService.swift").read_text(encoding="utf-8")
    kc_session_store_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCSessionPersistence" / "KCSessionStore.swift").read_text(encoding="utf-8")
    kc_artwork_session_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCArtworkSession.swift").read_text(encoding="utf-8")
    scene_text = (ROOT / "KidCanvas" / "SceneDelegate.swift").read_text(encoding="utf-8")
    header_text = (ROOT / "KidCanvas" / "KCDrawingCanvasView.swift").read_text(encoding="utf-8")
    drawing_bridge_text = (ROOT / "KidCanvas" / "KCDrawingEngineAdapter.swift").read_text(encoding="utf-8")
    bitmap_buffer_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCBitmapBuffer.swift").read_text(encoding="utf-8")
    flood_fill_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCFloodFillEngine.swift").read_text(encoding="utf-8")
    color_sampler_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCColorSampler.swift").read_text(encoding="utf-8")
    pressure_model_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCPressureModel.swift").read_text(encoding="utf-8")
    crayon_grain_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCCrayonGrain.swift").read_text(encoding="utf-8")
    sticker_constraints_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCStickerConstraints.swift").read_text(encoding="utf-8")
    history_paging_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCHistoryPaging.swift").read_text(encoding="utf-8")
    line_art_drawing_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCLineArtDrawing.swift").read_text(encoding="utf-8")
    composition_root_text = (ROOT / "KidCanvas" / "KCAppCompositionRoot.swift").read_text(encoding="utf-8")
    catalog_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCContentCatalog" / "Resources" / "content.json").read_text(encoding="utf-8")
    content_picker_feature_text = (ROOT / "KidCanvas" / "KCContentPickerFeature.swift").read_text(encoding="utf-8")
    canvas_feature_text = (ROOT / "KidCanvas" / "KCCanvasFeature.swift").read_text(encoding="utf-8")
    line_art_feature_text = (ROOT / "KidCanvas" / "KCLineArtFeature.swift").read_text(encoding="utf-8")
    device_layout_metrics_text = (ROOT / "KidCanvas" / "KCDeviceLayoutMetrics.swift").read_text(encoding="utf-8")
    editor_ui_factory_text = (ROOT / "KidCanvas" / "KCEditorUIFactory.swift").read_text(encoding="utf-8")
    brush_dock_feature_text = (ROOT / "KidCanvas" / "KCBrushDockFeature.swift").read_text(encoding="utf-8")
    kc_content_picker_layout_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCContentPickerLayout.swift").read_text(encoding="utf-8")
    kc_recent_color_queue_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCRecentColorQueue.swift").read_text(encoding="utf-8")
    kc_sticker_category_mapping_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCStickerCategoryMapping.swift").read_text(encoding="utf-8")
    editor_panels_feature_text = (ROOT / "KidCanvas" / "KCEditorPanelsFeature.swift").read_text(encoding="utf-8")
    kc_editor_panels_collapse_state_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCEditorPanelsCollapseState.swift").read_text(encoding="utf-8")
    history_feature_text = (ROOT / "KidCanvas" / "KCHistoryFeature.swift").read_text(encoding="utf-8")
    kc_history_thumb_status_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCHistoryThumbStatus.swift").read_text(encoding="utf-8")
    preview_text = (ROOT / "docs" / "product" / "mockups" / "ui-preview.html").read_text(encoding="utf-8")
    checks.extend(app_feature_checks(
        main_text,
        canvas_text,
        session_store_bridge_text,
        kc_session_store_text,
        kc_artwork_session_text,
        scene_text,
        header_text,
        drawing_bridge_text,
        bitmap_buffer_text,
        flood_fill_text,
        color_sampler_text,
        pressure_model_text,
        crayon_grain_text,
        sticker_constraints_text,
        history_paging_text,
        line_art_drawing_text,
        composition_root_text,
        catalog_text,
        content_picker_feature_text,
        canvas_feature_text,
        line_art_feature_text,
        device_layout_metrics_text,
        editor_ui_factory_text,
        brush_dock_feature_text,
        kc_content_picker_layout_text,
        kc_recent_color_queue_text,
        kc_sticker_category_mapping_text,
        editor_panels_feature_text,
        kc_editor_panels_collapse_state_text,
        history_feature_text,
        kc_history_thumb_status_text,
        plist,
        pbx_text,
    ))
    checks.extend(preview_checks(preview_text))

    checks.extend(localization_checks(
        ROOT / "KidCanvas" / "zh-Hans.lproj" / "Localizable.strings",
        ROOT / "KidCanvas" / "en.lproj" / "Localizable.strings",
        ROOT / "KidCanvas" / "zh-Hans.lproj" / "InfoPlist.strings",
        ROOT / "KidCanvas" / "en.lproj" / "InfoPlist.strings",
        ROOT / "KidCanvas" / "KCLocalizedStrings.swift",
        pbx_text,
    ))

    if all(checks):
        print("Validation passed.")
        return 0

    print("Validation failed.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
