# Campaign Style Lock — 套图一致性协议（单一真理源）

> ecom-image2 套图一致性机制的设计意图。
> 任何 ≥2 张图的「视觉资产套图」任务（Listing 套图 / A+ 模块组 / 季节 campaign / 多变体系列），都在这里锁定风格。
> SKILL.md Step 4 指向本文件；`assets/default-style-lock.json` 是无品牌规范时的 fallback。
> 单一真理源原则：Lock 字段定义、prepend 机制、单张自由度、多变体规则、region 调整，**只在这里维护**。

---

## 何时建 Lock

| 时机 | 动作 |
|---|---|
| 用户请求 ≥2 张图（"做一套 Listing 套图"/"5 张 A+"/"3 个颜色变体"） | 视为套图任务，`campaign=true`，建 Lock |
| 用户只做 1 张图 | 跳过 Lock，直接 Step 5 组装 |
| 用户给了品牌规范（色板/字体/Logo/VI 手册） | 基于品牌规范建 Lock，覆盖默认 |
| 用户没给任何品牌规范 | 读取 `assets/default-style-lock.json` 作为保守 fallback |
| 同一 campaign 后续追加图（"再补一张场景图"） | 复用已建的 Lock 文本，prepend 到新图 prompt |

**判定原则**：只要整套图要"看起来是同一个品牌/同一组视觉语言"，就建 Lock。哪怕只有 2 张。

---

## 一、10 字段锁定协议

每张套图的 prompt 开头必须 prepend 一段 Lock 文本，由以下 10 个字段组成。字段顺序固定（便于 Claude 和脚本解析），缺字段时用 `default-style-lock.json` 对应值补齐。

### 字段速查

| # | 字段 | 作用 | 锁定强度 |
|---|---|---|---|
| 1 | `visual_direction` | 视觉方向定位（摄影/3D/插画） | 强锁定 |
| 2 | `color_palette` | 固定色板（主色 2-3 + 强调色 1） | 强锁定 |
| 3 | `color_temperature` | 冷暖调 + 色温描述 | 强锁定 |
| 4 | `typography` | 字体系统（标题/正文/强调 + fallback） | 强锁定 |
| 5 | `background_system` | 背景系统（类型 + 一致描述） | 强锁定 |
| 6 | `lighting_system` | 光线系统（方向 + 质感 + 强度） | 强锁定 |
| 7 | `layout_system` | 布局系统（网格/留白/对齐） | 强锁定 |
| 8 | `icon_system` | 图标系统（风格 + 线宽 + 圆角） | 强锁定（含图标的图） |
| 9 | `product_presentation` | 产品呈现规则（角度/裁切/占比） | 强锁定 |
| 10 | `locked_immutable` | 禁止漂移项（整套图绝对不能变的东西） | 不可变 |

### 各字段怎么写

**1. `visual_direction`（视觉方向）**
整套图统一一种视觉语言。三选一，不混用。

- `commercial product photography`（商业产品摄影，最常见）
- `3D render, CGI`（3D 渲染，适合科技/工业）
- `editorial illustration`（编辑插画，适合生活方式/品牌故事）

> 反向写法（避免 negation）：写"是什么"，不写"不是什么"。`commercial product photography` 优于 `not illustration`。

**2. `color_palette`（固定色板）**
2-3 个主色 + 1 个强调色。给 hex 值 + 用途标注。整套图所有视觉元素（背景/文字/图标/色块）只能从这套色板取色。

格式：`primary #FFFFFF (white background), #F5F5F5 (light gray surface), #2C2C2C (charcoal text); accent #0066CC (blue highlight)`

> 建 Lock 时优先采用用户品牌色。无品牌色时按品类选保守色板（见 `default-style-lock.json` 的品类分支）。

**3. `color_temperature`（冷暖调）**
`warm` / `neutral` / `cool` + 一句色温描述。

- `neutral, balanced white balance ~5500K`（电商最通用）
- `warm, golden tint ~3200K`（家居/美食/暖调生活方式）
- `cool, blue-white tint ~6500K`（科技/医疗/清洁感）

**4. `typography`（字体系统）**
三档：标题 / 正文 / 强调。每档给主字体 + fallback。

格式：`headings: Inter Bold; body: Inter Regular; emphasis: Inter SemiBold; fallback: Helvetica, Arial, sans-serif`

> 跨境电商默认无衬线（Inter / Helvetica / SF Pro / Source Han Sans）。手写/衬线字体仅在用户品牌明确要求时用，且整套统一。含中文市场加 `Source Han Sans / Noto Sans CJK` fallback。

**5. `background_system`（背景系统）**
背景类型 + 一致描述。整套图背景语言统一。

- `clean white seamless sweep (#FFFFFF), no props`（Amazon 主图标配）
- `soft light gray studio gradient (#F5F5F5 to #E8E8E8)`（场景/信息图）
- `warm beige lifestyle backdrop (#EDE4D3)`（家居/生活方式）

> 同一套图里，主图可能纯白底、场景图可能是质感底——只要"底色色相 + 质感语言"一致即可（都偏中性灰、都偏暖米色），不算漂移。

**6. `lighting_system`（光线系统）**
方向 + 质感 + 强度。整套图光线方向一致（否则产品看起来像两个批次）。

格式：`soft diffused daylight from top-left, gentle falloff, even illumination, subtle rim light on right edge`

> 产品摄影最常见的稳定光线：`soft diffused daylight from top-left`。Amazon 主图用 `even studio lighting, minimal shadow`。

**7. `layout_system`（布局系统）**
网格规则 + 留白 + 对齐。主要约束信息图/A+/对比图这类有版式的图。

- `rule of thirds, product centered-left, generous whitespace, left-aligned text blocks`
- `structured grid, 12-column, 8px gutter, product occupies 60% of frame`

**8. `icon_system`（图标系统）**
图标风格 + 线宽 + 圆角。信息图/卖点图必锁。

格式：`thin-line icons, 2px stroke, 4px corner radius, monochrome in accent color`

> 混用线性和填充图标是套图"廉价感"的头号来源。整套必须同一风格。

**9. `product_presentation`（产品呈现规则）**
角度 / 裁切 / 占比。整套图里产品怎么放要一致。

- `front 3/4 angle, product occupies 60-70% of frame, no crop on edges`
- `straight front view, centered, product occupies 80%+ (Amazon main image)`

**10. `locked_immutable`（禁止漂移项）★ 最关键**
列出整套图**绝对不能变**的东西。这是套图一致性的核心——把"什么不能漂移"显式化，Claude 和用户都清楚边界。

典型锁定项：
- 色板（主色 + 强调色 hex 固定）
- 字体（主字体 + fallback 固定）
- 背景色相（白/灰/米色的具体方向）
- 光线方向（top-left / top-center）
- 图标风格（线性/填充 + 线宽）
- 产品角度（front 3/4 / straight front）

格式：`LOCKED across entire set: color palette, typography, background hue, lighting direction, icon style, product angle`

---

## 二、Lock 文本格式与 prepend 机制

建好 10 字段后，组装成一段 Lock 文本，**逐字 prepend 到每张图的 prompt 开头**。格式固定如下（Claude 和 imagegen.sh 都按此解析）：

```
[CAMPAIGN LOCK — campaign_id: <id>]
Visual direction: <visual_direction>
Color palette: <color_palette>
Color temperature: <color_temperature>
Typography: <typography>
Background: <background_system>
Lighting: <lighting_system>
Layout: <layout_system>
Icon style: <icon_system>
Product presentation: <product_presentation>
LOCKED across entire set: <locked_immutable>
[/CAMPAIGN LOCK]

<这张图的 5-slot prompt（Scene/Subject/Important details/Use case/Constraints）>
```

`campaign_id` 是本次套图的唯一标识（如 `amz-waistbelt-202607`），用于追加图时复用同一 Lock。

**prepend 规则**：
- Lock 文本是**前缀**，不是后缀。GPT-Image-2 对 prompt 开头的内容权重更高，Lock 放前面才能压制漂移。
- Lock 文本**逐字复制**，不重写、不意译。每张图的 Lock 段一字不差。
- 单张 prompt 的 Scene/Subject 等槽位只描述"这张图的独特内容"，不重复 Lock 已覆盖的字段（避免冗余稀释）。

---

## 三、单张自由度：只允许改这 4 项

Lock 不等于死板。每张图保留 4 项自由度，覆盖"这套图里每张要讲不同故事"的需求：

| 可改项 | 说明 | 示例 |
|---|---|---|
| **画面目的**（frame_purpose） | 这张图在漏斗里的角色（吸睛/代入/说明/对比/信任） | 主图=吸睛；场景图=代入；信息图=说明 |
| **主体动作**（subject_action） | 产品怎么呈现（使用中/拆解/静止/对比） | 静止展示 vs 使用中 vs 拆解爆炸图 |
| **局部构图**（local_composition） | 这张的景别/视角（特写/全景/俯拍/侧视） | 微距特写 vs 全景场景 vs 俯拍平铺 |
| **短文案**（short_copy） | 这张图的文字标签/卖点短句 | "50H Battery" vs "IPX7 Waterproof" |

这 4 项之外的任何字段（色板/字体/背景类型/光线方向/图标风格/产品角度）**都属于 Lock，单张不得修改**。

> 设计意图：Lock 保证"一眼看出是同一套"，4 项自由度保证"每张讲不同故事"。既一致又不死板——这是套图不漂移的编排机制。

---

## 四、多变体套图规则（n=8 同锚点）

"多变体"指同一产品的颜色/材质/款式变体（如耳机有黑/白/蓝/粉 5 色）。多变体套图用批量生成 + 同一锚点：

- **同锚点**：所有变体共享同一 `visual_direction / lighting / background / product_presentation / layout`（即 Lock 的强锁定字段全部不变）。
- **只改颜色/材质**：每张图的 Subject 槽里只改 `{color}` 和 `{material}` 变量，其他描述一字不差。
- **批量调用**：用 `imagegen.sh` 的 `--n 8`（或多次循环），每次只换颜色/材质变量，prompt 主体完全相同。

示例（耳机 4 色变体，共享 Lock，只改 Subject 的 color/material）：
```
变体1 Subject: wireless over-ear headphones, matte black (#1A1A1A), aluminum alloy
变体2 Subject: wireless over-ear headphones, arctic white (#F0F0F0), aluminum alloy
变体3 Subject: wireless over-ear headphones, ocean blue (#1B4F8C), aluminum alloy
变体4 Subject: wireless over-ear headphones, coral pink (#FF6B6B), aluminum alloy
```
Lock 段四张完全一致。这样产出的变体"同一张产品图 PS 出来的"般一致。

> 多变体场景下 `locked_immutable` 尤其严格：光线方向、产品角度、背景、占比、镜头焦距全部锁定——否则颜色对比会失真（不同光线下的同色看起来像不同色）。

---

## 五、何时用 default 模板（fallback 流程）

```
用户请求套图
  ├─ 用户给了品牌规范（色板/字体/VI）？
  │    └─ YES → 基于品牌规范填 10 字段，建 Lock
  └─ NO → 读取 assets/default-style-lock.json
            ├─ 按 region 选调整（见第六节）
            ├─ 按品类选色板分支（ Electronics 偏冷灰 / Beauty 偏暖白 / Food 偏鲜艳 ）
            └─ 生成保守、通用的 Lock，prepend 到每张图
```

`default-style-lock.json` 的定位：**保守、通用、不犯错**。中性色板、无衬线字体、干净背景、柔光——适合任何品类任何市场，不会出彩但绝不出错。用户后续可基于它微调（"把强调色改成我们的品牌蓝 #0066CC"）。

---

## 六、region 本地化（查表）

region 影响套图的审美偏好、肤色多样性、节日季、文化禁忌。建 Lock 时若已知 region，按下表调整 `default-style-lock.json` 的对应字段。

> 单一真理源：region → Lock 字段调整**只在这里查**。`funnel-set.md` 的槽位编排也会参考本节决定"该 region 多放哪类图"。

### 6.1 region → 审美偏好与 Lock 调整

| region | 审美偏好 | 色板调整 | 字体调整 | 背景调整 | 光线调整 |
|---|---|---|---|---|---|
| **US** | 直接、自信、卖点清晰 | 高对比，强调色饱和度足（#0066CC / #E63946） | 粗壮无衬线（Inter Bold / Montserrat），标题大 | 纯白 #FFFFFF 或明亮浅灰 | 明亮、清晰、硬光感（高显色） |
| **EU** | 克制、极简、质感 | 低饱和中性（米灰 #E8E2D9 / 雾蓝 #A8B5C0），强调色低调 | 纤细无衬线（Helvetica Neue / Futura），字距宽 | 柔和灰/米色渐变，质感底 | 柔和漫射、自然光感、低对比 |
| **SEA**（东南亚） | 鲜艳、热闹、促销感强 | 高饱和暖色（橙红 #FF6B35 / 金黄 #FFD23F），对比强烈 | 醒目圆润无衬线（Poppins / Nunito），可加粗 | 彩色/节日元素/渐变背景 | 明亮、鲜艳、高饱和 |
| **CN**（中国） | 精致、国潮可选、信任感 | 红金（#C8102E / #D4AF37）或克制高级灰（#5C5C5C） | 思源黑体 / PingFang SC，标题可书法体（国潮时） | 质感底（大理石/木纹/素色） | 干净通透，国潮时可用侧光塑形 |
| **ME**（中东） | 尊贵、几何、宗教敏感 | 金（#D4AF37）/ 深绿（#006C35）/ 白（#FFFFFF），避免纯黑 | 几何无衬线（Cairo / Tajawal，支持阿语） | 几何图案/大理石/金色质感 | 暖金光、戏剧性侧光（尊贵感） |

### 6.2 肤色多样性（含人物的图必查）

| region | 肤色多样性要求 |
|---|---|
| **US / EU** | **强制多样**：套图含模特时，整套至少出现 2 种以上肤色（白/棕/黑/亚裔）。单一肤色有品牌风险（歧视观感） |
| **SEA** | 以东南亚本地肤色为主（棕褐/小麦），可混入少量东亚面孔 |
| **CN** | 以东亚肤色为主，白皙偏多（本地审美），但避免过度美白（平台合规风险） |
| **ME** | 以中东/南亚肤色为主（橄榄/小麦），模特着装保守（见 6.3） |

> Amazon US/EU 主图若含人物，肤色多样性是隐性合规项（不强制但影响转化 + 品牌风险）。建 Lock 时在 `locked_immutable` 加一条 `model diversity: 2+ skin tones across set`。

### 6.3 文化禁忌（违反即封号/下架风险）

| region | 禁忌 | Lock 层面处理 |
|---|---|---|
| **ME** | 猪及猪形象 / 酒精 / 暴露着装（女性需遮头发与四肢）/ 十字架 / 六芒星 / 蛇 | 模特着装 `conservative, covered shoulders and hair`；色板避纯黑（哀悼色）改用深绿/金；prompt 的 Constraints 槽强制注入 `no alcohol, no pork imagery, no religious symbols` |
| **CN** | 特定政治符号 / 地图边界问题 / 日军旗纹（旭日旗） | 避免旭日放射纹；地图类图不用（或用官方标准地图）；国潮元素避免历史敏感符号 |
| **SEA** | 部分国家（如印尼/马来）避猪/避酒精；泰国避不敬王室元素；菲律宾避特定手势 | 按 ME 规则降级处理；手势避免食指指人（改用手掌指引） |
| **US/EU** | 种族刻板印象 / 文化挪用（如印第安头饰/部落纹样商用） | 避免特定族裔的文化符号做装饰；肤色刻板分工（如亚裔只演科技、黑人只演运动）严禁 |

### 6.4 节日季套图（季节性 campaign）

| region | 关键大促 | 套图调整 |
|---|---|---|
| **US** | Black Friday / Cyber Monday（11 月）/ 圣诞（12 月）/ Prime Day（7 月） | 色板临时切黑红/圣诞红绿；主图加促销角标（需符合平台规则） |
| **CN** | 双 11（11.11）/ 618（6.18）/ 春节（农历新年） | 红金主色；春联/福字/生肖元素（注意生肖年度） |
| **SEA** | Lazada/Shopee 大促（双日如 9.9/11.11）/ 开斋节（Eid）/ 农历新年（华人市场） | 开斋节用绿金；华人新年用红金；大促用平台品牌色 |
| **ME** | 斋月（Ramadan）/ 开斋节（Eid al-Fitr）/ 白色星期五 | 绿金/星空新月元素；避免促销过于喧嚣（斋月期间克制） |
| **EU** | 圣诞（12 月）/ 复活节（春）/ Summer Sale | 圣诞红绿/金；复活节粉黄；避免过度美式商业化感 |

> 节日季套图建**临时 Lock**（单独 campaign_id，如 `ramadan-2026`），节日后归档，不污染日常 Listing 的 Lock。

---

## 七、与 SKILL.md 其他步骤的对齐

| 步骤 | 与 Lock 的关系 |
|---|---|
| Step 1 意图识别 | 识别 `campaign=true`（≥2 张图）+ region（影响第六节调整） |
| Step 2 场景路由 | 每张图命中各自模板（主图/场景/信息图），Lock 不影响路由 |
| Step 3 驱动力诊断 | 驱动力影响套图槽位编排（见 `funnel-set.md`），不直接改 Lock |
| **Step 4 建 Lock** | 读本文件建 10 字段，prepend 到后续每张图 |
| Step 5 Prompt 组装 | 每张图的 5-slot prompt 前面拼 Lock 段；Scene 槽只写"这张图独特内容" |
| Step 6 图像生成 | Lock 段随 prompt 一起传给 imagegen.sh，脚本原样透传 |
| Step 7 合规自检 | 检查套图一致性（色板/字体/光线是否漂移）+ region 禁忌是否触发 |

---

*本协议为套图模式的单一真理源。修改 10 字段定义、prepend 机制、单张自由度、多变体规则、region 调整，只改本文件。*
