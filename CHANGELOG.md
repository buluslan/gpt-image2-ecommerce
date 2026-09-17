# Changelog

## 0.3.2

- 更正 0.3.1 的模型归属描述：Flare 与 Sunburst 是 OpenAI 官方 GPT-Image-2.5 模型，不是服务商别名
- 恢复官方双模型定位，并保留第三方兼容端点可能尚未开放模型的运行时提醒

## 0.3.1

- 收紧模型能力与价格表述，避免把端点差异写成无条件保证
- 将“平台合规”收紧为技术预检与动态风险复核，明确 C2PA/OCR 的检测边界
- 标明视觉 eval 输入资产仍为占位，并补齐离线 smoke test 与 GitHub Actions

## 0.3.0

**GPT-Image-2.5 upgrade + channel decoupling** — the skill focuses on prompt orchestration; the image endpoint is entirely your choice.

### Channel decoupling
- `--mode` refactored: `auto | api | manual | cli(legacy)`
- **api mode**: any OpenAI-compatible endpoint via `IMAGE_API_BASE` / `IMAGE_API_KEY` / `IMAGE_MODEL`; reference images ride in `image_urls` with automatic `/v1/images/edits` multipart fallback
- **manual mode**: zero-channel path — exports a prompt pack (prompt.txt + request.json + usage notes) to paste into ChatGPT or curl yourself
- cli mode (codex exec) kept as deprecated legacy

### GPT-Image-2.5 adaptation
- Model routing: Flare (fast drafts) vs Sunburst (label-preserving edits) → `references/model-routing.md`; 15 scenario templates carry `model_hint`
- `--quality low|medium|high|xhigh|max|auto`; size validation adds total-pixels rule; envelope surfaces endpoint-reported cost

### New scenarios (35 → 39)
- `motion-gif`: 16-frame grid → GIF/WebP product animation (methodology in `references/motion-gif.md`, adapted from the open-source product-motion-gif project)
- `bulk-product-swap`: swap your product into a reference layout set
- `bulk-translate`: layout-preserving bulk listing translation
- `transparent-cutout`: transparent product cutout

### Orchestration
- craft.md: five-element prompt assembly, 2.5 text-rendering notes, edit-fidelity craft
- funnel-set.md: single-prompt full-set fast track alongside the precise per-slot mode
- Template slop-word cleanup across the scenario library

### Fixes
- Envelope no longer loses small inline images (large b64 now always spills to a file before rendering)

## 0.1.0

- Initial release: 25 e-commerce scenario templates
