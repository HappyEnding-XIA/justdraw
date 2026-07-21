# 玻璃材质视觉基线（T109）

> 状态：✅ 设计基线 + G1-G5 已实现（2026-07-21，Codex 收口）。G1（系统液态玻璃 `UIGlassEffect`）、G2（假玻璃→真玻璃并解除 history 嵌套遮挡）、G3（按钮玻璃化）、G4（尺寸面板减层）和 G5（画纸留边 + 轻工作台氛围光）均已完成；代码通过全量自动验收，双端 runtime 验收口径已同步。
>
> 设计来源（唯一真源）：`docs/product/mockups/ui-preview.html` / `ui-preview.svg`（PRD `docs/product/prd.md` §视觉语言明确指向）。本基线把 mockup 的 CSS 材质参数翻译为 iOS 实现口径，并盘点当前代码与目标的差距。

## 1. 背景与目标

PRD（§视觉语言）要求：各类**按钮组、菜单、浮层面板和底部 Dock** 优先采用 iOS 系统风格玻璃材质——半透明、轻模糊、轻高光、柔和边界、背景透出；玻璃服务于**层级区分**，不能过度透明到影响图标、文字、色块、画布内容识别；**选中态按钮保留高饱和色块**，但需与玻璃容器协调。

T109 目标：
1. 以 mockup 为准，形成**唯一的玻璃 token 基线**（材质、底色叠层、边界、阴影、圆角、按钮）。
2. 盘点当前各表面材质现状，列出不一致与“假玻璃”（半透明实色无模糊）。
3. 明确**哪些表面走玻璃、哪些保持实色**（保证儿童识别）。
4. 给出后续编码任务的优先级，以及人工 + runtime 验收口径。

## 2. 唯一真源：mockup 的材质口径

`ui-preview.html` 的 CSS 变量与组件规则（节选）：

| Token（CSS） | 值 | 用途 |
|---|---|---|
| `--glass` | `rgba(255, 251, 246, 0.72)` | 容器玻璃底色（暖奶白） |
| `--glass-strong` | `rgba(255, 255, 255, 0.88)` | 需要更高对比的玻璃（弹层/强容器） |
| `--line` | `rgba(41, 56, 74, 0.09)` | 细分隔线 |
| `--shadow-xl/lg/md` | `rgba(125, 91, 49, 0.18 / 0.14 / 0.12)` | 暖棕阴影 |
| 玻璃容器 | `backdrop-filter: blur(24px) saturate(1.15)`；`border: 1px solid rgba(255,255,255,0.76)`；`box-shadow: var(--shadow-lg)` | 面板/工具栏/Dock |
| 圆角 | 容器 `30px`，左轨 `34px`，底部 Dock `36px`，面板 `30px` | — |
| 按钮（icon/tool/swatch…） | `background: rgba(255,255,255,0.82)`；`box-shadow: inset 0 1px 0 rgba(255,255,255,0.76), var(--shadow-md)`；圆角 `18px` | 玻璃上的次级控件：半透明白 + 顶部内高光 |
| 强调/选中按钮（`.brand`） | `linear-gradient(180deg, #f7dc84, #eec463)` | 高饱和暖黄，实色 |

要点：**容器=真玻璃（backdrop blur + 暖底 + 白高光描边 + 暖棕阴影 + 大圆角）；按钮=半透明白 0.82 + 顶部内高光（拟玻璃光泽）；选中/强调=实色暖黄**。

## 3. 统一玻璃 token 基线（iOS 实现口径）

集中收敛到 `KCEditorVisualStyle` / `KCEditorUIFactory`（见 §7 任务 G1）。所有玻璃表面必须经同一入口，禁止再内联散写 `UIVisualEffectView`。

### 3.1 容器玻璃（`applyFloatingPanelChrome`，目标值）

| 维度 | 目标值（对齐 mockup） | 当前值 | 差距 |
|---|---|---|---|
| 材质 | `UIBlurEffect(.systemThinMaterialLight)` | 同 | 一致（iOS 无自定义 blur 半径，`.systemThinMaterialLight` 最接近 `blur(24) saturate(1.15)`） |
| 底色叠层（contentView） | `UIColor(red:1.0, green:0.984, blue:0.961, alpha:0.34)`（暖奶白，对齐 `--glass`） | `UIColor(white:1.0, alpha:0.34)`（中性白） | 暖度不足 → 调暖 |
| 边界 | `UIColor(white:1.0, alpha:0.76)`，`borderWidth 1.0`（白高光） | `UIColor(red:0.17,green:0.22,blue:0.30,alpha:0.08)`，`1.2`（暗细线） | 由暗线改白高光 |
| 圆角 | 容器 `30`，左轨 `34`，底部 Dock `36` | 统一 `26` | 偏小且无分级 → 分级到 30/34/36 |
| 阴影色 | `UIColor(red:0.49,green:0.357,blue:0.192,alpha:1)`（暖棕 125/91/49） | `UIColor(red:0.37,green:0.32,blue:0.24)` | 色相偏冷 → 调暖棕 |
| 阴影参数 | `opacity 0.14`，`radius 18`，`offset (0,8)` | 同 | 一致 |

> `--glass-strong`（0.88）用于弹层/Toast 等需更高对比处：底色叠层 alpha 提到约 `0.50`。

### 3.2 按钮（玻璃上的次级控件）

| 维度 | 目标值（对齐 mockup `rgba(255,255,255,0.82)` + inset 高光） | 当前值（`applyRaisedButtonAppearance`） | 差距 |
|---|---|---|---|
| 底色 | `UIColor(white:1.0, alpha:0.82)` | `raisedBackgroundColor = white 0.92` | 偏实 → 降到 0.82 |
| 顶部内高光 | 1pt 顶部内白光（`inset 0 1px 0 rgba(255,255,255,0.76)`） | 无 | 缺光泽 → 补内高光（可选内描边/子层） |
| 圆角 | `18` | 多为 `18-20` | 基本一致 |
| 阴影 | `shadow-md`（`0.10/0.12`，暖棕） | `0.05-0.10` | 基本一致 |

### 3.3 选中/强调态（保持实色）

- 选中按钮：`accentColor = UIColor(red:0.97,green:0.86,blue:0.48)`（≈ `#f7dc84`），实色；mockup 为渐变 `#f7dc84→#eec463`，**渐变为可选增强**（非本轮必需）。
- 高饱和色块（调色盘色样、色板选中）：**保持实色**，不走玻璃（儿童需准确辨色，玻璃会偏色）。
- 禁用态：`disabledBackgroundColor`（white 0.68）+ `disabledAlpha 0.56`，保持实色压暗。

## 4. 实施前盘点（历史现状）

中央样式系统：`KCEditorVisualStyle`（token + chrome 方法）与 `KCEditorUIFactory`（控件工厂），均位于 `KidCanvas/DesignSystem/KCEditorUIFactory.swift`。容器玻璃经 `floatingPanel()`（`UIBlurEffect(.systemThinMaterialLight)`）→ `applyFloatingPanelChrome`；按钮经 `applyRaisedButtonAppearance`（实色）。

| # | 表面 | 真模糊？ | 现状 | 位置 |
|---|---|---|---|---|
| 1 | 顶部左/右浮层、左轨、底部 Dock（`collapsiblePanels[0/1/2/4]`） | 是 | `floatingPanel()` → `applyFloatingPanelChrome` | `KCMainViewController.swift:282-284,288`；chrome `KCEditorUIFactory.swift:29-44,175` |
| 2 | 右侧参数面板（`collapsiblePanels[3]`） | 容器否/子面板是 | 裸 `UIScrollView` 无 chrome；其 `colorsPanel`/`sizePanel` 各为 `floatingPanel()` | `KCMainViewController.swift:289,285-286` |
| 3 | 折叠按钮 / 工具状态 chip | 否（半透明实色） | `applyRaisedButtonAppearance`（`compactBackgroundColor` 0.88） | `KCEditorUIFactory.swift:306-340` |
| 4 | 内容库卡片（`KCContentLibraryPanelView`） | **否（假玻璃）** | 内联：深色遮罩 + `cardView` white 0.96、圆角 26、border、阴影 0.30；不经任何 chrome 方法 | `KCContentLibraryPanelView.swift:69,75-83` |
| 5 | 线稿选择器（`KCLineArtPickerViewController`） | 是（路径不同） | 内联 `UIVisualEffectView`、圆角 28、无边界无阴影 | `KCLineArtPickerViewController.swift:47-50` |
| 6 | Toast（`KCToastPresenter`） | 是（路径不同） | 内联 `UIVisualEffectView`、圆角 24、白边 0.72、无阴影 | `KCToastPresenter.swift:70-75` |
| 7 | 线稿提取结果卡（`KCLineArtExtractionResultCard`） | **否（假玻璃）** | 内联：遮罩 + `cardView` white 0.98、圆角 24、border、阴影 0.22 | `KCMainViewController+ImagePicking.swift:399,405-413` |
| 8 | 系统 alert/actionSheet、系统取色器 popover | 系统 | `UIAlertController` / `UIColorPickerViewController` | 多处 |
| 9 | 画笔/印章/橡皮参数子层（`KCBrushStickerPanelView`） | 宿主玻璃 + 额外半透明层 | 在 `sizePanel` 玻璃上再叠 `shell` white 0.58、`sizePreview` white 0.72 | `KCBrushStickerPanelView.swift:69-76,90-97` |
| 10 | 按钮（icon/tool/swatch/history…） | 否（实色 0.92） | `applyRaisedButtonAppearance` | `KCEditorUIFactory.swift:46-63` 等 |

## 5. 实施前差距与不一致

1. **三套玻璃圆角**：浮层 26 / 线稿选择器 28 / Toast 24 → 应统一并按表面分级（§3.1）。
2. **三条玻璃应用路径**（同一 `.systemThinMaterialLight`）：(a) `applyFloatingPanelChrome`（带边/带阴影/带 0.34 底色）；(b) 线稿选择器内联（无边无阴影）；(c) Toast 内联（带边无阴影）→ 收敛为**单一入口**。
3. **同类弹层玻璃/实色分裂**：线稿选择器、Toast 走真模糊，而视觉同级的**全屏弹层——内容库卡片（0.96）、线稿提取结果卡（0.98）——是近不透明实色**（假玻璃）。
4. **`collapsiblePanels[3]` 是唯一不是玻璃的折叠面板**（裸 scroll view，chrome 全靠子面板）。
5. **嵌套模糊被遮挡**：`historyPanel`（真模糊）被放进内容库 `cardView`（0.96 实色）内，模糊基本被父层遮死。
6. **折叠按钮/chip 实色，而其折叠的面板是玻璃**——同区域材质不统一。
7. **玻璃面板内多余半透明层**：`KCBrushStickerPanelView` 的 `shell`(0.58)/`sizePreview`(0.72) 在玻璃上再叠一层，双重削弱透出感。
8. **按钮偏实、缺光泽**：按钮 0.92 实色，无 mockup 的顶部内高光，与“玻璃上的半透明控件”预期不符。
9. **边界暗线 vs 白高光**：当前玻璃用暗细线（alpha 0.08），mockup 用白高光（0.76）——视觉性格不同。

## 6. 分表面规则：玻璃 vs 实色

**走玻璃（真模糊，统一入口）**：
- 顶部左/右浮层、左工具轨、右侧参数面板及其子面板、底部 Dock。
- 内容库卡片、线稿提取结果卡（由假玻璃改为真玻璃，并解决 §5-5 嵌套遮挡）。
- 线稿选择器、Toast（改走统一 `applyFloatingPanelChrome`，圆角/边界/阴影对齐）。
- 折叠按钮 / 工具状态 chip：由实色改为轻玻璃（与所折叠的玻璃面板统一）。

**保持实色（儿童识别/准确辨色/层级强调）**：
- 选中态按钮、强调按钮（`accentColor` 暖黄；渐变可选）。
- 调色盘色样、高饱和色块（玻璃会偏色，影响选色准确性）。
- 禁用态（压暗实色）。
- 画布纸张/工作台背景（§画布分层，T105 已定）。
- 系统控件（alert、取色器）沿用系统外观。

**已收敛的层级**：`KCBrushStickerPanelView` 已移除额外半透明 `shell`，`sizePreview` 直接使用宿主玻璃面板表面，避免双重削弱。

## 7. 实施优先级与任务拆分（G1-G5 已完成）

| 编号 | 后续任务 | 范围 | 风险 |
|---|---|---|---|
| ✅ G1 | 统一玻璃入口 + 系统液态玻璃（**已实现，自动验收通过，Codex 审核通过**） | `makeGlassEffectView(contentTint:)` 统一入口；iOS 26+ 用 `UIGlassEffect(style: .regular)`（系统液态玻璃），iOS<26 降级 `systemMaterialLight`+暖描边；`applyFloatingPanelChrome` 暖棕投影 + 分级圆角（容器30/左轨34/Dock36）；线稿选择器、Toast 改走统一入口 | 低（集中改 DesignSystem） |
| ✅ G2 | 假玻璃→真玻璃（**已实现**） | `KCContentLibraryPanelView.cardView` 与 `KCLineArtExtractionResultCard.cardView` 由"实色 0.96/0.98 + 暗描边"改为统一玻璃入口（`makeGlassEffectView` + `applyGlassSurface`），`cardView` 自身只承载暖棕投影与圆角，玻璃作子视图铺底置于最后、既有分段/关闭/内容/按钮子控件原样叠在玻璃之上。**顺带解开 `historyPanel` 嵌套遮挡**（父层由 0.96 不透明实色 → 玻璃透出，子层历史玻璃可见） | 中（内容库/弹层可见性，需双端截图验收） |
| ✅ G3 | 按钮玻璃化（**已实现**） | `applyRaisedButtonAppearance` 底色 0.92→0.82，描边改玻璃白高光，并增加顶部 1pt 白色内高光；折叠按钮与工具状态 chip 由 `compactBackgroundColor` 实色改为统一玻璃入口（`makeGlassEffectView` + `applyGlassSurface`） | 低-中（按钮可读性，深/浅画布下点验） |
| ✅ G4 | 减层（已完成） | `KCBrushStickerPanelView` 移除玻璃面板内额外半透明 `shell`，尺寸预览直接落在宿主玻璃面板上 | 低 |
| ✅ G5 | 画纸留边 + 工作台氛围光（已完成） | 画纸屏幕呈现保留安全留边，工作台增加低干扰暖色氛围光；不写入保存图片、历史缩略图或草稿 | 中 |

每个 G* 任务独立提交，各自跑 `layout-safe-area`/`system-ui`/`content-library` runtime 验收不回退 + 双端截图人工确认。

## 8. 验收口径

**人工验收（双端：iPhone 17 Pro / iPad Pro 11 M4，横屏）**：
- 空白画布首屏：所有玻璃浮层/Dock 呈半透明、背景透出、边界为白高光、阴影暖棕柔和；图标/文字清晰。
- 深色/高饱和画布：玻璃透出画布色但不影响内容识别；选中态暖黄实色与玻璃协调。
- 内容库打开：卡片为真玻璃（透出画布），历史分区不出现“模糊被实色遮死”。
- 底部 Dock 各状态（工具切换/禁用）：玻璃一致、禁用态压暗实色。
- 线稿选择器、Toast、线稿提取结果卡：材质与浮层统一（同一圆角分级/边界/阴影）。
- 调色盘色样：保持实色、无偏色。

**runtime 验收（必须不回退）**：
- `scripts/runtime_acceptance_test.sh "<device>" layout-safe-area`（双端）。
- `scripts/runtime_acceptance_test.sh "<device>" system-ui`（双端）。
- `scripts/runtime_acceptance_test.sh "<device>" content-library`（双端）。
- 若 G3 改按钮：补 `drawing-tools` runtime 验收不回退。

## 9. 边界（不做什么）

- 不改变画布内容、保存格式、历史/草稿 schema、导出尺寸（与 T105/T106 一致）。
- 不把调色盘色样、选中/强调按钮改玻璃（保实色，§6）。
- 不引入自定义 CIFilter 模糊或 `UIVisualEffectView` 之外的模糊实现；统一用系统 `.systemThinMaterialLight`。
- 不为玻璃新增第二个样式系统；一切收敛进 `KCEditorVisualStyle` / `KCEditorUIFactory`。
- **G1-G5 已实现并已提交**：G1-G3 由 `9fc5660`、`e76624c` 等提交落地，G4/G5 随 `8c145d5` 收口；自动验收与文档同步完成。后续仅在出现新的视觉问题时按截图另开任务。
