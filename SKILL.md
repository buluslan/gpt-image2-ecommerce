---
name: ecom-image2
description: Use when generating e-commerce product images, advertising materials, or commercial photography using GPT-Image-2 via Codex CLI. Triggers on requests for product photography, promotional banners, social media assets, UGC-style images, packaging design, flat lay, model shots, livestream scenes, exploded views, ghost mannequin, magazine editorial, seasonal campaigns, luxury atmospherics, device mockups, storefront photography, sports campaigns, and other e-commerce visual content.
allowed-tools:
  - Bash
  - Read
version: 0.1.0
---

## Overview

Generate e-commerce images using GPT-Image-2 via Codex CLI. Match user intent to structured JSON prompt templates, assemble concise prompts, and invoke image generation.

## Workflow

### Step 1: Intent Recognition

From the user's request, extract:

- **Scene type**: hero image, lifestyle, flat lay, macro detail, poster/banner, social media, UGC, model showcase, before/after, packaging, infographic, creative concept, size spec, multi-product, livestream, virtual try-on, exploded view, ghost mannequin, multi-angle grid, magazine editorial, seasonal campaign, luxury atmospherics, device mockup, storefront, sports campaign
- **Product info**: category (beauty/electronics/food/fashion/home/jewelry/sports), description, material, key selling points
- **Style preference**: luxury, fresh, tech, minimal, or other variant
- **Reference image**: whether user provided a product photo path

If the user provides a product photo path, note it for `--image` parameter.

### Step 2: Template Matching

Read the matching template from `references/templates/`. Match by scanning `keywords` and `trigger_phrases` in each template:

| Trigger Words | Template File |
|---|---|
| 白底图, 主图, hero image, packshot | `01-hero-image.json` |
| 场景图, 生活图, lifestyle | `02-lifestyle-scene.json` |
| 平铺图, flat lay, 俯拍 | `03-flat-lay.json` |
| 细节图, 微距, macro, 特写 | `04-detail-macro.json` |
| 海报, poster, banner, 促销 | `05-poster-banner.json` |
| 社交媒体, 小红书, Instagram, TikTok | `06-social-media.json` |
| UGC, 买家秀, GRWM | `07-ugc-style.json` |
| 模特, model, 人物展示 | `08-model-showcase.json` |
| 对比, before after, 前后 | `09-before-after.json` |
| 包装, packaging, 礼盒 | `10-packaging.json` |
| 信息图, A+, 详情页 | `11-infographic.json` |
| 创意, 概念, creative | `12-creative-concept.json` |
| 尺寸, 规格, 使用步骤 | `13-size-spec.json` |
| 套装, 组合, bundle | `14-multi-product.json` |
| 直播, livestream | `15-livestream.json` |
| 试穿, 融入, try on | `16-try-on-virtual.json` |
| 拆解图, 爆炸图, exploded view, 内部结构 | `17-exploded-view.json` |
| 隐形模特, ghost mannequin, 3D服装 | `18-ghost-mannequin.json` |
| 多角度, 网格, grid, 多色展示 | `19-multi-angle-grid.json` |
| 杂志, 封面, editorial, magazine | `20-magazine-editorial.json` |
| 季节, 四季, campaign, 春夏秋冬 | `21-seasonal-campaign.json` |
| 奢华, 氛围, 烟雾, luxury, atmospheric | `22-luxury-atmospherics.json` |
| 设备模型, 界面, mockup, SaaS, APP | `23-device-mockup.json` |
| 店铺, 门面, 空间, storefront, 实体店 | `24-storefront.json` |
| 运动, 健身, sports, fitness | `25-sports-campaign.json` |

No match → default to `01-hero-image.json`.

Only read the matched template file (progressive disclosure). Do not load all templates.

### Step 3: Prompt Assembly

From the matched JSON template:

1. Take `prompt_template` as the base structure
2. Replace `{variables}` with user-provided info
3. If user specified a style variant → apply `variants.<name>.overrides`
4. If product category known → apply `category_tips.<category>`
5. **Simplify**: keep only core fields with values, remove empty/null fields
6. Output a concise JSON object (not the full template metadata)

**Key principle**: keep prompts simple. Only include essential information. Image2 performs best with concise, focused prompts rather than overly complex ones.

Example assembled prompt for a beauty hero image:
```json
{
  "type": "product photography",
  "subject": "frosted glass serum bottle with matte white cap",
  "background": "clean white background",
  "lighting": "soft diffused studio lighting",
  "composition": "centered, front view",
  "quality": "8K, commercial e-commerce photography",
  "category_note": "emphasize texture and glow"
}
```

### Step 4: Image Generation

Run the generation script:

```bash
bash scripts/imagegen.sh --prompt-file <(echo '<assembled_json>') --mode auto
```

Or call `codex exec` directly:

**Without reference image:**
```bash
codex exec --ephemeral --skip-git-repo-check --sandbox read-only --color never - <<< "Use imagegen to create an image with this request:
<assembled_json>

Requirements:
- Generate the image directly
- Do not provide explanation
- Return only the image result"
```

**With reference image:**
```bash
codex exec --ephemeral --skip-git-repo-check --sandbox read-only --color never \
  --image /path/to/ref.png \
  - <<< "Use imagegen to create an image with this request:
<assembled_json>

Reference image(s) are attached. Use them as visual identity/style references.
Requirements:
- Generate the image directly
- Do not provide explanation
- Return only the image result"
```

**HTTP service mode**: If `curl -sf http://127.0.0.1:4312/health` succeeds, submit via HTTP instead:
```bash
curl -sf -X POST http://127.0.0.1:4312/v1/images/generations \
  -H 'content-type: application/json' \
  -d '{"prompt":"<assembled_json>","images":["/path/to/ref.png"],"timeout_sec":180}'
```

### Step 5: Result Cleanup

After generation, images are saved to `~/.codex/generated_images/<session_id>/`. Must clean up:

1. Copy generated image to the user's working directory (or specified output path) and rename with descriptive name
2. **Delete the original codex session folder** to avoid duplicate storage:

```bash
rm -rf ~/.codex/generated_images/<session_id>
```

3. Report the final image path to the user

### Step 6: Suggestions

If applicable, suggest:
- Try a different style variant (list available variants from template)
- Adjust product category for more tailored results
- Add a reference image for better product consistency
- Try a different scene type

## Anti-AI Tips (for UGC / Livestream / Social Media scenes)

When generating UGC, livestream, or social media content, these rules are critical:

- Specify exact phone model: `iPhone 14 Pro`, `iPhone 15 Pro`
- Add visible imperfections: pores, slight noise, warm color cast, imperfect framing
- Use candid language: `NOT professional photography`, `NOT AI-generated look`
- Show real environment: slightly messy, real objects, water stains, used towels
- Reference film tone: `Kodak Portra 400 color feel`
- Explicitly state: `NOT retouched, NOT smoothed`
- Avoid AI-signature words: no `perfect`, `flawless`, `stunning`, `hyper-realistic`

## Prompt Writing Guidelines

- **Keep it simple**: only core information, no excessive constraints
- **Natural language preferred**: Image2 understands descriptive sentences better than keyword lists
- **Specify material**: describe textures explicitly (frosted glass, brushed metal, matte finish)
- **Lighting matters**: always include lighting direction and quality
- **Use references**: passing a product photo via `--image` significantly improves consistency
