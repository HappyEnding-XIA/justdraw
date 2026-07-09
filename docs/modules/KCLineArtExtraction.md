# KCLineArtExtraction

离线图片生成线稿（T101）：把相册/拍照图片在本地转成可填色位图线稿。模型与协议在 `Packages/KidCanvasModules/Sources/KCDomain/KCLineArtExtraction.swift`（UIKit-free），Core Image pipeline 核心在 `Packages/KidCanvasModules/Sources/KCDrawingEngine/KCLineArtExtractor.swift`；App 层（`KCMainViewController+ImagePicking.swift`）只负责系统图片输入、结果确认与保存。

## 1. 职责

- 定义 `KCLineArtExtractionResult`（位图线稿 PNG + 缩略图 JPEG + `KCLineArtQuality`）与 `KCLineArtExtracting` 协议（输入图片 `Data`，输出结果或 `nil`）。
- `KCLineArtQuality` 三级（good/marginal/poor）：`poor` 表示该图片可能不适合（过暗/过糊/边缘过少），由 App 层提示并允许重试/取消；`isUsable` 表示可使用（非 poor）。
- `KCLineArtExtractor` 离线 pipeline：方向归一化（CIImage 自带）→ 尺寸压缩（≤1600）→ 灰度化（`CIPhotoEffectMono`）→ 降噪（`CINoiseReduction`）→ 边缘检测（`CIEdges`）→ 反相（边缘变深线，`CIColorInvert`）→ 高对比近似阈值化（`CIColorControls`）→ 白底位图输出（`CGImage` → ImageIO PNG/JPEG）。
- 质量评估基于输入灰度的亮度均值与标准差：过暗/过亮（均值越界）或过均匀（标准差过低，无细节/模糊）判 poor；细节偏少判 marginal；否则 good。
- 结果确认流：使用这张线稿（保存到我的线稿 `.photoExtraction` 并打开）/ 重新生成（重选）/ 取消（不改变画布与我的线稿）。poor 时不允许直接“使用”，强制重选/取消。

## 2. 边界

- 不上云端、不上传儿童照片、不依赖 AI/Core ML（仅 Core Image 离线滤镜；MVP）。
- pipeline 核心保持 UIKit-free（`CIImage`/`CIFilter`/`CGImage`/ImageIO），可在 SPM 单测。
- 只输出位图线稿，不做矢量化；生成结果复用 T099 我的线稿存储生命周期（`KCCustomLineArtService.saveExtraction`，`sourceKind = .photoExtraction`）。
- 不直接覆盖当前画布：用户确认后才保存并打开；确认前不动画布与我的线稿。
- 能力边界：卡通图、绘本页、白底图、简单实物优先；复杂真实照片给“可能不理想”反馈，不承诺高质量。

## 3. 对外 API / 接入路径

- `KCLineArtExtracting.extract(from: Data) -> KCLineArtExtractionResult?`（KCDomain）。
- `KCLineArtExtractor`（KCDrawingEngine）：`init(context:)` + `extract(from:)`。
- `KCCustomLineArtService.saveExtraction(_:sourceSessionId:completion:)`（App）：复用结果 PNG/缩略图，`sourceKind = .photoExtraction`。
- 当前接入：内容库“我的线稿”分区“从照片生成线稿”入口（`KCMyLineArtGridView.onGenerateFromPhoto`）→ `didTapGenerateLineArtFromPhoto` → 相册导入（`pendingImageImportIntent = .generateLineArt`）→ `generateLineArt(from:)` 后台提取 → `presentLineArtExtractionResult` 确认 → `useGeneratedLineArt` 保存并打开。

## 4. 禁止回流规则

- 禁止把 UIKit 类型下沉到 `KCLineArtExtractionResult` / `KCLineArtExtracting`；模型与协议必须 UIKit-free。
- 禁止使用网络（`URLSession` 等）/云端 AI 上传图片；必须纯离线 Core Image。
- 禁止生成结果未经确认就覆盖当前画布或写入我的线稿；必须先经“使用这张线稿/重新生成/取消”确认。
- 禁止把照片生成线稿的 pipeline 混入历史/草稿/我的线稿存储磁盘 schema；只复用 `KCCustomLineArtService.saveExtraction`。
- 禁止对 poor 质量图片直接“使用”；必须强制重选/取消并给出“这张图片可能不适合”提示。
- 禁止承诺复杂真实照片的高质量；必须按质量分级给反馈，不静默失败。
