import json
import plistlib
import re
import sys
from pathlib import Path
import struct
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT / "KidCanvas"
APP_FILE_PATHS = {
    "AppDelegate.swift": APP_ROOT / "App" / "AppDelegate.swift",
    "SceneDelegate.swift": APP_ROOT / "App" / "SceneDelegate.swift",
    "KCAppCompositionRoot.swift": APP_ROOT / "App" / "KCAppCompositionRoot.swift",
    "KCMainViewController.swift": APP_ROOT / "Features" / "Editor" / "KCMainViewController.swift",
    "KCEditorPanelsFeature.swift": APP_ROOT / "Features" / "Editor" / "KCEditorPanelsFeature.swift",
    "KCDeviceLayoutMetrics.swift": APP_ROOT / "Features" / "Editor" / "KCDeviceLayoutMetrics.swift",
    "KCEditorToolControls.swift": APP_ROOT / "Features" / "Editor" / "KCEditorToolControls.swift",
    "KCEditorColorBridge.swift": APP_ROOT / "Features" / "Editor" / "KCEditorColorBridge.swift",
    "KCMainViewController+LayoutMetrics.swift": APP_ROOT / "Features" / "Editor" / "KCMainViewController+LayoutMetrics.swift",
    "KCMainViewController+PanelCollapse.swift": APP_ROOT / "Features" / "Editor" / "KCMainViewController+PanelCollapse.swift",
    "KCMainViewController+ToolSelection.swift": APP_ROOT / "Features" / "Editor" / "KCMainViewController+ToolSelection.swift",
    "KCCanvasFeature.swift": APP_ROOT / "Features" / "Canvas" / "KCCanvasFeature.swift",
    "KCDrawingCanvasModels.swift": APP_ROOT / "Features" / "Canvas" / "KCDrawingCanvasModels.swift",
    "KCCanvasHistoryStore.swift": APP_ROOT / "Features" / "Canvas" / "KCCanvasHistoryStore.swift",
    "KCDrawingCanvasView.swift": APP_ROOT / "Features" / "Canvas" / "KCDrawingCanvasView.swift",
    "KCToolRailFeature.swift": APP_ROOT / "Features" / "Tools" / "KCToolRailFeature.swift",
    "KCBrushDockFeature.swift": APP_ROOT / "Features" / "Tools" / "KCBrushDockFeature.swift",
    "KCEraserControlsFeature.swift": APP_ROOT / "Features" / "Tools" / "KCEraserControlsFeature.swift",
    "KCBrushStickerPanelView.swift": APP_ROOT / "Features" / "Tools" / "KCBrushStickerPanelView.swift",
    "KCContentPickerFeature.swift": APP_ROOT / "Features" / "ContentPicker" / "KCContentPickerFeature.swift",
    "KCColorPalettePanelRenderer.swift": APP_ROOT / "Features" / "ContentPicker" / "KCColorPalettePanelRenderer.swift",
    "KCLineArtFeature.swift": APP_ROOT / "Features" / "LineArt" / "KCLineArtFeature.swift",
    "KCLineArtPickerViewController.swift": APP_ROOT / "Features" / "LineArt" / "KCLineArtPickerViewController.swift",
    "KCHistoryFeature.swift": APP_ROOT / "Features" / "History" / "KCHistoryFeature.swift",
    "KCDrawingEngineAdapter.swift": APP_ROOT / "Infrastructure" / "KCDrawingEngineAdapter.swift",
    "KCSessionService.swift": APP_ROOT / "Infrastructure" / "KCSessionService.swift",
    "LegacyArchiveMigrator.swift": APP_ROOT / "Infrastructure" / "LegacyArchiveMigrator.swift",
    "KCEditorUIFactory.swift": APP_ROOT / "DesignSystem" / "KCEditorUIFactory.swift",
    "KCPressFeedbackController.swift": APP_ROOT / "DesignSystem" / "KCPressFeedbackController.swift",
    "KCToastPresenter.swift": APP_ROOT / "DesignSystem" / "KCToastPresenter.swift",
    "KCLocalizedStrings.swift": APP_ROOT / "Localization" / "KCLocalizedStrings.swift",
    "Assets.xcassets": APP_ROOT / "Resources" / "Assets.xcassets",
    "Info.plist": APP_ROOT / "Resources" / "Info.plist",
}


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
        for top_toolbar_entry in [
            "static var paletteTitle: String",
            "static var newCanvasTitle: String",
            "static var undoTitle: String",
            "static var redoTitle: String",
            "static var saveSuccessToastTitle: String",
            "static var saveFailedToastTitle: String",
        ]:
            checks.append(require_text(entry_text, top_toolbar_entry, f"Localization entry exposes top toolbar text: {top_toolbar_entry}"))

    # T055: 产品侧将贴纸能力命名为“印章 / Stamp”。内部仍沿用 sticker key/id 作为稳定模型，
    # 但用户可见的工具、面板、编辑按钮、芯片和无障碍文案必须展示为印章语义。
    expected_product_strings = [
        (zh_localizable, "zh-Hans", [
            '"tool.sticker.title" = "印章";',
            '"panel.brush-sticker.title" = "画笔 / 印章";',
            '"panel.stickers.title" = "印章";',
            '"panel.sticker-edit.title" = "印章编辑";',
            '"sticker.bring-forward.title" = "印章前移";',
            '"sticker.delete.title" = "删除印章";',
            '"sticker.category.accessibility" = "%@ 印章";',
            '"sticker.symbol.default" = "印章";',
            '"chip.title.sticker" = "印章";',
        ]),
        (en_localizable, "en", [
            '"tool.sticker.title" = "Stamp";',
            '"panel.brush-sticker.title" = "Brush / Stamp";',
            '"panel.stickers.title" = "Stamps";',
            '"panel.sticker-edit.title" = "Stamp Edit";',
            '"sticker.bring-forward.title" = "Bring Stamp Forward";',
            '"sticker.delete.title" = "Delete Stamp";',
            '"sticker.category.accessibility" = "%@ Stamps";',
            '"sticker.symbol.default" = "Stamp";',
            '"chip.title.sticker" = "Stamp";',
        ]),
    ]
    for path, locale_label, expected_lines in expected_product_strings:
        if not path.exists():
            continue
        locale_text = path.read_text(encoding="utf-8")
        for expected_line in expected_lines:
            checks.append(require_text(locale_text, expected_line, f"{locale_label} sticker product text is stamp-facing: {expected_line}"))

    expected_top_toolbar_strings = [
        (zh_localizable, "zh-Hans", [
            '"top.palette.title" = "调色板";',
            '"top.new-canvas.title" = "新画布";',
            '"top.undo.title" = "撤销";',
            '"top.redo.title" = "重做";',
        ]),
        (en_localizable, "en", [
            '"top.palette.title" = "Palette";',
            '"top.new-canvas.title" = "New Canvas";',
            '"top.undo.title" = "Undo";',
            '"top.redo.title" = "Redo";',
        ]),
    ]
    for path, locale_label, expected_lines in expected_top_toolbar_strings:
        if not path.exists():
            continue
        locale_text = path.read_text(encoding="utf-8")
        for expected_line in expected_lines:
            checks.append(require_text(locale_text, expected_line, f"{locale_label} top toolbar text is localized: {expected_line}"))

    expected_save_toast_strings = [
        (zh_localizable, "zh-Hans", [
            '"toast.save.success" = "已保存";',
            '"toast.save.failed" = "无法保存";',
        ]),
        (en_localizable, "en", [
            '"toast.save.success" = "Saved";',
            '"toast.save.failed" = "Unable to Save";',
        ]),
    ]
    for path, locale_label, expected_lines in expected_save_toast_strings:
        if not path.exists():
            continue
        locale_text = path.read_text(encoding="utf-8")
        for expected_line in expected_lines:
            checks.append(require_text(locale_text, expected_line, f"{locale_label} save toast text is localized: {expected_line}"))

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
    checks.append(require_count_at_least(preview_text, r'class="[^"]*sticker-cat', 4, "Preview stamp panel shows category icons"))
    checks.append(require_count_at_least(preview_text, r'class="[^"]*sticker-pill', 4, "Preview stamp panel shows stamps for the active category"))
    return checks


def product_stamp_naming_checks():
    checks = []
    product_paths = [
        ROOT / "docs" / "product" / "prd.md",
        ROOT / "docs" / "product" / "mockups" / "main-screen-design-brief.md",
        ROOT / "docs" / "product" / "mockups" / "ui-preview.html",
        ROOT / "docs" / "product" / "mockups" / "ui-preview.svg",
    ]
    combined_product_text = ""
    for path in product_paths:
        if not path.exists():
            checks.append(fail(f"Product document exists: {path.relative_to(ROOT)}"))
            continue
        text = path.read_text(encoding="utf-8")
        combined_product_text += f"\n--- {path.relative_to(ROOT)} ---\n{text}"
        checks.append(ok(f"Product document exists: {path.relative_to(ROOT)}"))
        checks.append(forbid_text(text, "Sticker", f"{path.relative_to(ROOT)} has no user-visible Sticker wording"))
        checks.append(forbid_text(text, "Stickers", f"{path.relative_to(ROOT)} has no user-visible Stickers wording"))
        checks.append(forbid_text(text, "贴纸", f"{path.relative_to(ROOT)} has no user-visible 贴纸 wording"))

    checks.append(require_text(combined_product_text, "印章", "Product docs use the Chinese stamp product term"))
    checks.append(require_text(combined_product_text, "Stamp", "Product mockups use the English stamp product term"))
    checks.append(require_text(combined_product_text, "支持 iPhone 和 iPad", "PRD states iPhone and iPad support"))
    checks.append(require_text(combined_product_text, "横屏优先", "PRD states landscape-first orientation"))
    checks.append(forbid_text(combined_product_text, "仅支持 iOS iPad", "PRD no longer states iPad-only support"))
    checks.append(forbid_text(combined_product_text, "仅支持 iPad", "PRD no longer states iPad-only final product"))
    checks.append(forbid_text(combined_product_text, 'aria-label="sticker"', "Mockup accessibility text does not expose sticker wording"))
    checks.append(forbid_text(combined_product_text, 'data-tip="Sticker"', "Mockup tooltip text does not expose Sticker wording"))
    return checks


def delivery_acceptance_checks():
    checks = []
    checklist_path = ROOT / "docs" / "testing" / "DELIVERY_ACCEPTANCE_CHECKLIST.md"
    manual_runbook_path = ROOT / "docs" / "testing" / "MANUAL_ACCEPTANCE_RUNBOOK_2026-07-06.md"
    runtime_docs_path = ROOT / "docs" / "testing" / "RUNTIME_SMOKE_TEST.md"
    docs_index_path = ROOT / "docs" / "README.md"
    runtime_smoke_path = ROOT / "scripts" / "runtime_smoke_test.sh"
    runtime_acceptance_path = ROOT / "scripts" / "runtime_acceptance_test.sh"

    if not checklist_path.exists():
        return [fail("Delivery acceptance checklist exists")]

    checklist_text = checklist_path.read_text(encoding="utf-8")
    manual_runbook_text = manual_runbook_path.read_text(encoding="utf-8") if manual_runbook_path.exists() else ""
    runtime_docs_text = runtime_docs_path.read_text(encoding="utf-8") if runtime_docs_path.exists() else ""
    docs_index_text = docs_index_path.read_text(encoding="utf-8")
    runtime_smoke_text = runtime_smoke_path.read_text(encoding="utf-8") if runtime_smoke_path.exists() else ""
    runtime_acceptance_text = runtime_acceptance_path.read_text(encoding="utf-8") if runtime_acceptance_path.exists() else ""

    checks.append(ok("Delivery acceptance checklist exists"))
    checks.append(require_text(docs_index_text, "./testing/DELIVERY_ACCEPTANCE_CHECKLIST.md", "Docs index links the delivery acceptance checklist"))
    checks.append(ok("Manual acceptance runbook exists") if manual_runbook_path.exists() else fail("Manual acceptance runbook exists"))
    checks.append(require_text(docs_index_text, "./testing/MANUAL_ACCEPTANCE_RUNBOOK_2026-07-06.md", "Docs index links the manual acceptance runbook"))
    checks.append(require_text(checklist_text, "./MANUAL_ACCEPTANCE_RUNBOOK_2026-07-06.md", "Delivery checklist links the manual acceptance runbook"))
    checks.append(ok("Runtime acceptance script exists") if runtime_acceptance_path.exists() else fail("Runtime acceptance script exists"))
    checks.append(ok("Runtime acceptance script is executable") if runtime_acceptance_path.exists() and (runtime_acceptance_path.stat().st_mode & 0o111) else fail("Runtime acceptance script is executable"))
    checks.append(require_text(runtime_acceptance_text, "--kc-runtime-empty-save-check", "Runtime acceptance script launches the empty-save Debug probe"))
    checks.append(require_text(runtime_acceptance_text, "--kc-runtime-layout-check", "Runtime acceptance script launches the layout Debug probe"))
    checks.append(require_text(runtime_acceptance_text, "--kc-runtime-sticker-check", "Runtime acceptance script launches the sticker Debug probe"))
    checks.append(require_text(runtime_acceptance_text, "--kc-runtime-save-history-check", "Runtime acceptance script launches the save-history Debug probe"))
    checks.append(require_text(runtime_acceptance_text, "--kc-runtime-drawing-tools-check", "Runtime acceptance script launches the drawing-tools Debug probe"))
    checks.append(require_text(runtime_acceptance_text, "--kc-runtime-system-ui-check", "Runtime acceptance script launches the system-ui Debug probe"))
    checks.append(require_text(runtime_acceptance_text, "kc_runtime_acceptance_empty_save.json", "Runtime acceptance script reads the empty-save JSON result"))
    checks.append(require_text(runtime_acceptance_text, "kc_runtime_acceptance_layout.json", "Runtime acceptance script reads the layout JSON result"))
    checks.append(require_text(runtime_acceptance_text, "kc_runtime_acceptance_sticker.json", "Runtime acceptance script reads the sticker JSON result"))
    checks.append(require_text(runtime_acceptance_text, "kc_runtime_acceptance_save_history.json", "Runtime acceptance script reads the save-history JSON result"))
    checks.append(require_text(runtime_acceptance_text, "kc_runtime_acceptance_drawing_tools.json", "Runtime acceptance script reads the drawing-tools JSON result"))
    checks.append(require_text(runtime_acceptance_text, "kc_runtime_acceptance_system_ui.json", "Runtime acceptance script reads the system-ui JSON result"))
    checks.append(require_text(runtime_acceptance_text, "layout-safe-area", "Runtime acceptance script exposes the layout-safe-area probe"))
    checks.append(require_text(runtime_acceptance_text, "sticker-undo-redo", "Runtime acceptance script exposes the sticker-undo-redo probe"))
    checks.append(require_text(runtime_acceptance_text, "save-history-restore", "Runtime acceptance script exposes the save-history-restore probe"))
    checks.append(require_text(runtime_acceptance_text, "drawing-tools", "Runtime acceptance script exposes the drawing-tools probe"))
    checks.append(require_text(runtime_acceptance_text, "system-ui", "Runtime acceptance script exposes the system-ui probe"))
    checks.append(require_text(runtime_acceptance_text, "safe_path_component", "Runtime acceptance script sanitizes device/probe names for DerivedData paths"))
    checks.append(require_text(runtime_acceptance_text, "/tmp/kc-dd-acceptance-${SAFE_DEVICE_NAME}-${SAFE_PROBE_NAME}", "Runtime acceptance script uses per-device/probe DerivedData by default"))
    checks.append(require_text(runtime_acceptance_text, "result.get(\"passed\")", "Runtime acceptance script fails when the JSON result is not passing"))

    required_flows = [
        "F01 | 启动",
        "F02 | 画笔",
        "F03 | 橡皮",
        "F04 | 填色",
        "F05 | 取色",
        "F06 | 印章",
        "F07 | 颜色面板",
        "F08 | 自定义色",
        "F09 | 保存",
        "F10 | 历史",
        "F11 | 相册导入",
        "F12 | 线稿",
    ]
    for flow in required_flows:
        checks.append(require_text(checklist_text, flow, f"Delivery checklist covers core flow: {flow}"))
        checks.append(require_text(manual_runbook_text, flow, f"Manual acceptance runbook covers core flow: {flow}"))
    checks.append(require_text(checklist_text, "空画布点保存应显示“无法保存”", "Delivery checklist requires localized save-failure feedback"))
    checks.append(require_text(checklist_text, "画一笔后保存应显示“已保存”", "Delivery checklist requires localized save-success feedback"))
    checks.append(require_text(checklist_text, "相册权限弹窗", "Delivery checklist records photo permission prompt validation"))
    checks.append(require_text(manual_runbook_text, "iPhone 结果", "Manual acceptance runbook records iPhone results"))
    checks.append(require_text(manual_runbook_text, "iPad 结果", "Manual acceptance runbook records iPad results"))
    checks.append(require_text(manual_runbook_text, "系统能力专项点验", "Manual acceptance runbook includes system capability checks"))
    checks.append(require_text(manual_runbook_text, "Photos 权限弹窗", "Manual acceptance runbook checks Photos permission prompt"))
    checks.append(require_text(manual_runbook_text, "从相册导入图片", "Manual acceptance runbook checks photo import"))
    checks.append(require_text(manual_runbook_text, "保存到系统相册", "Manual acceptance runbook checks photo library save"))
    checks.append(require_text(manual_runbook_text, "系统自定义取色器", "Manual acceptance runbook checks system color picker"))
    checks.append(require_text(manual_runbook_text, "印章真实捏合/旋转", "Manual acceptance runbook checks real stamp pinch and rotation"))
    checks.append(require_text(manual_runbook_text, "缺陷记录模板", "Manual acceptance runbook includes a defect template"))
    checks.append(require_text(manual_runbook_text, "阻塞 / 非阻塞", "Manual acceptance runbook classifies defects by severity"))

    required_commands = [
        "python3 scripts/validate_project.py",
        "swift test",
        "xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build -quiet",
        "xcodebuild -project KidCanvas.xcodeproj -scheme KidCanvas -destination 'platform=iOS Simulator,name=iPad Pro 11 M4' build -quiet",
        'scripts/runtime_smoke_test.sh "iPhone 17 Pro"',
        'scripts/runtime_smoke_test.sh "iPad Pro 11 M4"',
        'scripts/runtime_acceptance_test.sh "iPhone 17 Pro"',
        'scripts/runtime_acceptance_test.sh "iPad Pro 11 M4"',
        'scripts/runtime_acceptance_test.sh "iPhone 17 Pro" layout-safe-area',
        'scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" layout-safe-area',
        'scripts/runtime_acceptance_test.sh "iPhone 17 Pro" sticker-undo-redo',
        'scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" sticker-undo-redo',
        'scripts/runtime_acceptance_test.sh "iPhone 17 Pro" save-history-restore',
        'scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" save-history-restore',
        'scripts/runtime_acceptance_test.sh "iPhone 17 Pro" drawing-tools',
        'scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" drawing-tools',
        'scripts/runtime_acceptance_test.sh "iPhone 17 Pro" system-ui',
        'scripts/runtime_acceptance_test.sh "iPad Pro 11 M4" system-ui',
        "git diff --check",
    ]
    for command in required_commands:
        checks.append(require_text(checklist_text, command, f"Delivery checklist documents required command: {command}"))

    checks.append(require_text(checklist_text, "人工触控", "Delivery checklist separates manual touch acceptance from automated checks"))
    checks.append(require_text(checklist_text, "文档同步", "Delivery checklist requires documentation sync in delivery records"))
    checks.append(require_text(runtime_docs_text, "runtime_acceptance_test.sh", "Runtime testing docs cover runtime acceptance"))
    checks.append(require_text(runtime_docs_text, "空画布保存反馈", "Runtime testing docs explain the empty-canvas save acceptance"))
    checks.append(require_text(runtime_docs_text, "/tmp/kc-dd-smoke-<设备名>", "Runtime testing docs document per-device smoke DerivedData paths"))
    checks.append(require_text(runtime_docs_text, "/tmp/kc-dd-acceptance-<设备名>-<探针名>", "Runtime testing docs document per-device/probe acceptance DerivedData paths"))
    checks.append(require_text(runtime_docs_text, "并行构建锁", "Runtime testing docs explain acceptance DerivedData parallel-build lock avoidance"))
    checks.append(require_text(runtime_docs_text, "绘画工具链路", "Runtime testing docs explain the drawing-tools acceptance probe"))
    checks.append(require_text(runtime_docs_text, "系统 UI 呈现探针", "Runtime testing docs explain the system-ui acceptance probe"))
    checks.append(require_text(runtime_smoke_text, "safe_path_component", "Runtime smoke test sanitizes device names for DerivedData paths"))
    checks.append(require_text(runtime_smoke_text, "/tmp/kc-dd-smoke-${SAFE_DEVICE_NAME}", "Runtime smoke test uses per-device DerivedData by default"))
    checks.append(require_text(runtime_smoke_text, "NORMALIZE_LANDSCAPE_SCREENSHOT", "Runtime smoke test normalizes landscape screenshot observation"))
    checks.append(require_text(runtime_smoke_text, "shot_width", "Runtime smoke test reads screenshot width"))
    checks.append(require_text(runtime_smoke_text, "shot_height", "Runtime smoke test reads screenshot height"))
    checks.append(require_text(runtime_smoke_text, "LANDSCAPE_SHOT", "Runtime smoke test writes a normalized landscape screenshot"))
    checks.append(require_text(runtime_smoke_text, "_landscape.png", "Runtime smoke test names normalized landscape screenshots"))
    return checks


def module_documentation_checks():
    checks = []
    docs_dir = ROOT / "docs" / "modules"
    required_docs = [
        "KCCommon.md",
        "KCDomain.md",
        "KCSessionPersistence.md",
        "KCContentPickerFeature.md",
        "KCEditorPanelsFeature.md",
        "KCHistoryFeature.md",
    ]
    for filename in required_docs:
        path = docs_dir / filename
        if not path.exists():
            checks.append(fail(f"Module documentation exists: {filename}"))
            continue
        text = path.read_text(encoding="utf-8")
        checks.append(ok(f"Module documentation exists: {filename}"))
        checks.append(require_text(text, "## 1. 职责", f"{filename} documents responsibilities"))
        checks.append(require_text(text, "## 2. 边界", f"{filename} documents boundaries"))
        checks.append(require_regex(text, r"## 3\. (对外 API|当前接入|对外 API / 接入路径)", f"{filename} documents API or integration path"))
        checks.append(require_text(text, "## 4. 禁止回流规则", f"{filename} documents anti-backflow rules"))

    index_path = docs_dir / "README.md"
    index_text = index_path.read_text(encoding="utf-8")
    for filename in required_docs:
        checks.append(require_text(index_text, f"./{filename}", f"Module index links {filename}"))
    checks.append(forbid_text(index_text, "待按需补充", "Module index has no pending-baseline placeholder"))
    checks.append(forbid_text(index_text, "KCCommon / KCDomain / KCSessionPersistence", "Module index no longer lists baseline docs as missing"))
    return checks


def package_dependency_map(package_text):
    target_dependencies = {}
    for match in re.finditer(r"\.(?:target|testTarget)\(\s*name:\s*\"([^\"]+)\"(?P<body>.*?)(?=\n\s*\.(?:target|testTarget)\(|\n\s*\]\n\))", package_text, re.S):
        name = match.group(1)
        body = match.group("body")
        dependencies_match = re.search(r"dependencies:\s*\[(.*?)\]", body, re.S)
        if dependencies_match:
            target_dependencies[name] = set(re.findall(r"\"([^\"]+)\"", dependencies_match.group(1)))
        else:
            target_dependencies[name] = set()
    return target_dependencies


def spm_module_governance_checks():
    checks = []
    packages_dir = ROOT / "Packages"
    package_swifts = sorted(
        path.relative_to(ROOT).as_posix()
        for path in packages_dir.rglob("Package.swift")
        if ".build" not in path.parts
    )
    expected_package = "Packages/KidCanvasModules/Package.swift"
    checks.append(ok("KidCanvasModules remains the single local SPM package")
                  if package_swifts == [expected_package]
                  else fail("Unexpected local SPM packages: " + ", ".join(package_swifts or ["none"])))

    package_path = ROOT / expected_package
    if not package_path.exists():
        checks.append(fail("KidCanvasModules Package.swift is missing"))
        return checks

    package_text = package_path.read_text(encoding="utf-8")
    checks.append(require_text(package_text, 'name: "KidCanvasModules"', "SPM package name is KidCanvasModules"))
    checks.append(require_text(package_text, ".iOS(.v16)", "SPM package keeps iOS 16 platform floor"))
    checks.append(forbid_text(package_text, ".package(", "KidCanvasModules has no external package dependencies"))

    expected_targets = {
        "KCCommon": set(),
        "KCDomain": {"KCCommon"},
        "KCDrawingEngine": {"KCCommon", "KCDomain"},
        "KCContentCatalog": {"KCCommon", "KCDomain"},
        "KCSessionPersistence": {"KCCommon", "KCDomain"},
    }
    dependencies = package_dependency_map(package_text)
    sources_dir = ROOT / "Packages" / "KidCanvasModules" / "Sources"
    tests_dir = ROOT / "Packages" / "KidCanvasModules" / "Tests"

    for target_name, allowed_dependencies in expected_targets.items():
        checks.append(ok(f"SPM source target exists: {target_name}") if (sources_dir / target_name).is_dir() else fail(f"Missing SPM source target directory: {target_name}"))
        checks.append(require_text(package_text, f'.library(name: "{target_name}"', f"SPM product exists: {target_name}"))
        checks.append(require_text(package_text, f'name: "{target_name}"', f"SPM target declared: {target_name}"))

        actual_dependencies = dependencies.get(target_name)
        if actual_dependencies is None:
            checks.append(fail(f"SPM target dependency map missing: {target_name}"))
            continue
        checks.append(ok(f"SPM dependency direction is valid: {target_name}")
                      if actual_dependencies == allowed_dependencies
                      else fail(f"Invalid dependencies for {target_name}: {sorted(actual_dependencies)} expected {sorted(allowed_dependencies)}"))

        test_target_name = f"{target_name}Tests"
        checks.append(ok(f"SPM test target exists: {test_target_name}") if (tests_dir / test_target_name).is_dir() else fail(f"Missing SPM test target directory: {test_target_name}"))
        checks.append(require_text(package_text, f'name: "{test_target_name}"', f"SPM test target declared: {test_target_name}"))
        checks.append(ok(f"SPM test target depends on source target: {test_target_name}")
                      if dependencies.get(test_target_name) == {target_name}
                      else fail(f"Invalid dependencies for {test_target_name}: {sorted(dependencies.get(test_target_name, set()))} expected {[target_name]}"))

    forbidden_foundations = {"KidCanvas", "KidCanvasApp", "KCEditorPanelsFeature", "KCCanvasFeature", "KCHistoryFeature", "KCContentPickerFeature"}
    for target_name in expected_targets:
        actual_dependencies = dependencies.get(target_name, set())
        forbidden = sorted(actual_dependencies & forbidden_foundations)
        checks.append(ok(f"Base target does not depend on App/UI Feature targets: {target_name}")
                      if not forbidden
                      else fail(f"{target_name} must not depend on App/UI Feature targets: {', '.join(forbidden)}"))

    return checks


def apple_double_checks():
    checks = []
    guarded_roots = [
        ROOT / "KidCanvas",
        ROOT / "KidCanvas.xcodeproj",
        ROOT / "Packages" / "KidCanvasModules" / "Package.swift",
        ROOT / "Packages" / "KidCanvasModules" / "Sources",
        ROOT / "Packages" / "KidCanvasModules" / "Tests",
        ROOT / "docs",
        ROOT / "scripts",
    ]
    apple_double_files = []
    for guarded_root in guarded_roots:
        if guarded_root.is_file():
            continue
        if not guarded_root.exists():
            continue
        for path in guarded_root.rglob("._*"):
            if ".git" in path.parts or ".build" in path.parts or "ai-docs" in path.parts:
                continue
            apple_double_files.append(path.relative_to(ROOT).as_posix())
    checks.append(ok("No AppleDouble metadata files in source, docs, scripts, or xcodeproj")
                  if not apple_double_files
                  else fail("AppleDouble metadata files found: " + ", ".join(sorted(apple_double_files)[:20])))
    return checks


def app_structure_checks():
    checks = []
    expected_directories = [
        APP_ROOT / "App",
        APP_ROOT / "Features" / "Editor",
        APP_ROOT / "Features" / "Canvas",
        APP_ROOT / "Features" / "Tools",
        APP_ROOT / "Features" / "ContentPicker",
        APP_ROOT / "Features" / "LineArt",
        APP_ROOT / "Features" / "History",
        APP_ROOT / "Infrastructure",
        APP_ROOT / "DesignSystem",
        APP_ROOT / "Localization",
        APP_ROOT / "Resources",
    ]
    for directory in expected_directories:
        checks.append(ok(f"App structure directory exists: {directory.relative_to(ROOT)}")
                      if directory.is_dir()
                      else fail(f"Missing App structure directory: {directory.relative_to(ROOT)}"))

    root_swift_files = sorted(path.name for path in APP_ROOT.glob("*.swift") if not path.name.startswith("._"))
    checks.append(ok("KidCanvas root no longer contains App Swift files")
                  if not root_swift_files
                  else fail("KidCanvas root still contains App Swift files: " + ", ".join(root_swift_files)))

    for file_name, path in APP_FILE_PATHS.items():
        checks.append(ok(f"App file exists at layered path: {path.relative_to(ROOT)}")
                      if path.exists()
                      else fail(f"Missing App file at layered path: {file_name} -> {path.relative_to(ROOT)}"))
    return checks


def architecture_reality_checks():
    checks = []
    docs = {
        "ARCHITECTURE_EVOLUTION_PLAN.md": (ROOT / "docs" / "architecture" / "ARCHITECTURE_EVOLUTION_PLAN.md").read_text(encoding="utf-8"),
        "TECHNICAL_ARCHITECTURE.md": (ROOT / "docs" / "architecture" / "TECHNICAL_ARCHITECTURE.md").read_text(encoding="utf-8"),
        "MODULAR_ARCHITECTURE_DESIGN.md": (ROOT / "docs" / "architecture" / "MODULAR_ARCHITECTURE_DESIGN.md").read_text(encoding="utf-8"),
    }
    combined = "\n".join(docs.values())

    required_statements = [
        "当前 App target 已无业务 Objective-C `.m` 源码",
        "当前工程已无 `KidCanvas-Bridging-Header.h`",
        "当前 SPM 落地形态是 1 个本地 package、5 个基础 library target",
        "App target 已按 App / Features / Infrastructure / DesignSystem / Localization / Resources 分层",
        "继续支持 iPhone + iPad，横屏优先",
        "禁止一个模块一个 package",
        "禁止把画布核心重写为纯 SwiftUI Canvas",
    ]
    for statement in required_statements:
        checks.append(require_text(combined, statement, f"Architecture docs state reality: {statement}"))

    stale_phrases = [
        "KDMainViewController 尚未",
        "KDDrawingCanvasView 尚未",
        "Objective-C bridge 尚未清理",
        "尚未迁移为 Swift",
    ]
    for phrase in stale_phrases:
        checks.append(forbid_text(combined, phrase, f"Architecture docs do not contain stale phrase: {phrase}"))
    return checks


def project_file_references_exist(pbx_text):
    missing = []
    for match in re.finditer(r"/\* ([^*]+) \*/ = \{isa = PBXFileReference; [^;]+; path = ([^;]+); sourceTree = \"?<group>\"?;", pbx_text):
        display_name = match.group(1)
        path_value = match.group(2).strip('"')
        if display_name.endswith(".app"):
            continue
        expected_path = ROOT / "KidCanvas" / path_value
        if not expected_path.exists() and display_name in APP_FILE_PATHS:
            expected_path = APP_FILE_PATHS[display_name]
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
    source_files = {path.name for path in APP_ROOT.rglob("*.m")}
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
    canvas_models_text,
    canvas_history_store_text,
    session_store_bridge_text,
    kc_session_store_text,
    kc_artwork_session_text,
    scene_text,
    header_text,
    drawing_bridge_text,
    bitmap_buffer_text,
    flood_fill_text,
    color_sampler_text,
    image_pixel_sampler_text,
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
    line_art_picker_text,
    device_layout_metrics_text,
    editor_ui_factory_text,
    press_feedback_text,
    toast_presenter_text,
    color_palette_renderer_text,
    brush_sticker_panel_text,
    brush_dock_feature_text,
    eraser_controls_feature_text,
    tool_rail_feature_text,
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
    checks.append(require_text(pbx_text, 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";', "Debug Swift compilation conditions keep DEBUG-only probes available"))
    checks.append(ok("Manual Info.plist is configured") if "GENERATE_INFOPLIST_FILE = NO" in pbx_text and "INFOPLIST_FILE = KidCanvas/Resources/Info.plist" in pbx_text else fail("Manual Info.plist build settings are not configured"))
    bundle_ids = re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", pbx_text)
    checks.append(ok("Bundle identifier is configured") if bundle_ids else fail("Bundle identifier is missing"))
    checks.append(ok("Bundle identifier is not the example placeholder") if bundle_ids and all("example" not in bundle_id for bundle_id in bundle_ids) else fail("Bundle identifier still uses the example placeholder"))
    checks.append(ok("Photo import permission exists") if plist.get("NSPhotoLibraryUsageDescription") else fail("Photo import permission is missing"))
    checks.append(ok("Photo save permission exists") if plist.get("NSPhotoLibraryAddUsageDescription") else fail("Photo save permission is missing"))
    checks.append(ok("App locks to light appearance in Info.plist") if plist.get("UIUserInterfaceStyle") == "Light" else fail("UIUserInterfaceStyle is not locked to Light"))
    checks.append(require_text(scene_text, "window.overrideUserInterfaceStyle = .light", "Window locks to light appearance"))
    checks.append(require_text(scene_text, "mainViewController.overrideUserInterfaceStyle = .light", "Root view controller locks to light appearance"))
    checks.append(require_text(scene_text, "requestLandscapeGeometry(for: windowScene)", "Scene startup requests landscape geometry"))
    checks.append(require_text(scene_text, "UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)", "Landscape geometry request uses iOS scene preferences"))
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
    checks.append(require_text(editor_ui_factory_text, "func collapseToggleButton(symbolName: String) -> UIButton", "Collapse toggle button creation lives in KCEditorUIFactory"))
    checks.append(require_text(editor_ui_factory_text, "func toolStateChip() -> UIView", "Collapsed tool-state chip creation lives in KCEditorUIFactory"))
    checks.append(require_text(editor_ui_factory_text, "func toolStateSwatch() -> UIView", "Collapsed tool-state swatch creation lives in KCEditorUIFactory"))
    checks.append(require_text(editor_ui_factory_text, "func toolStateLabel() -> UILabel", "Collapsed tool-state label creation lives in KCEditorUIFactory"))
    checks.append(require_text(editor_ui_factory_text, "enum KCEditorVisualStyle", "Editor visual style tokens are centralized"))
    checks.append(forbid_text(editor_ui_factory_text, "private enum KCEditorVisualStyle", "Editor visual style tokens are reusable across App UI helpers"))
    checks.append(require_text(editor_ui_factory_text, "cornerCurve = .continuous", "Editor controls use continuous corners for a more polished surface"))
    checks.append(require_text(editor_ui_factory_text, "applyFloatingPanelChrome", "Floating panel glass/chrome styling is centralized"))
    checks.append(require_text(editor_ui_factory_text, "applyRaisedButtonAppearance", "Raised button styling is centralized"))
    checks.append(require_text(editor_ui_factory_text, "applyCompactButtonAppearance", "Compact button styling is centralized"))
    checks.append(require_text(editor_ui_factory_text, "applySmallToolButtonAppearance", "Small tool button styling is centralized without overlapping helper calls"))
    checks.append(require_text(editor_ui_factory_text, "applySelectableButtonAppearance", "Selectable editor button styling is centralized"))
    checks.append(require_text(editor_ui_factory_text, "applyActionButtonAvailability", "Editor action button availability styling is centralized"))
    checks.append(require_text(editor_ui_factory_text, "saveActionColor", "Save action color token is centralized"))
    checks.append(require_text(editor_ui_factory_text, "KCEditorVisualStyle.applyFloatingPanelChrome", "Floating panels use centralized chrome styling"))
    checks.append(require_count_at_least(editor_ui_factory_text, r"KCEditorVisualStyle\.applyRaisedButtonAppearance", 4, "Primary editor buttons reuse raised-button styling"))
    checks.append(require_count_at_least(editor_ui_factory_text, r"KCEditorVisualStyle\.applyCompactButtonAppearance", 1, "Compact editor controls reuse compact-button styling"))
    checks.append(require_text(editor_ui_factory_text, "KCEditorVisualStyle.applySmallToolButtonAppearance", "Small editor controls reuse the dedicated small-button styling"))
    checks.append(require_text(brush_sticker_panel_text, "func applyPillSelectionAppearance", "Brush/stamp panel centralizes pill selection styling"))
    checks.append(require_text(brush_sticker_panel_text, "func applyStampButtonAppearance", "Brush/stamp panel centralizes stamp button styling"))
    checks.append(require_text(brush_sticker_panel_text, "button.layer.cornerCurve = .continuous", "Brush/stamp panel buttons use continuous corners"))
    checks.append(require_text(brush_sticker_panel_text, "KCEditorVisualStyle.applySelectableButtonAppearance", "Brush/stamp panel reuses shared selectable button styling"))
    checks.append(require_text(brush_sticker_panel_text, "KCEditorVisualStyle.applyActionButtonAvailability", "Brush/stamp panel reuses shared disabled button styling"))
    checks.append(forbid_text(brush_sticker_panel_text, "activePillBackgroundColor", "Brush/stamp panel does not duplicate active pill color tokens"))
    checks.append(forbid_text(brush_sticker_panel_text, "inactiveButtonBackgroundColor", "Brush/stamp panel does not duplicate button color tokens"))
    checks.append(require_text(main_text, "var editorUIFactory: KCEditorUIFactory", "Main view controller delegates common UI creation to KCEditorUIFactory"))
    checks.append(require_text(main_text, "return self.editorUIFactory.floatingPanel()", "Floating panel helper delegates to KCEditorUIFactory"))
    checks.append(require_text(main_text, "let toggle = self.editorUIFactory.collapseToggleButton", "Main view controller delegates collapse-toggle construction"))
    checks.append(require_text(main_text, "let chip = self.editorUIFactory.toolStateChip()", "Main view controller delegates collapsed chip construction"))
    checks.append(require_text(main_text, "let swatch = self.editorUIFactory.toolStateSwatch()", "Main view controller delegates collapsed chip swatch construction"))
    checks.append(require_text(main_text, "let label = self.editorUIFactory.toolStateLabel()", "Main view controller delegates collapsed chip label construction"))
    checks.append(forbid_text(main_text, "toggle.backgroundColor = UIColor(white: 1.0, alpha: 0.82)", "Collapse toggle styling is no longer hardcoded in the main view controller"))
    checks.append(forbid_text(main_text, "toggle.layer.shadowOpacity = 0.16", "Collapse toggle shadow is no longer hardcoded in the main view controller"))
    checks.append(forbid_text(main_text, "chip.backgroundColor = UIColor(white: 1.0, alpha: 0.82)", "Collapsed chip styling is no longer hardcoded in the main view controller"))
    checks.append(forbid_text(main_text, "chip.layer.shadowOpacity = 0.12", "Collapsed chip shadow is no longer hardcoded in the main view controller"))
    checks.append(require_text(pbx_text, "KCPressFeedbackController.swift in Sources", "Press feedback controller is included in the app target sources"))
    checks.append(require_text(press_feedback_text, "final class KCPressFeedbackController", "Press feedback is extracted to KCPressFeedbackController"))
    checks.append(require_text(press_feedback_text, "func register(_ control: UIControl)", "Press feedback registration lives in KCPressFeedbackController"))
    checks.append(require_text(press_feedback_text, "objc_getAssociatedObject", "Press feedback associated-object state lives in KCPressFeedbackController"))
    checks.append(require_text(press_feedback_text, "if !control.isEnabled", "Disabled controls do not trigger press feedback"))
    checks.append(require_text(main_text, "private(set) lazy var pressFeedbackController: KCPressFeedbackController", "Main view controller owns a Press Feedback controller instance"))
    checks.append(require_text(main_text, "self.pressFeedbackController.register(control)", "Main view controller delegates press-feedback registration"))
    checks.append(forbid_text(main_text, "objc_getAssociatedObject", "Press feedback associated-object state is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "objc_setAssociatedObject", "Press feedback associated-object mutation is no longer owned by the main view controller"))
    checks.append(require_text(pbx_text, "KCToastPresenter.swift in Sources", "Toast presenter is included in the app target sources"))
    checks.append(require_text(toast_presenter_text, "final class KCToastPresenter", "Save toast UI is extracted to KCToastPresenter"))
    checks.append(require_text(toast_presenter_text, "func showSaveToast(success: Bool, in view: UIView, anchorView: UIView) -> UIView", "Save toast presentation lives in KCToastPresenter"))
    checks.append(require_text(toast_presenter_text, "func dismiss(_ toastView: UIView?)", "Save toast dismissal lives in KCToastPresenter"))
    checks.append(require_text(toast_presenter_text, "UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))", "Toast keeps the existing blur style"))
    checks.append(require_text(toast_presenter_text, "KCL10n.saveSuccessToastTitle", "Save success toast uses localized text"))
    checks.append(require_text(toast_presenter_text, "KCL10n.saveFailedToastTitle", "Save failure toast uses localized text"))
    checks.append(require_text(toast_presenter_text, "toast.accessibilityLabel = titleLabel.text", "Save toast exposes localized accessibility text"))
    checks.append(require_text(main_text, "self.toastPresenter.showSaveToast(success: success, in: self.view, anchorView: self.saveButton)", "Main view controller delegates save toast presentation"))
    checks.append(require_text(main_text, "self.toastPresenter.dismiss(self.saveToastView)", "Main view controller delegates save toast dismissal"))
    checks.append(require_text(main_text, "#if DEBUG", "Runtime acceptance probe is Debug-only"))
    checks.append(require_text(main_text, "--kc-runtime-empty-save-check", "Runtime acceptance probe is gated by an explicit launch argument"))
    checks.append(require_text(main_text, "--kc-runtime-layout-check", "Runtime layout probe is gated by an explicit launch argument"))
    checks.append(require_text(main_text, "--kc-runtime-sticker-check", "Runtime sticker probe is gated by an explicit launch argument"))
    checks.append(require_text(main_text, "--kc-runtime-save-history-check", "Runtime save-history probe is gated by an explicit launch argument"))
    checks.append(require_text(main_text, "--kc-runtime-drawing-tools-check", "Runtime drawing-tools probe is gated by an explicit launch argument"))
    checks.append(require_text(main_text, "--kc-runtime-system-ui-check", "Runtime system-ui probe is gated by an explicit launch argument"))
    checks.append(require_text(main_text, "kc_runtime_acceptance_empty_save.json", "Runtime acceptance probe writes the empty-save JSON result"))
    checks.append(require_text(main_text, "kc_runtime_acceptance_layout.json", "Runtime acceptance probe writes the layout JSON result"))
    checks.append(require_text(main_text, "kc_runtime_acceptance_sticker.json", "Runtime acceptance probe writes the sticker JSON result"))
    checks.append(require_text(main_text, "kc_runtime_acceptance_save_history.json", "Runtime save-history probe writes the save-history JSON result"))
    checks.append(require_text(main_text, "kc_runtime_acceptance_drawing_tools.json", "Runtime drawing-tools probe writes the drawing-tools JSON result"))
    checks.append(require_text(main_text, "kc_runtime_acceptance_system_ui.json", "Runtime system-ui probe writes the system-ui JSON result"))
    checks.append(require_text(main_text, "saveButtonEnabledBeforeTap", "Runtime acceptance probe verifies empty-canvas save remains tappable"))
    checks.append(require_text(main_text, "failureToastVisible", "Runtime acceptance probe verifies the localized save-failure toast"))
    checks.append(require_text(main_text, "layout-safe-area", "Runtime layout probe reports its probe name"))
    checks.append(require_text(main_text, "safeAreaInsets", "Runtime layout probe records safe area insets"))
    checks.append(require_text(main_text, "layoutCheckResult", "Runtime layout probe checks key floating controls"))
    checks.append(require_text(main_text, "visibleHeightCheckResult", "Runtime layout probe checks compact visible panel heights"))
    checks.append(require_text(main_text, "right-panel-visible-height", "Runtime layout probe guards the compact right panel height"))
    checks.append(require_text(main_text, "left-rail-visible-height", "Runtime layout probe guards the compact left rail height"))
    checks.append(require_text(main_text, "sticker-undo-redo", "Runtime sticker probe reports its probe name"))
    checks.append(require_text(main_text, "afterInsertSelected", "Runtime sticker probe verifies inserted stamp selection"))
    checks.append(require_text(main_text, "afterUndoVisible", "Runtime sticker probe verifies undo restores stamp content"))
    checks.append(require_text(main_text, "afterRedoVisible", "Runtime sticker probe verifies redo reapplies stamp delete"))
    checks.append(require_text(main_text, "save-history-restore", "Runtime save-history probe reports its probe name"))
    checks.append(require_text(main_text, "afterSaveHistoryCount", "Runtime save-history probe verifies history count grows after save"))
    checks.append(require_text(main_text, "successToastObserved", "Runtime save-history probe verifies the save-success toast is triggered"))
    checks.append(require_text(main_text, "afterOpenVisible", "Runtime save-history probe verifies saved history restores visible content"))
    checks.append(require_text(main_text, "drawing-tools", "Runtime drawing-tools probe reports its probe name"))
    checks.append(require_text(main_text, "palette36Count", "Runtime drawing-tools probe verifies palette switching"))
    checks.append(require_text(main_text, "eraserChangedCanvas", "Runtime drawing-tools probe verifies eraser changes canvas pixels"))
    checks.append(require_text(main_text, "fillSucceeded", "Runtime drawing-tools probe verifies flood fill succeeds"))
    checks.append(require_text(main_text, "pickedColorMatchesFill", "Runtime drawing-tools probe verifies eyedropper samples the filled color"))
    checks.append(require_text(main_text, "recentColorRecorded", "Runtime drawing-tools probe verifies picked color is recorded as recent"))
    checks.append(require_text(main_text, "system-ui", "Runtime system-ui probe reports its probe name"))
    checks.append(require_text(main_text, "configuredCustomColorPicker", "System color picker configuration is reusable by production and acceptance paths"))
    checks.append(require_text(main_text, "presentCustomColorPicker", "System color picker presentation is reusable by production and acceptance paths"))
    checks.append(require_text(main_text, "configuredPhotoLibraryPicker", "Photo picker configuration is reusable by production and acceptance paths"))
    checks.append(require_text(main_text, "presentPhotoLibraryPicker", "Photo picker presentation is reusable by production and acceptance paths"))
    checks.append(require_text(main_text, "colorPickerPopoverSourceIsCustomButton", "Runtime system-ui probe verifies the custom color popover anchor"))
    checks.append(require_text(main_text, "colorPickerSelectionApplied", "Runtime system-ui probe verifies system color selection applies to the canvas"))
    checks.append(require_text(main_text, "colorPickerSelectionRecorded", "Runtime system-ui probe verifies system color selection is recorded as recent"))
    checks.append(require_text(main_text, "imagePickerUsesPhotoLibrary", "Runtime system-ui probe verifies photo library source type"))
    checks.append(require_text(main_text, "imageImportVisible", "Runtime system-ui probe verifies selected photo import creates visible content"))
    checks.append(require_text(main_text, "imageImportStartsClean", "Runtime system-ui probe verifies imported photos start as a clean session"))
    checks.append(require_text(main_text, "runtimeAcceptanceImportImage", "Runtime system-ui probe uses a deterministic synthetic import image"))
    checks.append(require_text(canvas_text, "insertRuntimeAcceptanceEraserStroke", "Canvas exposes Debug-only eraser helper for runtime acceptance"))
    checks.append(require_text(canvas_text, "performRuntimeAcceptanceFloodFill", "Canvas exposes Debug-only fill helper for runtime acceptance"))
    checks.append(require_text(canvas_text, "runtimeAcceptancePickedColor", "Canvas exposes Debug-only eyedropper helper for runtime acceptance"))
    checks.append(require_text(main_text, "runSaveHistoryAcceptanceProbe", "Runtime save-history probe is implemented in the main view controller"))
    checks.append(forbid_text(main_text, "let toast = UIVisualEffectView", "Save toast view construction is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "UIImage.SymbolConfiguration(pointSize: 24.0", "Save toast icon construction is no longer owned by the main view controller"))
    checks.append(require_text(pbx_text, "KCColorPalettePanelRenderer.swift in Sources", "Color palette panel renderer is included in the app target sources"))
    checks.append(require_text(color_palette_renderer_text, "final class KCColorPalettePanelRenderer", "Color palette UIKit rendering is extracted to KCColorPalettePanelRenderer"))
    checks.append(require_text(color_palette_renderer_text, "struct Configuration", "Color palette renderer exposes a configuration DTO"))
    checks.append(require_text(color_palette_renderer_text, "struct RenderedPanel", "Color palette renderer returns rendered panel references"))
    checks.append(require_text(color_palette_renderer_text, "func renderPanel", "Color palette panel construction lives in KCColorPalettePanelRenderer"))
    checks.append(require_text(color_palette_renderer_text, "func reloadPaletteGrid", "Palette grid rendering lives in KCColorPalettePanelRenderer"))
    checks.append(require_text(color_palette_renderer_text, "func reloadRecentColorRow", "Recent color row rendering lives in KCColorPalettePanelRenderer"))
    checks.append(require_text(color_palette_renderer_text, "func updateSegmentButtons", "Palette segment selected-state styling lives in KCColorPalettePanelRenderer"))
    checks.append(require_text(color_palette_renderer_text, "func applyActiveColor", "Current color highlighting lives in KCColorPalettePanelRenderer"))
    checks.append(require_text(color_palette_renderer_text, "KCEditorVisualStyle.applyCompactButtonAppearance", "Custom color button reuses shared compact styling"))
    checks.append(require_text(color_palette_renderer_text, "KCEditorVisualStyle.accentColor", "Palette segment selected state reuses shared accent token"))
    checks.append(require_text(color_palette_renderer_text, "KCEditorVisualStyle.pillBackgroundColor", "Palette segment container reuses shared pill background token"))
    checks.append(require_text(main_text, "private(set) lazy var colorPaletteRenderer: KCColorPalettePanelRenderer", "Main view controller owns a color palette renderer instance"))
    checks.append(require_text(main_text, "self.colorPaletteRenderer.renderPanel", "Main view controller delegates color panel construction"))
    checks.append(require_text(main_text, "self.colorPaletteRenderer.reloadPaletteGrid", "Main view controller delegates palette grid rendering"))
    checks.append(require_text(main_text, "self.colorPaletteRenderer.reloadRecentColorRow", "Main view controller delegates recent color rendering"))
    checks.append(require_text(main_text, "self.colorPaletteRenderer.updateSegmentButtons", "Main view controller delegates palette segment styling"))
    checks.append(require_text(main_text, "self.colorPaletteRenderer.applyActiveColor", "Main view controller delegates current color highlighting"))
    checks.append(forbid_text(main_text, "colorButton.layer.cornerRadius = buttonSize / 2.0", "Palette color button styling is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "button.layer.cornerRadius = buttonSize / 2.0", "Recent color button styling is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "self.palette24Button.setTitleColor", "Palette segment styling is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "activeColorButton.layer.borderColor", "Current color highlight border reset is no longer owned by the main view controller"))
    checks.append(require_text(pbx_text, "KCBrushStickerPanelView.swift in Sources", "Brush/sticker panel view is included in the app target sources"))
    checks.append(require_text(brush_sticker_panel_text, "final class KCBrushStickerPanelView", "Brush/sticker/eraser panel assembly is extracted to KCBrushStickerPanelView"))
    checks.append(require_text(brush_sticker_panel_text, "struct Texts", "Brush/sticker panel text inputs are explicit"))
    checks.append(require_text(brush_sticker_panel_text, "struct RenderedPanel", "Brush/sticker panel returns rendered control references"))
    checks.append(require_text(brush_sticker_panel_text, "func renderPanel", "Brush/sticker panel assembly lives in KCBrushStickerPanelView"))
    checks.append(require_text(brush_sticker_panel_text, "func reloadStickerButtons", "Sticker list rendering lives in KCBrushStickerPanelView"))
    checks.append(require_text(brush_sticker_panel_text, "func applyStickerCategorySelection", "Sticker category selected-state styling lives in KCBrushStickerPanelView"))
    checks.append(require_text(brush_sticker_panel_text, "func applyStickerSymbolSelection", "Sticker symbol selected-state styling lives in KCBrushStickerPanelView"))
    checks.append(require_text(brush_sticker_panel_text, "func applyStickerEditButtonsEnabled", "Sticker edit button enabled styling lives in KCBrushStickerPanelView"))
    checks.append(require_text(main_text, "private(set) lazy var brushStickerPanelView: KCBrushStickerPanelView", "Main view controller owns a brush/sticker panel view instance"))
    checks.append(require_text(main_text, "self.brushStickerPanelView.renderPanel", "Main view controller delegates brush/sticker panel assembly"))
    checks.append(require_text(main_text, "self.brushStickerPanelView.reloadStickerButtons", "Main view controller delegates sticker list rendering"))
    checks.append(require_text(main_text, "self.brushStickerPanelView.applyStickerCategorySelection", "Main view controller delegates sticker category selected-state styling"))
    checks.append(require_text(main_text, "self.brushStickerPanelView.applyStickerSymbolSelection", "Main view controller delegates sticker symbol selected-state styling"))
    checks.append(require_text(main_text, "self.brushStickerPanelView.applyStickerEditButtonsEnabled", "Main view controller delegates sticker edit button styling"))
    checks.append(forbid_text(main_text, "self.sizeSlider = UISlider()", "Size slider construction is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "let stickerScrollView = UIScrollView()", "Sticker scroll view assembly is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "self.circleEraserButton = self.smallToolButtonWithSymbolName", "Eraser shape button assembly is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "self.frontStickerButton = self.smallToolButtonWithSymbolName", "Sticker edit button assembly is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "button.transform = active ? CGAffineTransform(scaleX: 1.05", "Sticker symbol selection does not resize buttons or shift layout in the main controller"))
    checks.append(forbid_text(main_text, "UIColor(red: 0.86, green: 0.94, blue: 1.0", "Sticker symbol selection color is no longer hardcoded in the main controller"))
    checks.append(require_text(pbx_text, "KCBrushDockFeature.swift in Sources", "Brush Dock feature is included in the app target sources"))
    checks.append(require_text(brush_dock_feature_text, "final class KCBrushDockFeature", "Brush Dock configuration is extracted to KCBrushDockFeature"))
    checks.append(require_text(brush_dock_feature_text, "struct KCBrushDockItem: Equatable", "Brush Dock item DTO is explicit and comparable"))
    checks.append(require_text(brush_dock_feature_text, "func brushItems() -> [KCBrushDockItem]", "Brush Dock item list lives in KCBrushDockFeature"))
    checks.append(require_text(brush_dock_feature_text, "func brushColor(for style: KDBrushStyle) -> UIColor", "Brush accent colors live in KCBrushDockFeature"))
    checks.append(require_text(brush_dock_feature_text, "func isButton(_ button: KDBrushButton, activeForToolMode toolMode: KDToolMode, brushStyle: KDBrushStyle) -> Bool", "Brush Dock selection matching lives in KCBrushDockFeature"))
    checks.append(require_text(brush_dock_feature_text, "func applySelectionAppearance(to button: KDBrushButton, active: Bool)", "Brush Dock selected-state styling lives in KCBrushDockFeature"))
    checks.append(require_text(brush_dock_feature_text, "KCEditorVisualStyle.applySelectableButtonAppearance", "Brush Dock selected-state chrome reuses shared editor visual token"))
    checks.append(forbid_text(brush_dock_feature_text, "activeBackgroundColor", "Brush Dock does not duplicate selected background token"))
    checks.append(forbid_text(brush_dock_feature_text, "inactiveBorderColor", "Brush Dock does not duplicate inactive border token"))
    checks.append(forbid_text(brush_dock_feature_text, "CGAffineTransform(scaleX", "Brush Dock selection does not resize buttons or shift layout"))
    checks.append(require_text(brush_dock_feature_text, 'id: "pencil"', "Brush Dock feature declares the pencil item"))
    checks.append(require_text(brush_dock_feature_text, 'id: "pen"', "Brush Dock feature declares the pen item"))
    checks.append(require_text(brush_dock_feature_text, 'id: "crayon"', "Brush Dock feature declares the crayon item"))
    checks.append(require_text(main_text, "private(set) lazy var brushDockFeature: KCBrushDockFeature", "Main view controller owns a Brush Dock feature instance"))
    checks.append(require_text(main_text, "let brushItems = self.brushDockFeature.brushItems()", "Main view controller delegates brush dock item creation to KCBrushDockFeature"))
    checks.append(require_text(main_text, "self.brushDockFeature.isButton(", "Main view controller delegates brush Dock selection matching"))
    checks.append(require_text(main_text, "self.brushDockFeature.applySelectionAppearance(to: button, active: active)", "Main view controller delegates brush Dock selected-state styling"))
    checks.append(forbid_text(main_text, "let brushItems: [(id:", "Brush Dock tuple configuration is no longer hardcoded in the main view controller"))
    checks.append(forbid_text(main_text, "func brushColor(for style: KDBrushStyle) -> UIColor", "Brush accent color decisions live outside the main view controller"))
    checks.append(forbid_text(main_text, "button.backgroundColor = active ? UIColor(red: 0.66, green: 0.89, blue: 0.72", "Brush Dock selected background is no longer written in the main view controller"))
    checks.append(forbid_text(main_text, "button.layer.shadowOpacity = active ? 0.20 : 0.12", "Brush Dock selected shadow is no longer written in the main view controller"))
    checks.append(require_text(pbx_text, "KCEraserControlsFeature.swift in Sources", "Eraser controls feature is included in the app target sources"))
    checks.append(require_text(eraser_controls_feature_text, "final class KCEraserControlsFeature", "Eraser controls are extracted to KCEraserControlsFeature"))
    checks.append(require_text(eraser_controls_feature_text, "func previewPath(for shape: KDEraserShape, center: CGPoint, size: CGFloat) -> UIBezierPath", "Eraser preview path creation lives in KCEraserControlsFeature"))
    checks.append(require_text(eraser_controls_feature_text, "func isShape(_ shape: KDEraserShape, activeFor currentShape: KDEraserShape) -> Bool", "Eraser shape active-state matching lives in KCEraserControlsFeature"))
    checks.append(require_text(eraser_controls_feature_text, "func applyShapeButtonAppearance(to button: UIButton, active: Bool)", "Eraser shape button selected-state styling lives in KCEraserControlsFeature"))
    checks.append(require_text(eraser_controls_feature_text, "KCEditorVisualStyle.applySelectableButtonAppearance", "Eraser shape buttons reuse shared selectable button styling"))
    checks.append(forbid_text(eraser_controls_feature_text, "activeBackgroundColor", "Eraser controls do not duplicate selected background token"))
    checks.append(forbid_text(eraser_controls_feature_text, "inactiveBorderColor", "Eraser controls do not duplicate inactive border token"))
    checks.append(forbid_text(eraser_controls_feature_text, "CGAffineTransform(scaleX", "Eraser shape selection does not resize buttons or shift layout"))
    checks.append(require_text(main_text, "private(set) lazy var eraserControlsFeature: KCEraserControlsFeature", "Main view controller owns an Eraser Controls feature instance"))
    checks.append(require_text(main_text, "self.eraserControlsFeature.previewPath(", "Main view controller delegates eraser preview path creation"))
    checks.append(require_text(main_text, "self.eraserControlsFeature.applyShapeButtonAppearance(to: item.button, active: active)", "Main view controller delegates eraser shape button selected-state styling"))
    checks.append(forbid_text(main_text, "func previewPathForEraserShape", "Eraser preview path creation is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "let buttons: [UIButton] = [self.circleEraserButton, self.cloudEraserButton, self.starEraserButton]", "Eraser shape buttons no longer use anonymous array/index matching in the main view controller"))
    checks.append(forbid_text(main_text, "for index in 0..<buttons.count", "Eraser shape button refresh no longer depends on indexes in the main view controller"))
    checks.append(forbid_text(main_text, "index == self.canvasView.currentEraserShape.rawValue", "Eraser shape active-state matching no longer depends on button array indexes in the main view controller"))
    # T023: collapse state lives in KCEditorPanelsFeature (KCEditorPanelsCollapseState in KCDomain); controller delegates.
    checks.append(require_text(editor_panels_feature_text, "var panelsCollapsed: Bool", "Toolbar collapse state is tracked in the editor panels feature"))
    checks.append(require_text(kc_editor_panels_collapse_state_text, "public struct KCEditorPanelsCollapseState", "Collapse-state decisions are extracted to KCDomain"))
    checks.append(require_text(main_text, "var collapsiblePanels", "Collapsible panel groups are tracked for hide/show"))
    checks.append(require_text(main_text, "self.collapsiblePanels = [topLeft, topRight, leftRail, rightScrollView, bottomDock]", "Collapse hides all five floating panel groups at once"))
    checks.append(require_text(main_text, "let safeArea = self.view.safeAreaLayoutGuide", "Floating editor controls use the safe area as their layout boundary"))
    checks.append(require_text(main_text, "topLeft.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor", "Top-left controls avoid the landscape safe-area edge"))
    checks.append(require_text(main_text, "topRight.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor", "Top-right controls avoid the landscape safe-area edge"))
    checks.append(require_text(main_text, "leftRail.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor", "Left tool rail avoids the landscape safe-area edge"))
    checks.append(require_text(main_text, "rightScrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor", "Right panel avoids the landscape safe-area edge"))
    checks.append(require_text(main_text, "toggle.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor", "Collapse toggle avoids the safe-area edge"))
    checks.append(require_regex(main_text, r"leftRail\.widthAnchor\.constraint\(equalToConstant: 80\.0\)", "Left tool rail uses compact iPhone-friendly width"))
    checks.append(require_text(main_text, "leftRail.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: self.leftRailTopOffset())", "Left tool rail top offset is delegated to device layout metrics"))
    checks.append(require_text(main_text, "leftRail.heightAnchor.constraint(equalTo: safeArea.heightAnchor, multiplier: self.leftRailHeightMultiplier())", "Left tool rail height is delegated to device layout metrics"))
    checks.append(require_regex(main_text, r"func buildLeftRail[\s\S]*let toolScrollView = UIScrollView\(\)[\s\S]*toolScrollView\.alwaysBounceVertical = true[\s\S]*toolScrollView\.addSubview\(stack\)", "Left tool rail is vertically scrollable on compact iPhone screens"))
    checks.append(require_regex(main_text, r"func buildLeftRail[\s\S]*toolScrollView\.clipsToBounds = true[\s\S]*toolScrollView\.addSubview\(stack\)", "Left tool rail clips scrolling tools inside its capsule"))
    checks.append(require_regex(editor_ui_factory_text, r"func railToolButton[\s\S]*button\.widthAnchor\.constraint\(equalToConstant: 56\.0\)[\s\S]*button\.heightAnchor\.constraint\(equalToConstant: 56\.0\)", "Left tool buttons use compact stable dimensions"))
    checks.append(require_text(pbx_text, "KCToolRailFeature.swift in Sources", "Tool Rail feature is included in the app target sources"))
    checks.append(require_text(tool_rail_feature_text, "final class KCToolRailFeature", "Tool Rail configuration is extracted to KCToolRailFeature"))
    checks.append(require_text(tool_rail_feature_text, "struct KCToolRailItem: Equatable", "Tool Rail item DTO is explicit and comparable"))
    checks.append(require_text(tool_rail_feature_text, "func toolItems() -> [KCToolRailItem]", "Tool Rail item list lives in KCToolRailFeature"))
    checks.append(require_text(tool_rail_feature_text, "func accentColor(for mode: KDToolMode) -> UIColor?", "Tool Rail accent colors live in KCToolRailFeature"))
    checks.append(require_text(tool_rail_feature_text, "func isButton(_ button: KDToolButton, activeFor toolMode: KDToolMode) -> Bool", "Tool Rail active-state matching lives in KCToolRailFeature"))
    checks.append(require_text(tool_rail_feature_text, "func applySelectionAppearance(to button: KDToolButton, active: Bool)", "Tool Rail selected-state styling lives in KCToolRailFeature"))
    checks.append(require_text(tool_rail_feature_text, "KCEditorVisualStyle.applySelectableButtonAppearance", "Tool Rail selected-state chrome reuses shared editor visual token"))
    checks.append(forbid_text(tool_rail_feature_text, "activeBackgroundColor", "Tool Rail does not duplicate selected background token"))
    checks.append(forbid_text(tool_rail_feature_text, "inactiveBorderColor", "Tool Rail does not duplicate inactive border token"))
    checks.append(require_text(tool_rail_feature_text, 'id: "brush"', "Tool Rail feature declares the brush item"))
    checks.append(require_text(tool_rail_feature_text, 'id: "eraser"', "Tool Rail feature declares the eraser item"))
    checks.append(require_text(tool_rail_feature_text, 'id: "fill"', "Tool Rail feature declares the fill item"))
    checks.append(require_text(tool_rail_feature_text, 'id: "sticker"', "Tool Rail feature declares the sticker item"))
    checks.append(require_text(tool_rail_feature_text, 'KCToolRailItem(id: "sticker", mode: .sticker, symbolName: "seal.fill"', "Product-facing stamp tool uses a stamp-like SF Symbol"))
    checks.append(require_text(tool_rail_feature_text, 'id: "eyedropper"', "Tool Rail feature declares the eyedropper item"))
    checks.append(require_text(main_text, "private(set) lazy var toolRailFeature: KCToolRailFeature", "Main view controller owns a Tool Rail feature instance"))
    checks.append(require_text(main_text, "let items = self.toolRailFeature.toolItems()", "Main view controller delegates tool rail item creation to KCToolRailFeature"))
    checks.append(require_text(main_text, "self.toolRailFeature.isButton(", "Main view controller delegates tool rail active-state matching"))
    checks.append(require_text(main_text, "self.toolRailFeature.applySelectionAppearance(to: button, active: active)", "Main view controller delegates tool rail selected-state styling"))
    checks.append(forbid_text(main_text, "let items: [(symbol: String, mode: KDToolMode, id: String, label: String)]", "Tool Rail tuple configuration is no longer hardcoded in the main view controller"))
    checks.append(forbid_text(main_text, "button.backgroundColor = active\n                ? UIColor(red: 0.66, green: 0.89, blue: 0.72", "Tool Rail selected background is no longer written in the main view controller"))
    checks.append(forbid_text(main_text, "button.layer.shadowOpacity = active ? 0.14 : 0.08", "Tool Rail selected shadow is no longer written in the main view controller"))
    checks.append(require_text(editor_ui_factory_text, "button.transform = .identity", "Shared selectable styling keeps button frames stable"))
    checks.append(forbid_text(tool_rail_feature_text, "CGAffineTransform(scaleX", "Left tool selection does not scale buttons outside the rail"))
    checks.append(require_text(pbx_text, "KCDeviceLayoutMetrics.swift in Sources", "Device layout metrics are included in the app target sources"))
    checks.append(require_text(device_layout_metrics_text, "struct KCDeviceLayoutMetrics", "Device layout metrics are extracted from the main view controller"))
    checks.append(require_text(device_layout_metrics_text, "userInterfaceIdiom == .phone", "Device layout metrics detect compact phone layout"))
    checks.append(require_regex(device_layout_metrics_text, r"var rightPanelWidth: CGFloat[\s\S]*208\.0 : 248\.0", "Right panel uses compact iPhone width without changing iPad width"))
    checks.append(require_regex(device_layout_metrics_text, r"var rightPanelOuterWidth: CGFloat[\s\S]*232\.0 : 272\.0", "Right panel scroll container has compact iPhone width"))
    checks.append(require_regex(device_layout_metrics_text, r"var rightPanelTopOffset: CGFloat[\s\S]*88\.0 : 150\.0", "Compact iPhone right panel starts higher to expose more content"))
    checks.append(require_regex(device_layout_metrics_text, r"var leftRailTopOffset: CGFloat[\s\S]*112\.0 : 150\.0", "Compact iPhone left rail starts higher without colliding with the top toolbar"))
    checks.append(require_regex(device_layout_metrics_text, r"var leftRailHeightMultiplier: CGFloat[\s\S]*0\.58 : 0\.46", "Compact iPhone left rail exposes complete visible tools without clipping a partial item"))
    checks.append(require_regex(device_layout_metrics_text, r"var bottomDockWidth: CGFloat[\s\S]*430\.0 : 560\.0", "Bottom brush dock uses compact iPhone width without changing iPad width"))
    checks.append(require_regex(device_layout_metrics_text, r"var bottomDockHeight: CGFloat[\s\S]*66\.0 : 98\.0", "Bottom brush dock uses compact iPhone height"))
    checks.append(require_regex(device_layout_metrics_text, r"var brushCardWidth: CGFloat[\s\S]*100\.0 : 126\.0", "Bottom brush cards shrink on iPhone"))
    checks.append(require_regex(device_layout_metrics_text, r"var brushCardHeight: CGFloat[\s\S]*50\.0 : 68\.0", "Bottom brush cards stay inside the compact iPhone dock"))
    checks.append(require_regex(device_layout_metrics_text, r"var historyThumbSize: CGFloat[\s\S]*82\.0 : 92\.0", "History thumbnails keep compact iPhone sizing"))
    checks.append(require_text(main_text, "var layoutMetrics: KCDeviceLayoutMetrics", "Main view controller delegates device sizing to KCDeviceLayoutMetrics"))
    checks.append(require_text(main_text, "return self.layoutMetrics.rightPanelWidth", "Right panel width is delegated to KCDeviceLayoutMetrics"))
    checks.append(require_text(main_text, "return self.layoutMetrics.bottomDockWidth", "Bottom dock width is delegated to KCDeviceLayoutMetrics"))
    checks.append(require_text(main_text, "return self.layoutMetrics.brushCardWidth", "Brush card width is delegated to KCDeviceLayoutMetrics"))
    checks.append(require_text(main_text, "bottomDock.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor", "Bottom brush dock respects the safe area"))
    checks.append(require_regex(main_text, r"rightScrollView\.clipsToBounds = true", "Right menu clips content inside its scroll container"))
    checks.append(require_regex(main_text, r"func paletteColorButtonSize\(\) -> CGFloat[\s\S]*return self\.isCompactPhoneLayout \? 24\.0 : self\.contentPicker\.paletteColorButtonSize", "Color swatches shrink inside compact iPhone right menu"))
    checks.append(require_regex(main_text, r"func paletteColorButtonSpacing\(\) -> CGFloat[\s\S]*return self\.isCompactPhoneLayout \? 5\.0 : self\.contentPicker\.paletteColorButtonSpacing", "Color swatch spacing tightens inside compact iPhone right menu"))
    checks.append(require_regex(main_text, r"func buildBottomDock[\s\S]*scrollView\.clipsToBounds = true[\s\S]*panel\.addSubview\(scrollView\)", "Bottom brush dock clips horizontal scroll content"))
    checks.append(require_regex(brush_sticker_panel_text, r"let stickerScrollView[\s\S]*stickerScrollView\.clipsToBounds = true[\s\S]*panel\.addSubview\(stickerScrollView\)", "Right sticker row clips content inside the panel"))
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
    checks.append(require_regex(color_palette_renderer_text, r"customButton\.bottomAnchor\.constraint\(equalTo: panel\.bottomAnchor", "Custom color area pins its single entry to the panel bottom (no rainbow band)"))
    checks.append(require_regex(color_palette_renderer_text, r"let recentScrollView[\s\S]*showsHorizontalScrollIndicator = false[\s\S]*recentScrollView\.addSubview\(recentRow\)", "Recent colors are presented in a horizontal scroll row"))
    checks.append(require_regex(color_palette_renderer_text, r"let recentScrollView[\s\S]*recentScrollView\.clipsToBounds = true[\s\S]*recentScrollView\.addSubview\(recentRow\)", "Recent colors are clipped inside the color panel"))
    # T022: recent-color dedupe/cap logic moved to KCDomain KCRecentColorQueue (tested); controller delegates via the feature.
    checks.append(require_text(kc_recent_color_queue_text, "defaultLimit: Int = 8", "Recent colors keep up to eight colors (KCDomain KCRecentColorQueue)"))
    checks.append(require_text(content_picker_feature_text, "KCRecentColorQueue.inserting(", "Content picker feature delegates recent-color insertion to KCDomain"))
    checks.append(require_text(canvas_models_text, "case picker", "Eyedropper tool mode exists"))
    checks.append(require_text(canvas_text, "sampleColorFromImage(", "Eyedropper delegates pixel sampling to Swift"))
    checks.append(require_text(drawing_bridge_text, "KCImagePixelSampler.sample(cgImage: image, x: x, y: y)", "Eyedropper bridge samples a single pixel without rasterizing the whole image"))
    checks.append(forbid_text(drawing_bridge_text, "KCColorSampler.sample(buffer: buffer, x: x, y: y)", "Eyedropper bridge no longer samples through a full-image bitmap buffer"))
    checks.append(forbid_text(canvas_text, "CGContextTranslateCTM", "Eyedropper avoids fragile manual context flipping"))
    # T036: drawing algorithms are accessed through an injected protocol instance.
    checks.append(require_text(drawing_bridge_text, "protocol KCDrawingEngineProviding", "Drawing engine protocol boundary exists"))
    checks.append(require_text(drawing_bridge_text, "final class KCDrawingEngineAdapter: NSObject, KCDrawingEngineProviding", "Default drawing adapter implements the protocol"))
    checks.append(require_text(composition_root_text, "self.drawingEngine = KCDrawingEngineAdapter()", "Composition Root constructs the default drawing engine adapter"))
    checks.append(require_text(main_text, "let drawingEngine: KCDrawingEngineProviding", "Main view controller stores the injected drawing engine"))
    checks.append(require_text(pbx_text, "KCLineArtFeature.swift in Sources", "Line-art feature is included in the app target sources"))
    checks.append(require_text(pbx_text, "KCLineArtPickerViewController.swift in Sources", "Line-art picker view controller is included in the app target sources"))
    checks.append(require_text(canvas_text, "var drawingEngine: KCDrawingEngineProviding", "Canvas view depends on the drawing engine protocol"))
    checks.append(require_text(canvas_text, "self.drawingEngine.normalizedPressure", "Drawing canvas delegates to the injected drawing engine"))
    checks.append(require_text(canvas_text, "self.drawingEngine.normalizedPressure", "Pressure normalization is bridged through DI"))
    checks.append(require_text(canvas_text, "self.drawingEngine.floodFillImage", "Flood fill is bridged through DI"))
    checks.append(require_text(canvas_text, "self.drawingEngine.sampleColorFromImage", "Color sampling is bridged through DI"))
    checks.append(require_text(canvas_models_text, "case pencil", "Pencil brush style exists"))
    checks.append(require_text(canvas_models_text, "case pen", "Pen brush style exists"))
    checks.append(require_text(canvas_models_text, "case crayon", "Crayon brush style exists"))
    checks.append(require_regex(canvas_text, r"\.crayon[\s\S]*drawCrayonGrain\(forPath: renderPath", "Crayon brush adds clipped grain texture"))
    checks.append(require_regex(canvas_text, r"func drawCrayonGrain[\s\S]*clipPath\.addClip\(\)", "Crayon grain texture is clipped to the stroke (UIKit drawing in Swift)"))
    checks.append(require_text(canvas_text, "self.drawingEngine.crayonGrainDashPoints(pathBounds:", "Crayon grain geometry is delegated to the injected drawing engine"))
    checks.append(require_regex(crayon_grain_text, r"public enum KCCrayonGrain", "Crayon grain engine is implemented in Swift"))
    checks.append(require_text(crayon_grain_text, "let seed = row * 37 + column * 17", "Crayon grain is deterministic (seed math in Swift)"))
    checks.append(require_text(crayon_grain_text, "let columnCount = min(220", "Crayon grain has a column safety cap"))
    checks.append(require_text(crayon_grain_text, "let rowCount = min(180", "Crayon grain has a row safety cap"))
    checks.append(require_text(main_text, "bottomDock.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)", "Bottom brush dock is centered as a floating control"))
    checks.append(require_regex(main_text, r"func buildBottomDock[\s\S]*\.pencil[\s\S]*\.pen[\s\S]*\.crayon", "Bottom dock contains brush choices only", re.S))
    checks.append(require_text(canvas_models_text, "case circle", "Circle eraser shape exists"))
    checks.append(require_text(canvas_models_text, "case cloud", "Cloud eraser shape exists"))
    checks.append(require_text(canvas_models_text, "case star", "Star eraser shape exists"))
    checks.append(require_text(canvas_text, "func performFloodFill", "Flood fill entry point remains in the Swift canvas"))
    checks.append(require_text(canvas_text, "self.drawingEngine.floodFillImage", "Flood fill delegates to the injected drawing engine"))
    checks.append(require_text(canvas_text, "self.drawingEngine.normalizedPressure", "Pressure normalization delegates to the injected drawing engine"))
    checks.append(require_text(canvas_text, "self.drawingEngine.sampleColorFromImage", "Color sampling delegates to the injected drawing engine"))
    checks.append(require_text(canvas_text, "final class KCDrawingCanvasView", "Canvas is a Swift class (no Objective-C bridge header needed)"))
    checks.append(require_text(canvas_models_text, "enum KDToolMode", "Canvas tool mode enum is extracted to KCDrawingCanvasModels"))
    checks.append(require_text(canvas_models_text, "final class KDStroke", "Canvas stroke model is extracted to KCDrawingCanvasModels"))
    checks.append(require_text(canvas_models_text, "final class KDCanvasState", "Canvas state model is extracted to KCDrawingCanvasModels"))
    checks.append(require_text(canvas_models_text, "final class KDStickerView", "Canvas sticker view model is extracted to KCDrawingCanvasModels"))
    checks.append(forbid_text(canvas_text, "final class KDStroke", "Canvas view no longer owns the stroke model type"))
    checks.append(forbid_text(canvas_text, "final class KDCanvasState", "Canvas view no longer owns the canvas state model type"))
    checks.append(forbid_text(canvas_text, "final class KDStickerView", "Canvas view no longer owns the sticker view model type"))
    checks.append(require_text(drawing_bridge_text, "KCBitmapBuffer(cgImage:", "Flood fill bridge uses Swift bitmap buffer"))
    checks.append(require_text(drawing_bridge_text, "KCFloodFillEngine.fill(", "Flood fill bridge calls the Swift engine"))
    checks.append(require_text(drawing_bridge_text, "KCImagePixelSampler.sample(", "Color sampling bridge calls the single-pixel Swift sampler"))
    checks.append(require_text(drawing_bridge_text, "KCPressureModel.normalized(", "Pressure bridge calls the Swift model"))
    checks.append(require_text(drawing_bridge_text, "guard let buffer = KCBitmapBuffer(cgImage:", "Swift bridge validates CGImage input before fill"))
    checks.append(require_text(drawing_bridge_text, "return UIColor(", "Swift bridge returns UIKit color objects"))
    checks.append(require_text(bitmap_buffer_text, "public init?(cgImage: CGImage)", "Swift bitmap buffer can decode CGImage input"))
    checks.append(require_text(flood_fill_text, "public enum KCFloodFillEngine", "Flood fill engine is implemented in Swift"))
    checks.append(require_text(flood_fill_text, "guard width <= Int.max / height", "Swift flood fill guards pixel-count multiplication overflow"))
    checks.append(require_text(flood_fill_text, "let pixelCount = width * height", "Swift flood fill computes pixel count after overflow guard"))
    checks.append(require_regex(flood_fill_text, r"let seedColor = buffer\.pixel[\s\S]*guard seedColor != fillColor else \{ return 0 \}", "Swift flood fill short-circuits no-op fills before allocating traversal buffers"))
    checks.append(require_text(flood_fill_text, "var visited = [Bool]", "Swift flood fill tracks visited pixels"))
    checks.append(require_text(flood_fill_text, "var queue = [Int]()", "Swift flood fill uses an indexed queue"))
    checks.append(require_text(color_sampler_text, "public enum KCColorSampler", "Buffer color sampler is implemented in Swift"))
    checks.append(require_text(image_pixel_sampler_text, "public enum KCImagePixelSampler", "CGImage single-pixel sampler is implemented in Swift"))
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
    checks.append(require_text(line_art_picker_text, "final class KCLineArtPickerViewController: UIViewController", "Line-art picker UI is extracted to KCLineArtPickerViewController"))
    checks.append(require_text(line_art_picker_text, "typealias SelectionHandler", "Line-art picker exposes a selection callback"))
    checks.append(require_text(line_art_picker_text, "preferredContentSize = CGSize(width: 450.0, height: 420.0)", "Line-art picker keeps the existing popover size"))
    checks.append(require_text(line_art_picker_text, 'view.accessibilityIdentifier = "line-art.picker"', "Line-art picker keeps the automation identifier"))
    checks.append(require_text(line_art_picker_text, "let columns = 2", "Line-art picker keeps the two-column grid"))
    checks.append(require_text(line_art_picker_text, "func lineArtPreviewButton(for item: KCLineArtItem, index: Int) -> UIButton", "Line-art preview button creation lives in the picker view controller"))
    checks.append(require_text(main_text, "private(set) lazy var lineArtFeature: KCLineArtFeature", "Main view controller owns a line-art feature instance"))
    checks.append(require_text(main_text, "self.lineArtFeature.makeLineArtItems()", "Main view controller delegates line-art item creation to KCLineArtFeature"))
    checks.append(require_text(main_text, "KCLineArtPickerViewController(", "Main view controller presents the dedicated line-art picker"))
    checks.append(require_text(main_text, "self.loadLineArtItem(item)", "Line-art picker selection still loads the item through the main controller"))
    checks.append(require_text(main_text, "self.lineArtFeature.lineArtImage(for: item, canvasSize: canvasSize)", "Main view controller delegates line-art canvas rendering to KCLineArtFeature"))
    checks.append(forbid_text(main_text, "let picker = UIViewController()", "Line-art picker is no longer an anonymous UIViewController in the main controller"))
    checks.append(forbid_text(main_text, "func lineArtPreviewButtonForItem", "Line-art preview button creation is no longer owned by the main view controller"))
    checks.append(forbid_text(main_text, "#selector(didTapLineArtPreviewButton", "Line-art preview tap handling is no longer target-action in the main view controller"))
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
    checks.append(require_regex(brush_sticker_panel_text, r'button\.setImage\(categoryImage, for: \.normal\)[\s\S]*button\.accessibilityLabel = stickerCategoryAccessibilityProvider\(category\)', "Sticker category buttons are icon-first with localized accessibility labels"))
    # T026: tool menus/titles/hints are localized through KCL10n; the key English hardcodes
    # must not return to user-visible UI paths, and the controller must route through KCL10n.
    checks.append(require_regex(main_text, r"KCL10n\.", "Main view controller routes user-visible text through the KCL10n localization entry"))
    for hardcoded_top_label in [
        'applyAccessibilityLabel("Palette"',
        'applyAccessibilityLabel("New Canvas"',
        'applyAccessibilityLabel("Undo"',
        'applyAccessibilityLabel("Redo"',
    ]:
        checks.append(forbid_text(main_text, hardcoded_top_label, f"Top toolbar accessibility text is not hardcoded: {hardcoded_top_label}"))
    checks.append(require_text(main_text, "self.applyAccessibilityLabel(KCL10n.paletteTitle", "Top palette accessibility text is localized"))
    checks.append(require_text(main_text, "self.applyAccessibilityLabel(KCL10n.newCanvasTitle", "Top new-canvas accessibility text is localized"))
    checks.append(require_text(main_text, "self.applyAccessibilityLabel(KCL10n.undoTitle", "Top undo accessibility text is localized"))
    checks.append(require_text(main_text, "self.applyAccessibilityLabel(KCL10n.redoTitle", "Top redo accessibility text is localized"))
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
    checks.append(require_text(canvas_feature_text, "saveButton.isEnabled = true", "Save button remains tappable so empty-canvas save can show localized feedback"))
    checks.append(require_regex(canvas_feature_text, r"KCEditorVisualStyle\.applyActionButtonAvailability\([\s\S]*to: saveButton[\s\S]*enabled: state\.canSave[\s\S]*saveButton\.isEnabled = true", "Empty-canvas save is visually muted but remains tappable for feedback"))
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
    checks.append(require_text(canvas_history_store_text, "final class KCCanvasHistoryStore", "Canvas undo/redo history store is extracted"))
    checks.append(require_text(canvas_history_store_text, "maximumStates: Int = 48", "Canvas history store keeps the bounded capacity"))
    checks.append(require_text(canvas_history_store_text, "func trimHistoryStack", "Undo/redo history stacks are trimmed"))
    checks.append(require_text(canvas_text, "private let historyStore = KCCanvasHistoryStore()", "Canvas view delegates undo/redo stacks to KCCanvasHistoryStore"))
    checks.append(forbid_text(canvas_text, "private var undoStates", "Canvas view no longer owns the undo stack array"))
    checks.append(forbid_text(canvas_text, "private var redoStates", "Canvas view no longer owns the redo stack array"))
    checks.append(require_text(canvas_text, "func startBlankCanvas", "Canvas exposes clean blank-session reset"))
    checks.append(require_regex(canvas_text, r"func startBlankCanvas[\s\S]*resetCanvasContents\(\)[\s\S]*clearHistoryStacks\(\)", "New blank canvas clears content and undo/redo history"))
    checks.append(require_regex(canvas_text, r"func restoreCanvas[\s\S]*clearHistoryStacks\(\)", "Restoring/opening artwork clears undo/redo history"))
    checks.append(require_regex(canvas_text, r"func replaceCanvas[\s\S]*resetCanvasContents\(\)[\s\S]*clearHistoryStacks\(\)", "Imported photos start a clean canvas session"))
    checks.append(require_regex(canvas_text, r"func loadLineArtImage[\s\S]*resetCanvasContents\(\)[\s\S]*clearHistoryStacks\(\)", "Line-art templates start a clean canvas session"))
    checks.append(require_regex(canvas_text, r"func clearHistoryStacks[\s\S]*historyStore\.clear\(\)", "Canvas history stacks can be fully cleared"))
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
    checks.append(require_text(canvas_feature_text, "func applyActionButtonAppearance(", "Canvas Feature applies undo/redo/save button appearance"))
    checks.append(require_text(canvas_feature_text, "undoButton.isEnabled = state.canUndo", "Canvas Feature applies undo availability"))
    checks.append(require_text(canvas_feature_text, "redoButton.isEnabled = state.canRedo", "Canvas Feature applies redo availability"))
    checks.append(require_text(canvas_feature_text, "saveButton.isEnabled = true", "Canvas Feature keeps save action tappable for empty-canvas feedback"))
    checks.append(require_text(canvas_feature_text, "KCEditorVisualStyle.applyActionButtonAvailability", "Canvas action buttons reuse shared availability styling"))
    checks.append(require_text(canvas_feature_text, "KCEditorVisualStyle.saveActionColor", "Save button uses centralized action color token"))
    checks.append(forbid_text(canvas_feature_text, "UIColor(white: 1.0, alpha: 0.76)", "Canvas action buttons do not duplicate enabled background color"))
    checks.append(forbid_text(canvas_feature_text, "UIColor(red: 0.54, green: 0.80, blue: 0.98", "Canvas action buttons do not duplicate save action color"))
    checks.append(require_text(main_text, "private(set) lazy var canvasFeature: KCCanvasFeature", "Main view controller owns a Canvas Feature instance"))
    checks.append(require_text(main_text, "self.canvasFeature.makeCanvasView(delegate: self)", "Main view controller delegates canvas creation to KCCanvasFeature"))
    checks.append(require_regex(main_text, r"func refreshActionButtons[\s\S]*self\.canvasFeature\.actionState\(for: self\.canvasView\)[\s\S]*self\.canvasFeature\.applyActionButtonAppearance", "Save button availability is delegated to KCCanvasFeature"))
    checks.append(forbid_text(main_text, "self.saveButton.isEnabled = actionState.canSave", "Main view controller no longer applies save-button availability directly"))
    checks.append(forbid_text(main_text, "self.undoButton.isEnabled = actionState.canUndo", "Main view controller no longer applies undo-button availability directly"))
    checks.append(require_regex(main_text, r"func openSession[\s\S]*preserveUnsavedActiveSessionDraftIfNeeded\(\)[\s\S]*self\.sessionStore\.clearDraft\(\)", "Opening another history item preserves dirty edits without clearing their draft"))
    checks.append(require_regex(main_text, r"func preserveUnsavedActiveSessionDraftIfNeeded[\s\S]*self\.sessionStore\.saveDraftImage\(snapshot\)[\s\S]*return true", "Dirty active saved sessions can be synchronously preserved as draft"))
    checks.append(require_regex(main_text, r"func didTapNewCanvas[\s\S]*self\.suppressNextDraftSave = true[\s\S]*self\.canvasView\.startBlankCanvas\(\)", "New canvas starts a clean blank session without creating a draft"))
    checks.append(require_regex(main_text, r"func didTapDeleteLatestSession[\s\S]*shouldDeleteDraft[\s\S]*self\.suppressNextDraftSave = true[\s\S]*self\.canvasView\.startBlankCanvas\(\)", "Deleting the active draft starts a clean blank session"))
    checks.append(require_regex(main_text, r"func saveDraftIfNeeded[\s\S]*self\.activeSession != nil && !self\.activeSessionHasUnsavedChanges[\s\S]*return[\s\S]*self\.canvasFeature\.hasVisibleContent\(self\.canvasView\)", "Draft autosave skips only unchanged saved sessions"))
    checks.append(require_text(line_art_picker_text, "line-art.picker", "Line-art picker has an automation identifier"))
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
    checks.append(require_text(canvas_text, "func applyStickerSelectedAppearance", "Sticker selected-state feedback is centralized in the canvas view"))
    checks.append(require_text(canvas_text, "KCEditorVisualStyle.saveActionColor", "Sticker selected-state border reuses shared editor accent token"))
    checks.append(require_regex(canvas_text, r"func selectStickerView[\s\S]*applyStickerSelectedAppearance", "Selecting a sticker applies visible selected-state feedback"))
    checks.append(require_regex(canvas_text, r"func deselectSticker[\s\S]*applyStickerIdleAppearance", "Deselecting a sticker restores idle feedback"))
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
        with APP_FILE_PATHS["Info.plist"].open("rb") as plist_file:
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
        APP_FILE_PATHS["Assets.xcassets"] / "Contents.json",
        APP_FILE_PATHS["Assets.xcassets"] / "AppIcon.appiconset" / "Contents.json",
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
    checks.append(require_text(pbx_text, 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";', "Debug Swift compilation conditions define DEBUG"))
    checks.extend(app_icon_assets_exist(APP_FILE_PATHS["Assets.xcassets"] / "AppIcon.appiconset" / "Contents.json"))
    checks.append(project_file_references_exist(pbx_text))
    checks.append(source_files_in_build_phase(pbx_text))
    checks.append(resources_in_build_phase(pbx_text))
    checks.extend(shared_scheme_is_valid(ROOT / "KidCanvas.xcodeproj" / "xcshareddata" / "xcschemes" / "KidCanvas.xcscheme"))

    # T014 OC-zero governance: the app target is fully Swift — NO business .m
    # files may remain (legacy KDSessionStore/KDArtworkSession removed in
    # step 2; canvas/controller migrated to Swift in step 3-4).
    oc_whitelist = set()
    removed_legacy_objc = {"KDSessionStore.m", "KDArtworkSession.m", "KDMainViewController.m", "KDDrawingCanvasView.m"}
    remaining_objc = {p.name for p in APP_ROOT.rglob("*.m") if not p.name.startswith("._")}
    unexpected_objc = remaining_objc - oc_whitelist
    still_present_legacy = removed_legacy_objc & remaining_objc
    checks.append(ok(f"App target has no Objective-C .m sources ({sorted(remaining_objc) or 'none'})")
                  if not unexpected_objc and not still_present_legacy
                  else fail("Unexpected/legacy OC files remain: " + ", ".join(sorted(unexpected_objc | still_present_legacy))))
    checks.append(ok("All legacy/business OC .m removed (KDMainViewController/KDDrawingCanvasView/KDSessionStore/KDArtworkSession)")
                  if not still_present_legacy
                  else fail("Legacy OC files still present: " + ", ".join(sorted(still_present_legacy))))
    # T015: bridging header removed entirely (app target fully Swift, no OC↔Swift boundary).
    _bridging_header = APP_ROOT / "KidCanvas-Bridging-Header.h"
    checks.append(ok("Bridging header removed (app target fully Swift)")
                  if not _bridging_header.exists()
                  else fail("Bridging header still present: " + _bridging_header.name))

    objc_files = [
        APP_FILE_PATHS["KCMainViewController.swift"],
        APP_FILE_PATHS["KCMainViewController+LayoutMetrics.swift"],
        APP_FILE_PATHS["KCMainViewController+PanelCollapse.swift"],
        APP_FILE_PATHS["KCMainViewController+ToolSelection.swift"],
        APP_FILE_PATHS["KCDrawingCanvasView.swift"],
    ]
    for path in objc_files:
        if path.exists():
            checks.append(balanced_text(path, [("braces", "{", "}"), ("parentheses", "(", ")")]))
        else:
            checks.append(fail(f"{path.relative_to(ROOT)} is missing"))

    main_text = "\n".join([
        APP_FILE_PATHS["KCMainViewController.swift"].read_text(encoding="utf-8"),
        APP_FILE_PATHS["KCMainViewController+LayoutMetrics.swift"].read_text(encoding="utf-8"),
        APP_FILE_PATHS["KCMainViewController+PanelCollapse.swift"].read_text(encoding="utf-8"),
        APP_FILE_PATHS["KCMainViewController+ToolSelection.swift"].read_text(encoding="utf-8"),
    ])
    canvas_text = APP_FILE_PATHS["KCDrawingCanvasView.swift"].read_text(encoding="utf-8")
    canvas_models_text = APP_FILE_PATHS["KCDrawingCanvasModels.swift"].read_text(encoding="utf-8")
    canvas_history_store_text = APP_FILE_PATHS["KCCanvasHistoryStore.swift"].read_text(encoding="utf-8")
    session_store_bridge_text = APP_FILE_PATHS["KCSessionService.swift"].read_text(encoding="utf-8")
    kc_session_store_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCSessionPersistence" / "KCSessionStore.swift").read_text(encoding="utf-8")
    kc_artwork_session_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCArtworkSession.swift").read_text(encoding="utf-8")
    scene_text = APP_FILE_PATHS["SceneDelegate.swift"].read_text(encoding="utf-8")
    header_text = APP_FILE_PATHS["KCDrawingCanvasView.swift"].read_text(encoding="utf-8")
    drawing_bridge_text = APP_FILE_PATHS["KCDrawingEngineAdapter.swift"].read_text(encoding="utf-8")
    bitmap_buffer_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCBitmapBuffer.swift").read_text(encoding="utf-8")
    flood_fill_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCFloodFillEngine.swift").read_text(encoding="utf-8")
    color_sampler_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCColorSampler.swift").read_text(encoding="utf-8")
    image_pixel_sampler_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCImagePixelSampler.swift").read_text(encoding="utf-8")
    pressure_model_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCPressureModel.swift").read_text(encoding="utf-8")
    crayon_grain_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCCrayonGrain.swift").read_text(encoding="utf-8")
    sticker_constraints_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCStickerConstraints.swift").read_text(encoding="utf-8")
    history_paging_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCHistoryPaging.swift").read_text(encoding="utf-8")
    line_art_drawing_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDrawingEngine" / "KCLineArtDrawing.swift").read_text(encoding="utf-8")
    composition_root_text = APP_FILE_PATHS["KCAppCompositionRoot.swift"].read_text(encoding="utf-8")
    catalog_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCContentCatalog" / "Resources" / "content.json").read_text(encoding="utf-8")
    content_picker_feature_text = APP_FILE_PATHS["KCContentPickerFeature.swift"].read_text(encoding="utf-8")
    canvas_feature_text = APP_FILE_PATHS["KCCanvasFeature.swift"].read_text(encoding="utf-8")
    line_art_feature_text = APP_FILE_PATHS["KCLineArtFeature.swift"].read_text(encoding="utf-8")
    line_art_picker_path = APP_FILE_PATHS["KCLineArtPickerViewController.swift"]
    line_art_picker_text = line_art_picker_path.read_text(encoding="utf-8") if line_art_picker_path.exists() else ""
    device_layout_metrics_text = APP_FILE_PATHS["KCDeviceLayoutMetrics.swift"].read_text(encoding="utf-8")
    editor_ui_factory_text = APP_FILE_PATHS["KCEditorUIFactory.swift"].read_text(encoding="utf-8")
    press_feedback_path = APP_FILE_PATHS["KCPressFeedbackController.swift"]
    press_feedback_text = press_feedback_path.read_text(encoding="utf-8") if press_feedback_path.exists() else ""
    toast_presenter_path = APP_FILE_PATHS["KCToastPresenter.swift"]
    toast_presenter_text = toast_presenter_path.read_text(encoding="utf-8") if toast_presenter_path.exists() else ""
    color_palette_renderer_path = APP_FILE_PATHS["KCColorPalettePanelRenderer.swift"]
    color_palette_renderer_text = color_palette_renderer_path.read_text(encoding="utf-8") if color_palette_renderer_path.exists() else ""
    brush_sticker_panel_path = APP_FILE_PATHS["KCBrushStickerPanelView.swift"]
    brush_sticker_panel_text = brush_sticker_panel_path.read_text(encoding="utf-8") if brush_sticker_panel_path.exists() else ""
    brush_dock_feature_text = APP_FILE_PATHS["KCBrushDockFeature.swift"].read_text(encoding="utf-8")
    eraser_controls_feature_text = APP_FILE_PATHS["KCEraserControlsFeature.swift"].read_text(encoding="utf-8")
    tool_rail_feature_path = APP_FILE_PATHS["KCToolRailFeature.swift"]
    tool_rail_feature_text = tool_rail_feature_path.read_text(encoding="utf-8") if tool_rail_feature_path.exists() else ""
    kc_content_picker_layout_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCContentPickerLayout.swift").read_text(encoding="utf-8")
    kc_recent_color_queue_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCRecentColorQueue.swift").read_text(encoding="utf-8")
    kc_sticker_category_mapping_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCStickerCategoryMapping.swift").read_text(encoding="utf-8")
    editor_panels_feature_text = APP_FILE_PATHS["KCEditorPanelsFeature.swift"].read_text(encoding="utf-8")
    kc_editor_panels_collapse_state_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCEditorPanelsCollapseState.swift").read_text(encoding="utf-8")
    history_feature_text = APP_FILE_PATHS["KCHistoryFeature.swift"].read_text(encoding="utf-8")
    kc_history_thumb_status_text = (ROOT / "Packages" / "KidCanvasModules" / "Sources" / "KCDomain" / "KCHistoryThumbStatus.swift").read_text(encoding="utf-8")
    preview_text = (ROOT / "docs" / "product" / "mockups" / "ui-preview.html").read_text(encoding="utf-8")
    checks.extend(spm_module_governance_checks())
    checks.extend(app_structure_checks())
    checks.extend(apple_double_checks())
    checks.extend(architecture_reality_checks())
    checks.extend(module_documentation_checks())
    checks.extend(delivery_acceptance_checks())
    checks.extend(product_stamp_naming_checks())
    checks.extend(app_feature_checks(
        main_text,
        canvas_text,
        canvas_models_text,
        canvas_history_store_text,
        session_store_bridge_text,
        kc_session_store_text,
        kc_artwork_session_text,
        scene_text,
        header_text,
        drawing_bridge_text,
        bitmap_buffer_text,
        flood_fill_text,
        color_sampler_text,
        image_pixel_sampler_text,
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
        line_art_picker_text,
        device_layout_metrics_text,
        editor_ui_factory_text,
        press_feedback_text,
        toast_presenter_text,
        color_palette_renderer_text,
        brush_sticker_panel_text,
        brush_dock_feature_text,
        eraser_controls_feature_text,
        tool_rail_feature_text,
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
        APP_ROOT / "Localization" / "zh-Hans.lproj" / "Localizable.strings",
        APP_ROOT / "Localization" / "en.lproj" / "Localizable.strings",
        APP_ROOT / "Localization" / "zh-Hans.lproj" / "InfoPlist.strings",
        APP_ROOT / "Localization" / "en.lproj" / "InfoPlist.strings",
        APP_FILE_PATHS["KCLocalizedStrings.swift"],
        pbx_text,
    ))

    if all(checks):
        print("Validation passed.")
        return 0

    print("Validation failed.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
