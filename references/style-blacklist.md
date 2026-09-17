# Style Blacklist — 品类×风格冲突 + Anti-Slop 双层过滤（单一真理源）

> ecom-image2 的质量护栏单一真理源。
> 所有「品类×风格冲突规则」「slop 词过滤」「AI-tell 视觉特征判断」**只在这里维护**。
> SKILL.md 的 Step 5（Constraints 槽）、Step 7（质量自检）和 scenarios/*.json 都指向本文件，禁止在其他地方重复定义。
>
> **Anti-Slop 双层过滤**：
> - **第一层（slop 词过滤，第二节）**：在 prompt 文字层过滤 AI 感知词，Step 5 组装时删除或替换。
> - **第二层（AI-tell 视觉特征，第四节）**：在出图后的视觉判断层检测 AI 告密特征，Step 7 由 Claude vision 主导（脚本不自动做）。

---

## 何时查这个文件

| 时机 | 查什么 |
|---|---|
| Step 1 意图识别后（品类已确定） | 该品类的「黑名单风格」+「推荐替代风格」+「关键规则」 |
| Step 5 Prompt 组装 Constraints 槽 | 注入对应品类的推荐替代关键词 + 背景亮度/字体/配色硬约束 |
| 任何含人物/写实场景/UGC/直播图 | slop 词过滤清单（第二节），prompt 中命中即替换或删除 |
| Step 7 质量自检（prompt 层） | 出图后若仍有 AI 感，回查 slop 词（第二节）是否漏过滤 |
| Step 7 质量自检（视觉层） | **第四节（AI-tell 视觉特征）**：Claude 用 vision 逐项检测生成图的 AI 告密特征，命中则重试 / 改 prompt / 换槽位 |

---

## 一、品类×风格冲突矩阵

### 1. Electronics / Tech（数码、3C、智能硬件、音频设备）

**黑名单风格：**

| 黑名单风格 | 英文关键词 | 原因 |
|---|---|---|
| 户外生活方式杂志风 | outdoor lifestyle, lifestyle magazine, bokeh outdoor, golden hour lifestyle | 科技产品用「湖畔野餐」氛围图显得不伦不类，削弱专业感 |
| 奢华氛围渲染 | luxury atmospherics, smoke, perfume aesthetic, velvet, silk drape | 美妆/香水专属氛围，与硬核科技产品调性完全相反 |
| 花卉装饰风 | dried flowers, botanical, floral pattern, rose petals, wreath | 软性美妆视觉语言，不适合科技硬件 |
| 手写字体风 | handwritten font, script font, casual writing, brush lettering | 科技产品需现代无衬线/等宽字体，手写风显得不够专业 |
| 复古做旧风 | vintage, retro film grain, faded, antique, nostalgia | 削弱科技产品的「新/前沿」感 |

**推荐替代风格：**

| 推荐风格 | 英文关键词 | 适用场景 |
|---|---|---|
| 硬核科技风（中等明度） | tech blueprint, cyan grid, dark gray background (NOT pure black), isometric tech lines, subtle geometric patterns | 对比图、信息图、规格图 |
| 工业设计风 | industrial design, matte metal texture, clean studio, soft directional lighting on metal | 产品主图、细节图 |
| 极简数据风 | minimal data visualization, clean sans-serif typography, structured grid layout, monospace accent | A+ 信息图、对比图、参数图 |
| 未来科技感 | subtle neon accent lines, holographic gradient overlay (sparingly), dark charcoal with glow | 海报、创意概念图 |

**关键规则：**
- 背景亮度 ≥ `#2A2A2A`（深灰），**不用纯黑 `#000000`**，也不用纯白户外场景
- 文字排版用现代无衬线字体（Helvetica / SF Pro / Inter），标题可用等宽字体（SF Mono / JetBrains Mono）
- 配色以冷色调为主（深灰/碳灰 + 青色/电蓝点缀），暖色仅作点缀

---

### 2. Beauty / Skincare（护肤、彩妆、香水、个护）

**黑名单风格：**

| 黑名单风格 | 英文关键词 | 原因 |
|---|---|---|
| 硬核工业风 | industrial, blueprint, tech grid, circuit board, isometric tech | 硬核工业风与美妆柔感冲突，显得冰冷 |
| 工程标注风 | spec annotation, ruler, measurement marks, technical drawing | 美妆不需要工程标注感 |
| 暗黑科技感 | pure black background, neon cyan glow, dark cyberpunk | 美妆需明亮/通透/洁净感，暗黑风显得不洁 |
| 复古粗糙质感 | distressed texture, grunge, rust, concrete | 与美妆的「洁净/精致」诉求相反 |

**推荐替代风格：**

| 推荐风格 | 英文关键词 | 适用场景 |
|---|---|---|
| 柔光美妆风 | soft diffused lighting, bright airy, dewy skin glow, clean white or pastel background | 主图、模特图、场景图 |
| 奢华氛围风（适度） | soft silk, marble surface, rose gold accent, subtle smoke (sparingly), perfume aesthetic | 香水、高端线、节日礼盒 |
| 水彩植物风 | watercolor botanical, soft floral illustration, pastel petals | 春夏新品、限定款、礼盒 |
| 极简美妆风 | minimal clean studio, frosted glass texture, soft gradient background | 主图、成分图、信息图 |

**关键规则：**
- 背景以**亮色/浅色为主**（纯白 / 浅粉 / 浅米 / 大理石白），深色仅限高端线适度使用
- 强调**肤感与光泽**：dewy / glowing / luminous / radiant（但禁用 slop 词 flawless/perfect，见第二节）
- 配色以暖白/粉/玫瑰金为主，强调色用品牌主色

---

### 3. Food（食品、饮料、零食、保健品）

**黑名单风格：**

| 黑名单风格 | 英文关键词 | 原因 |
|---|---|---|
| 暗黑戏剧光 | dark moody, dramatic shadow, chiaroscuro, low key lighting | 食品需要明亮温暖的食欲感，暗黑光显得不新鲜 |
| 工业冷调 | industrial, steel gray, tech grid, circuit | 冷硬工业感与食品的「温暖/手作」诉求冲突 |
| 科技蓝调 | neon blue, cyan glow, cyberpunk | 蓝光让食物显得有毒/不自然 |
| 复古做旧 | vintage fade, distressed, sepia heavy | 削弱食品的「新鲜/诱人」感 |

**推荐替代风格：**

| 推荐风格 | 英文关键词 | 适用场景 |
|---|---|---|
| 明亮食欲风 | bright natural daylight, warm soft light, fresh appetizing, clean white or wood surface | 主图、平铺图、场景图 |
| 手作温暖风 | rustic wood table, linen napkin, warm golden hour (soft), hand-crafted feel | 烘焙、手作、家常感食品 |
| 清新自然风 | fresh ingredients surrounding, green herbs, water splash, crisp texture | 生鲜、饮品、健康食品 |
| 节日盛宴风 | festive table setting, warm candlelight glow, abundant spread | 节日礼盒、年货、聚会食品 |

**关键规则：**
- 光线必须**明亮/温暖**（daylight / warm soft），不要暗黑戏剧光
- 强调**质感与新鲜**：crispy / juicy / steaming / fresh / golden crust
- 配色以暖色为主（橙/红/金黄/木色），蓝色仅限饮品/冰感场景

---

### 4. Fashion（服装、鞋包、配饰）

**黑名单风格：**

| 黑名单风格 | 英文关键词 | 原因 |
|---|---|---|
| 工程标注风 | flat lay with ruler, spec annotation, measurement marks, technical schematic | 时尚不需要工程标注感（除非是尺码图，那是另一场景） |
| 硬核科技风 | tech blueprint, circuit board, isometric tech lines, cyan grid | 科技风与时尚的「柔软/人体/潮流」诉求冲突 |
| 数据可视化风 | data visualization, chart overlay, statistical graph | 时尚图不需要数据图表干扰 |
| 工业金属感 | bare metal, steel mesh, industrial machinery | 冷硬金属感削弱服装的穿着感 |

**推荐替代风格：**

| 推荐风格 | 英文关键词 | 适用场景 |
|---|---|---|
| 杂志编辑风 | magazine editorial, vogue style, high fashion, studio portrait with clean backdrop | 高端服装、品牌大片 |
| 街拍生活风 | street style, urban backdrop, candid walking shot, natural daylight | 休闲装、日常穿搭、快时尚 |
| 极简衣架风 | minimal clean background, wooden hanger, soft studio light, fabric texture focus | 主图、产品图、细节图 |
| 季节氛围风 | seasonal atmosphere (spring blossoms / autumn leaves / winter cozy), soft golden hour | 季节 Campaign、节日款 |

**关键规则：**
- 服装主图优先**面料质感与剪裁**（fabric texture / drape / cut / stitching detail）
- 模特图强调**穿搭场景感**，不要孤立的产品摆拍
- 配色跟随品牌调性，避免工业冷调（除非是机能/科技面料品牌）

---

### 5. Home（家居、家具、厨具、家居装饰）

**黑名单风格：**

| 黑名单风格 | 英文关键词 | 原因 |
|---|---|---|
| 纯白实验室风 | pure white lab, clinical sterile, specimen on white | 家居需要生活温度，实验室风显得冷清 |
| 科技蓝调 | neon blue, cyan glow, tech grid, holographic | 科技感与家居的「温暖/生活感」冲突 |
| 户外探险风 | outdoor adventure, mountain, campsite, survival gear | 户外探险风不适合室内家居产品 |
| 重工业机械感 | heavy machinery, factory floor, raw steel, oil stain | 过度工业化削弱家的温馨感 |

**推荐替代风格：**

| 推荐风格 | 英文关键词 | 适用场景 |
|---|---|---|
| 生活场景风 | cozy living room scene, warm interior lighting, styled shelf, natural wood texture | 场景图、生活方式图、A+ |
| 北欧极简风 | Scandinavian minimal, bright airy, soft neutral palette, natural material | 主图、极简风格产品 |
| 季节家居风 | festive home setting, warm candlelight, seasonal decor | 节日家居、季节 Campaign |
| 细节质感风 | close-up material texture, fabric weave, wood grain, ceramic glaze | 细节图、材质展示 |

**关键规则：**
- 背景以**生活场景或暖色中性色**为主（米色/木色/浅灰/奶油色）
- 强调**居家温度**：cozy / warm / inviting / lived-in（不要 sterile/cold）
- 配色以自然色为主（木色/亚麻色/陶土色/橄榄绿）

---

### 6. Jewelry（珠宝、首饰、手表）

**黑名单风格：**

| 黑名单风格 | 英文关键词 | 原因 |
|---|---|---|
| 嘈杂户外风 | busy outdoor, crowded street, messy background | 珠宝需要聚焦主体，嘈杂背景分散注意力 |
| 卡通插画风 | cartoon, flat illustration, vector style, emoji-like | 削弱珠宝的高级感与材质真实感 |
| 工程标注风 | ruler, spec marks, technical schematic | 珠宝不需要工程标注（除非是钻石参数图，那是另一场景） |
| 朴素日常风 | casual snapshot, unstyled, plain desk | 珠宝需要仪式感，朴素日常风降低价值感 |

**推荐替代风格：**

| 推荐风格 | 英文关键词 | 适用场景 |
|---|---|---|
| 奢华珠宝风 | luxury jewelry photography, macro detail, sparkling highlights, black velvet or silk backdrop | 主图、细节图、高端线 |
| 极简白底风 | clean white background, soft studio reflection, centered composition | 主图、电商标准图 |
| 模特佩戴风 | elegant hand model, wrist shot, neck shot, soft skin tone backdrop | 佩戴场景、尺寸参考 |
| 节日礼盒风 | gift box setting, rose petals, ribbon, warm festive glow | 节日款、送礼场景 |

**关键规则：**
- 必须强调**材质光泽**：sparkling / brilliant / lustrous / polished / faceted
- 背景以**深色丝绒/绸缎**或**纯净白底**为主（两极化，不要中间灰）
- 光线用**聚光 + 柔光**组合，突出宝石折射与金属反光

---

### 7. Sports / Fitness（运动、健身、户外装备）

**黑名单风格：**

| 黑名单风格 | 英文关键词 | 原因 |
|---|---|---|
| 居家慵懒风 | cozy couch, lazy afternoon, soft pastel bedroom | 运动产品需要动感与活力，居家慵懒风与调性相反 |
| 奢华香水风 | perfume aesthetic, velvet, smoke, silk drape | 奢华氛围与运动的「汗水/力量/速度」冲突 |
| 工程标注风 | spec annotation, ruler, technical drawing（除非是装备参数图） | 削弱运动场景的代入感 |
| 暗黑戏剧静物 | still life, dark moody, low key, no motion | 运动需要动态感，静物暗黑风显得沉闷 |

**推荐替代风格：**

| 推荐风格 | 英文关键词 | 适用场景 |
|---|---|---|
| 动态运动风 | dynamic action shot, motion blur, athletic energy, sweat detail, gym or outdoor setting | 场景图、模特图、Campaign |
| 功能展示风 | feature callout, material close-up, ergonomic detail, technical spec（适度） | 信息图、细节图、卖点图 |
| 户外场景风 | trail running, mountain backdrop, beach workout, natural daylight | 户外装备、运动场景 |
| 极简产品风 | clean studio, dynamic product angle, dramatic directional light on equipment | 主图、产品图 |

**关键规则：**
- 强调**动态/力量/汗水**：dynamic / energetic / powerful / sweat / motion（禁用静态 slop 词）
- 背景以**运动场景或高对比工作室**为主，不要柔和居家
- 配色以高饱和/高对比为主（霓虹强调色 / 深色背景 + 亮色点缀）

---

## 二、slop 词过滤清单（Anti-Slop 第一层 · prompt 文字层）

> 这些词在电商图 prompt 中是「AI 味」的信号——要么堆砌画质（无意义），要么虚构美学（不真实），要么完美主义（显得假）。
> **规则：prompt 中命中即删除或替换为正向具体描述。**

### 2.1 完美主义词（最大类，最伤真实感）

| slop 词 | 为什么禁 | 正向替代写法 |
|---|---|---|
| perfect | 过度完美 = AI 味，真实产品有自然瑕疵 | `natural texture`, `real-world finish` |
| flawless | 同上，禁用于肤感/材质 | `even texture`, `consistent surface` |
| immaculate | 太干净不真实 | `clean but realistic` |
| pristine | 过度洁净 | `fresh, well-maintained` |
| impeccable | 抽象空话 | 直接写具体质感（如 `smooth matte finish`） |
| spotless | 不真实 | `tidy, organized` |
| blemish-free | 禁用于肤感 | `natural skin texture with even tone` |

### 2.2 质感夸张词（空话，无信息量）

| slop 词 | 为什么禁 | 正向替代写法 |
|---|---|---|
| stunning | 空泛赞美，无具体信息 | 直接写吸引人的具体点（如 `vibrant cyan accent`） |
| gorgeous | 同上 | 写具体（如 `warm golden tones`） |
| breathtaking | 同上 | 写具体场景/构图 |
| mesmerizing | 同上 | 写具体光影效果 |
| captivating | 同上 | 写具体主体动作 |
| beautiful | 太泛 | 写具体（`elegant silhouette`, `clean lines`） |
| amazing / incredible / fantastic | 空话 | 删除，或换具体描述 |

### 2.3 分辨率/画质堆砌词（Image2 无视，纯占 token）

| slop 词 | 为什么禁 | 正向替代写法 |
|---|---|---|
| 8K, 4K, ultra HD | 模型不按分辨率理解，无效 | 删除（质量由 `quality` 参数控制） |
| hyper-detailed, highly detailed | 空泛 | 写具体细节（`visible stitching`, `pore texture`） |
| masterpiece, best quality, award-winning | 训练 bias 词，无效且显 AI 味 | 删除 |
| professional photography | 过度使用成 slop | 写具体（`shot on 85mm lens, soft daylight`） |
| high resolution, ultra sharp | 无效 | 删除 |
| render in Unreal Engine / Octane | 不适用于电商实拍感 | 删除 |

### 2.4 虚构美学词（最显 AI 味）

| slop 词 | 为什么禁 | 正向替代写法 |
|---|---|---|
| hyper-realistic | 反而显得假（真照片不需要声明 realistic） | 删除，或写 `natural photographic look` |
| ultra-realistic | 同上 | 删除 |
| photorealistic | 同上（过度使用） | 删除，让构图/光线说话 |
| cinematic | 太泛，什么都叫 cinematic | 写具体（`warm side lighting, shallow depth of field`） |
| epic | 空话 | 写具体场景 |
| magical, dreamy | 模糊 | 写具体氛围（`soft morning haze`, `warm backlight`） |
| trending on ArtStation | prompt 工程古早 bias 词 | 删除 |

### 2.5 UGC / 直播 / 社交场景专属禁词

> 这些场景需要「反 AI 感」，下列词一旦出现就破坏真实感。

| slop 词 | 正向替代写法 |
|---|---|
| perfect lighting | `available indoor lighting, slightly warm` |
| studio quality | `iPhone 15 Pro shot, natural indoor light` |
| retouched, smoothed | `NOT retouched, natural skin texture, visible pores` |
| professional edit | `unedited, raw phone photo feel` |
| polished | `candid, unposed, in-the-moment` |
| model-perfect | `real person, relatable, everyday user` |

---

## 三、通用规则（跨品类）

1. **完美即 AI 味**：真实产品图有自然光线变化、轻微反射、材质的自然不均匀。不要追求「完美」。
2. **具体胜过抽象**：与其写「beautiful lighting」，写「soft daylight from the left at 45°」。具体描述永远优于空泛赞美。
3. **分辨率词无效**：8K/4K/hyper-detailed 对 Image2 无意义，质量由脚本 `quality` 参数控制（high/medium/low）。
4. **声明「不是什么」比「是什么」更有效**：UGC 场景写 `NOT professional photography` 比 `amateur phone photo` 更管用。
5. **品类风格冲突 > 个人偏好**：即便用户说「给这个耳机加花卉装饰」，也要先提示品类冲突，确认后再执行（产品准则：站在卖家角度，花卉装饰会降转化）。

---

## 四、AI-tell 视觉特征过滤（Anti-Slop 第二层 · 视觉判断层）

> **这是出图后的视觉判断层**，对应第二节（slop 词）的 prompt 文字层。
> slop 词在组装时过滤，但即便 prompt 干净，GPT-Image-2 的**默认统计输出**仍可能带 AI 告密特征（见 `craft.md` 1.1：模型学到的「好」=「被修过的好」）。
> 本层在 **Step 7 质量自检**时使用：Claude 用 vision **逐项检测**生成图是否命中下列特征。
> **脚本不自动做**（图像理解靠 Claude vision），Claude 读这张表做人工判断。

**使用方式**：
1. 出图后（Step 7），Claude 对生成图逐项扫下面 8 类 AI-tell
2. 命中任何一类 → 判断严重度（轻微可接受 / 明显需重做）
3. 明显命中 → 回到对应章节调 prompt 重生成（**一轮一改**：每次只针对一个最严重的特征改）
4. 三次重做仍命中 → 建议换场景方案或绕开（如 UGC 改用实拍 + AI 辅助）

---

### 4.1 塑料肤质（Plastic / Porcelain Skin）

**特征描述**：人物皮肤过度平滑，无毛孔、无 peach fuzz、无细纹，肤色均匀到不自然，像打蜡或瓷娃娃。

**为什么是 AI 告密**：真实皮肤有毛孔、微血管、绒毛、轻微色斑——这些是「真实人」的视觉证据。GPT-Image-2 训练数据里的「好皮肤」图大多经过磨皮修图，模型学到的 skin = 平滑无瑕（详见 `craft.md` 1.1）。所以**默认输出的皮肤就是塑料感**，除非 prompt 显式要求瑕疵。这是人物图最高频的 AI-tell。

**视觉 checklist**（Claude 逐项看）：
- [ ] 额头 / 鼻翼 / 脸颊能看到毛孔？
- [ ] 脸颊有 peach fuzz（细绒毛）？
- [ ] 有微笑线 / 法令纹等自然纹路？
- [ ] 肤色有自然的不均匀（微红 / 微暗），不是「糊成一片」？

**命中后建议**：
- 重试时在 prompt 加：`visible pores, peach fuzz, natural skin texture with fine lines, NOT retouched, NOT smoothed`（→ `craft.md` 1.2 招 3）
- 加胶片色调：`Kodak Portra 400 color feel, subtle film grain`（招 2）
- UGC 场景加设备锚定：`shot on iPhone 15 Pro`（招 1）

---

### 4.2 对称偏执（Unnatural Symmetry）

**特征描述**：人物脸部左右完全对称、双臂角度一模一样、双眼大小形状完全相同、身体姿态完全居中平衡。

**为什么是 AI 告密**：真实人体是**天然不对称**的——左右脸大小微差、一只眼略高、姿态总有轻微歪斜。扩散模型的损失函数偏好「平均脸 / 平均姿态」，平均化后对称度上升（详见 `craft.md` 1.1）。完全对称 = 模型在「偷懒」输出期望值。

**视觉 checklist**：
- [ ] 脸部左右有明显不对称？（眼大小 / 嘴角高低 / 脸型）
- [ ] 双臂 / 双腿姿态有差异？
- [ ] 整体姿态有自然歪斜，不是「站军姿」？

**命中后建议**：
- 重试时加：`slightly asymmetrical features, natural posture, candid off-center angle`（→ `craft.md` 1.2 招 6）
- 加：`subject looking slightly away from camera, not posed`
- 注意：**Amazon 主图 / 产品白底图不需要打破对称**（产品居中是平台要求），本条主要针对人物 / 模特 / UGC 图。

---

### 4.3 边缘融合（Fused / Merged Edges）

**特征描述**：产品边缘「糊」进背景、相邻物体边界融合、主体和道具黏在一起、轮廓不清晰。

**为什么是 AI 告密**：扩散模型去噪时，相邻像素一起预测，物体边界是**概率过渡区**而不是锐利切线（详见 `craft.md` 1.1）。物体越多、距离越近，融合越严重。这是为什么「信息图塞太多卖点框」会糊成一团。

**视觉 checklist**：
- [ ] 产品轮廓清晰锐利，和背景有明确分界？
- [ ] 产品和道具 / 文字框 / 标注线之间有间隙？
- [ ] 手指 / 头发 / 细长部位有没有「融」在一起？

**命中后建议**：
- prompt 减少画面物体数量（信息图卖点框 ≤4 个）
- 加：`crisp edges, clear silhouette, product sharply separated from background`
- 提高占比：`product fills 85% of frame`（减少周边干扰物）
- 若是手指融合（人物图）→ 见 4.4

---

### 4.4 多指 / 多肢（Extra Digits / Limbs）

**特征描述**：人物有 6 根手指、手指数量不对、多一条手臂 / 腿、肢体扭曲成不可能的角度。

**为什么是 AI 告密**：这是扩散模型最经典的失败模式。手部结构复杂（每只手 27 块骨头 + 复杂关节），训练数据里手部标注噪声大，模型没真正学会「手」的拓扑结构，只学会了「手的视觉风格」。所以它画的手**数量常错、关节常扭曲**。这是买家一眼能认出的 AI 告密，杀伤力极大。

**视觉 checklist**：
- [ ] 每只手恰好 5 根手指？
- [ ] 手指数对，没有「多一小截」？
- [ ] 手腕 / 手肘 / 肩膀关节角度生理上可能？
- [ ] 四肢数量对（2 手臂 2 腿），没有「多一条」？

**命中后建议**：
- **多指是最难修的 AI-tell**——重试常常还是错。
- 优先策略：**裁掉手 / 遮住手**（构图上让手出画面或被产品挡住）。
- 或换角度：`hands hidden behind back` / `close-up on face, hands out of frame`。
- 若必须露手 → 用参考图（`--image` 传含正确手部的图）+ 提高 `input_fidelity`。
- 三次重做仍错 → 建议绕开（改用产品图不露手 / 实拍 + AI 辅助）。

---

### 4.5 眼神空洞（Dead Eyes / Uncanny Valley Gaze）

**特征描述**：人物眼神「没有神采」、瞳孔呆滞、目光不聚焦、像看着虚空而不是看着某处，整体产生「恐怖谷」感。

**为什么是 AI 告密**：眼睛是「灵魂之窗」——人眼极度敏感于眼神的微妙聚焦方向。扩散模型画眼睛时还原了**形态**（虹膜 / 瞳孔 / 巩膜），但没还原**聚焦方向**（模型不知道「这个人在看什么」），于是眼神缺乏目标感，产生 uncanny valley。这是最难用 prompt 修复的 AI-tell 之一。

**视觉 checklist**：
- [ ] 眼神有「在看某个具体方向」的聚焦感？
- [ ] 瞳孔有反光点（catchlight），不是死黑？
- [ ] 整体表情自然，不是「假笑」？

**命中后建议**：
- 加具体视线方向：`model looking directly at the camera lens` 或 `looking at the product with focused gaze`
- 加 catchlight：`catchlight in the eyes, lively gaze`
- 加情绪描述：`genuine warm smile, eyes crinkled`
- 若仍空洞 → 改构图让人物不直视镜头（侧脸 / 低头看产品），侧脸的眼神问题更不显眼。

---

### 4.6 光过分完美（Too-Perfect / Flat Lighting）

**特征描述**：整张图光线均匀到不自然、没有阴影衰减、没有光比、没有方向感，画面「飘」着，像棚拍后期合成。

**为什么是 AI 告密**：真实光源（太阳 / 窗 / 灯）都有**方向和衰减**，必然产生阴影和高光的对比。扩散模型的默认光是「均匀柔光」（loss 最低、最安全），于是输出常是「平光」——缺乏光影层次（详见 `craft.md` 1.1 + 第二节）。这种光让产品显得「假」、没体积感。

**视觉 checklist**：
- [ ] 能看出光从哪个方向来？
- [ ] 有明确的高光区和阴影区（光比）？
- [ ] 阴影有自然的衰减（软边），不是「一刀切」？
- [ ] 物体有体积感，不是「扁平贴在背景上」？

**命中后建议**：
- 加具体光位 + 光比：`soft daylight from camera-left at 45°, gentle shadow falloff on the right`（→ `craft.md` 2.1 三要素）
- 品类匹配光照：数码用硬光打 specular、食品用侧光打纹理（→ `craft.md` 2.2 品类速查）
- 避免 `even lighting` / `flat lighting` 这种把光推向平光的词。

---

### 4.7 背景超现实 / 不可能几何（Impossible / Surreal Background）

**特征描述**：背景里的物体几何不可能（弯曲的直线、不可能的透视）、物体「融化」、背景道具凭空出现 / 消失、文字乱码、反光里有不合理的内容。

**为什么是 AI 告密**：扩散模型不理解「物理 / 几何 / 空间」，它只还原「视觉风格」。所以背景里的一把椅子可能腿数不对、一面墙的透视可能扭曲、桌上的书本文字是乱码——这些是模型不懂世界规律的证据。**主图 / 白底图（纯底）几乎不会触发本条**，**场景图 / 生活图 / A+ 故事模块**高频触发。

**视觉 checklist**：
- [ ] 背景物体的几何合理（直线直、透视一致）？
- [ ] 背景里没有「融化」或凭空拼接的物体？
- [ ] 反光面（镜子 / 玻璃 / 金属）里反射的内容合理？
- [ ] 背景里的文字 / logo 是合理内容，不是乱码？

**命中后建议**：
- 简化背景：纯底 / 渐变底 / 单一干净道具（减少出错机会）。
- 加：`clean simple background, minimal props, realistic perspective`
- 场景图改用参考图锚定（`--image` 传真实场景照）。
- 不可能几何若出现在关键区域（产品旁）→ 必须重做；在边角失焦区 → 可接受。

---

### 4.8 文字乱码 / 莫名水印（Gibberish Text / Phantom Watermarks）

**特征描述**：图里的文字是乱码（不是预期的词）、出现莫名的水印 / logo / 签名、包装上印着不存在的字符。

**为什么是 AI 告密**：如 `craft.md` 5.1 所述，扩散模型是「画字」不是「写字」，对长词 / 生僻词 / 包装小字准确率低。同时模型见过的电商图常带 watermark / logo，训练 bias 让它习惯性「加一点」——即便你没要求。

**视觉 checklist**：
- [ ] 图中所有文字都是预期内容（拼写正确）？
- [ ] 没有莫名出现的 watermark / logo / 签名？
- [ ] 产品包装上的文字合理（不是乱码字符）？
- [ ] Amazon 主图：图中无任何文字（平台禁文字）？

**命中后建议**：
- 文字错 → 套文字渲染三招（→ `craft.md` 5.2）：引号 + ALL CAPS、逐字母拼写、`no extra words`。
- 莫名 watermark → 加：`no watermark, no logo, no signature, no overlay text`。
- Amazon 主图一旦出现文字 → 直接违规，必须重做并加 `no text in image`。

---

### 第二层使用纪律

1. **一轮一改**：扫出多个 AI-tell 时，**只改最严重的一个**重生成，不要堆叠多个修改（堆叠会让 prompt 失控）。
2. **优先级**：多指多肢 / 文字乱码 / Amazon 主图违规 > 眼神空洞 / 塑料肤质 > 光平 / 对称 > 背景超现实（边角可接受）。
3. **三次重做仍命中**：建议绕开——改用参考图锚定、换场景方案、或建议实拍 + AI 辅助。AI 模型对某些特征（手指 / 眼神）目前不是 100% 可靠，工程化绕开比硬逼模型更高效。
4. **轻微可接受**：不是所有 AI-tell 都要重做——UGC 场景的「轻微不完美」反而增加真实感。判断标准：**买家第一眼会不会觉得假**。会 → 重做；不会 → 接受。
5. **品类判断**：主图 / A+ 精修图的标准最严（任何 AI-tell 都不接受）；UGC / 直播 / 社交图的标准最宽（轻微 AI-tell 在「真实感」里反而无害）。

---

*本文件为 ecom-image2 质量护栏单一真理源。新增品类、slop 词、AI-tell 视觉特征请直接在此文件维护，不要在 SKILL.md 或 scenarios/*.json 中重复定义。*
