# Craft — 电商做图工艺清单（「为什么」层）

> 模板（`scenarios/*.json`）告诉你「写什么」，本文件告诉你**「为什么这样写」**。
> 蒸馏 GPT-Image-2/2.5 电商做图的原理性知识：五要素组装、反 AI 感、光照、材质、构图、文字渲染、编辑保真、品类策略。
> 参考生态顶流的 craft 理念：不堆规则，讲原理——让 Claude 理解之后，遇到新场景能自己推理，而不是死记清单。

---

## 何时查这个文件

| 时机 | 查哪节 |
|---|---|
| 组装 prompt 前想一遍整体骨架 | 〇、五要素组装法则 |
| 出图有「AI 味」、不够真实、像广告大片不像实拍 | 一、反 AI 感工艺 |
| 产品质感不对（金属不亮 / 肤质不够好 / 食物没食欲 / 玻璃没通透感） | 二、光照工艺 + 三、材质表达 |
| 构图别扭、主体不突出、留白出错、被平台裁掉关键信息 | 四、构图工艺 |
| 信息图 / A+ / 海报上的文字渲染出错（乱码 / 多字母 / 错字） | 五、文字渲染三招 |
| 编辑类任务改错东西（动了不该动的标签/logo/形状） | 七、编辑保真工艺 |
| 接触新品类，不知道该抓哪个视觉关键 | 六、品类视觉策略 |
| Step 7 质量自检 | 全文 + `style-blacklist.md` 第二层（AI-tell 视觉特征） |

---

## 目录

0. [五要素组装法则](#〇五要素组装法则)
1. [反 AI 感工艺](#一反-ai-感工艺)
2. [光照工艺](#二光照工艺)
3. [材质表达工艺](#三材质表达工艺)
4. [构图工艺](#四构图工艺)
5. [文字渲染三招](#五文字渲染三招)
6. [品类视觉策略](#六品类视觉策略)
7. [编辑保真工艺](#七编辑保真工艺)
8. [附：工艺自检 checklist](#附工艺自检-checklist)

---

## 〇、五要素组装法则（GPT-Image-2.5 基线）

每条生产级 prompt 是一份**短生产简报**，五要素齐了图就稳（社区实测配方与官方 prompting guide 的共同收敛）：

| 要素 | 写什么 | 示例 |
|---|---|---|
| **Subject** | 主体 + **材质**（不是形容词） | `matte ceramic espresso cup`，不是 `nice cup` |
| **Material-first** | 材质优先于形容词——命名材质本身 | `frosted glass with amber serum` |
| **Light** | 光必须显式写（不写=发灰发闷） | `soft window light` / `dramatic backlight` |
| **Lens / ratio** | 镜头语言 + 构图锁定 | `85mm lens look` / `overhead flat lay` / `centered composition` |
| **Finish** | 收尾词控制风格化程度 | `clay render finish` / `painterly detail` / `commercial product photography` |

**为什么材质优先**：模型对「材质名词」的像素还原远稳于「形容词」——`matte ceramic` 给了表面反射率/质感/光泽三重物理约束，`elegant` 什么约束都没给。这与 5-slot 的 [Subject]/[Important details] 槽对应：组装时检查材质是否已点名，没点名就补。

**总纲**："Name the material, not the adjective. / Set the light explicitly. / Pin the framing."

---

## 一、反 AI 感工艺

### 1.1 为什么 GPT-Image-2 默认出图有「AI 味」

扩散模型不是「拍照」，是「从噪声里逐步去噪还原概率分布」。它输出的是**训练分布的统计平均**——而它见过的「产品图 / 人像图」大多是**修图后的广告大片、影棚精修、社交媒体高赞图**。于是模型的「默认值」就是这些被修过的图的样子。这就是 AI 味的根源：**模型学到的「好」=「被修过的好」**，而不是「真实的好」。

具体表现为四类典型 AI-tell（出图后能看出来的「告密特征」）：

| AI-tell | 成因（为什么模型会这样） | 视觉表现 |
|---|---|---|
| **塑料肤质**（plastic skin） | 训练数据里的「好皮肤」图大多经过磨皮修图，模型学到的「skin」=「平滑无毛孔、无 peach fuzz」 | 皮肤像打蜡、毛孔消失、肤色过度均匀 |
| **对称偏执**（symmetry obsession） | 正面构图在训练数据里占多数；扩散损失函数偏好「平均脸 / 平均姿态」（平均后对称度上升） | 脸左右完全对称、双臂角度一模一样、构图死板居中 |
| **边缘融合**（edge fusion） | 去噪时相邻像素一起预测，物体边界容易「糊」在一起；物体越多越容易融 | 手指融合、产品边缘融进背景、主体和道具黏在一起 |
| **光过分完美**（too-perfect lighting） | 均匀柔光的 loss 最低（最「安全」），模型默认给「无光比、无阴影衰减」的平光 | 阴影太柔太匀、没有自然的光影变化、整张图「飘」 |

> **核心认知**：AI 味不是「某个 slop 词造成的」，是**模型的默认统计输出**。要克服它，必须主动用 prompt 把输出**拉离这个默认分布**——往「真实世界的不完美」方向拉。

### 1.2 六招对策（每招讲清原理，不是规则堆砌）

#### 招 1：指定具体拍摄设备（手机型号 / 镜头焦段）

```
shot on iPhone 15 Pro
shot on 35mm lens, slight chromatic aberration
```

**为什么有效**：把输出锚定到「业余 / 纪实设备」的概率分布，**远离**「中画幅影棚广告」的分布。模型见到 `iPhone 15 Pro` 会下调画质预期、加上手机摄影的特征（轻微噪点、暖色偏、不完美的动态范围），这些恰恰是「真实」的信号。写 `professional photography` 反而把分布推向修图广告片——这就是它进 slop 黑名单的原因。

**品类适用**：UGC / 直播 / 社交 / 买家秀场景必用。主图 / A+ 等精修场景**不用**（那里要的是干净专业）。

#### 招 2：引用胶片色调

```
Kodak Portra 400 color feel
Fujifilm Superia color palette
subtle film grain
```

**为什么有效**：胶片有**颗粒结构和色偏**（Portra 偏暖、Superia 偏绿、Ektar 饱和度高），这些会破坏模型「干净平滑」的默认偏好。颗粒是高频细节，模型无法用「磨皮」逻辑处理它，于是被迫输出有纹理的画面。注意写 `subtle`——重度胶片颗粒对电商产品图是干扰。

#### 招 3：显式注入「可见瑕疵」

```
visible pores, peach fuzz, slight smile lines
natural skin texture with even tone (NOT blemish-free)
subtle fabric wrinkle, slight reflection on surface
```

**为什么有效**：模型默认会**抹掉**瑕疵（因为训练数据修过图）。显式写出来，是给模型一个「保留这些高频细节」的正向指令。关键是写**真实的**瑕疵（毛孔、细纹、轻微褶皱、轻微反光），不是写「damaged / dirty」（那会过界）。

> 这也是为什么 slop 词 `flawless / perfect / blemish-free` 杀伤力最大——它们是「抹掉瑕疵」的强指令，直接把肤质推向塑料感。

#### 招 4：纪实语言（NOT 声明）

```
NOT professional photography
NOT AI-generated look
NOT retouched, NOT smoothed
unedited, raw phone photo feel
```

**为什么有效**：扩散模型能理解**负向条件**（它知道「NOT professional」意味着要从专业分布里**移开**）。声明「不是什么」比声明「是什么」更有效——因为「是什么」的词（如 `candid` `amateur`）在训练里常被滥用成标签噪声，而 `NOT X` 是明确的排除信号。这条对 UGC 场景尤其关键。

#### 招 5：真实环境（打破影棚默认）

```
slightly messy bathroom shelf
used towel on the side
water drops on the mirror
half-empty coffee cup in background (slightly out of focus)
```

**为什么有效**：模型的默认场景是「干净影棚」或「完美 styling 的场景」。加入「使用痕迹 / 轻微凌乱」会强制场景偏离默认——真实生活就是有水渍、有杂物、有使用过的。注意 `slightly`——不是脏乱差，是「有人在用」的痕迹。

#### 招 6：不对称 / 非完美构图

```
candid angle, slightly off-center composition
natural posture, not posed
subject looking slightly away from camera
```

**为什么有效**：直接对抗模型的「对称偏执」（见 1.1）。电商主图需要居中对称（那是平台约束），但 UGC / 场景图 / 模特图需要打破对称才有「抓拍感」。

### 1.3 反 AI 感 prompt 范式（UGC / 直播 / 社交专用）

把六招组合起来，形成固定范式：

```
[设备] shot on iPhone 15 Pro, [胶片] Kodak Portra 400 color feel,
[瑕疵] visible pores and natural skin texture, [环境] slightly messy real bathroom,
[构图] candid off-center angle, [声明] NOT retouched, NOT professional photography,
no studio lighting.
```

> **何时用这个范式**：UGC 买家秀、直播截图、社交媒体、素人测评。**何时不用**：Amazon 主图（要纯白底精修）、A+ 信息图（要清晰干净）、品牌大片（要高端）。反 AI 感是场景驱动的，不是所有图都要「真实」。

---

## 二、光照工艺

光照是电商图的**第一质感决定因素**——比材质描述还重要。同一个产品，换光就换质感。模型不会自己「打光」，它的默认光是偏「均匀柔光」（最安全、loss 最低），你必须主动指定。

### 2.1 光照三要素

每条 prompt 的光照描述应覆盖这三要素，缺一就容易退回默认平光：

| 要素 | 取值 | 对产品质感的影响 |
|---|---|---|
| **方向**（direction） | 顺光（front）/ 侧光（side）/ 逆光（back）/ 顶光（top）/ 底光（bottom） | 顺光显色但平、侧光显纹理、逆光显轮廓（rim/halo）、顶光显深度 |
| **质感**（quality） | 硬光（hard）/ 柔光（soft）/ 漫射（diffuse） | 硬光=清晰硬阴影（显金属/玻璃棱角）；柔光=渐变软阴影（显肤质）；漫射=几乎无影（显色彩） |
| **强度 / 光比**（intensity / ratio） | 高光比（high contrast）/ 低光比（low contrast） | 高光比=drama、低光比=柔和 |

**写法模板**：`[质感] [方向] from [位置], [强度描述]`

```
soft side lighting from camera-left at 45°, gentle shadow falloff on the right
hard top light with crisp specular highlights on metal
diffused daylight, even illumination, minimal shadow
```

### 2.2 品类 × 光照速查（每品类的「黄金光」）

| 品类 | 黄金光 | 为什么 |
|---|---|---|
| **美妆 / 护肤** | 柔光 + 顺光 / 微侧（soft front, slight side） | 硬阴影会暴露肤质瑕疵，柔顺光让肤色均匀通透、显「光泽感」 |
| **食品** | 侧光 + 暖色（warm side light, 45° backlight） | 食欲感来自**阴影**——侧光突出食物的纹理、油光、蒸汽，顺光会让食物显得扁平没食欲 |
| **数码 / 3C** | 硬光 + 侧 / 顶（hard side / top light） | 金属 / 玻璃 / 塑料的**高光反射点**是质感来源，硬光能打出 crisp specular highlights，柔光会让数码产品显得「塑料感」 |
| **珠宝** | 聚光 + 柔光组合（spot + soft combo） | 聚光打出宝石折射火彩，柔光还原金属光泽，单一光位会损失一层 |
| **服装** | 柔侧光（soft side light） | 显面料垂坠感和褶皱，顺光会让面料显得扁平 |
| **家居** | 暖漫射 + 生活光（warm diffused interior light） | 显「家」的温度，硬光会让家居显得像 showroom 不像家 |
| **运动** | 硬侧光 + 高对比（hard side, high contrast） | 强调肌肉线条、汗水、装备棱角，柔光会削弱力量感 |

### 2.3 光照词典（写进 prompt 的具体词）

**方向**：
- `front lighting`（顺光）/ `side lighting`（侧光）/ `backlight` / `rim light`（逆光 / 边缘光）/ `top lighting` / `underlighting`

**质感**：
- `hard light` / `soft light` / `diffused light` / `overcast daylight`（漫射自然光）
- `specular highlight`（镜面高光——数码 / 珠宝必写）/ `gentle shadow falloff`（柔和阴影衰减——美妆必写）

**光位（精确）**：
- `from camera-left at 45°` / `from upper right` / `from behind the subject`
- `key light`（主光）/ `fill light`（补光）/ `hair light`（发丝光——模特图用）

**自然光参照**：
- `window light`（窗光——食品 / 家居常用）/ `golden hour`（黄金时段——户外场景）/ `overcast soft daylight`（阴天柔光——美妆）/ `blue hour`（蓝调时段——科技感）

> **为什么写 `from camera-left at 45°` 比写 `soft lighting` 有效**：模型见到 `soft lighting` 会给一个「平均柔光」；见到具体角度会**在那个方向放光源**，产生有方向的光影——而有方向的光才有质感。笼统词 → 平均光 → 平淡；具体词 → 方向光 → 质感。

---

## 三、材质表达工艺

### 3.1 为什么「写具体」比「写笼统」有效

模型见到笼统词（`metal` `glass` `fabric`）会**猜一个默认材质**——通常是训练里最常见的那个（metal→亮银色不锈钢、glass→透明玻璃杯）。结果你想要的是**拉丝铝合金**，出来的是**镜面不锈钢**。

**机制**：笼统词对应一个**宽分布**（很多种子材质），模型输出分布的「期望值」（平均）通常是 dull / safe 的那个。具体词（`brushed aluminum`）把分布**收窄到一个点**，输出就锁死在你想要的材质上。

> **工艺要点**：材质描述要精确到**工艺 + 表面处理 + 颜色**三层，不止「是什么材料」。

### 3.2 材质描述词典

| 笼统（避免） | 精确写法（推荐） | 为什么精确有效 |
|---|---|---|
| `metal` | `brushed aluminum` / `polished chrome` / `matte titanium` / `gunmetal finish` | 锁定工艺（拉丝 / 抛光 / 哑光）+ 金属种类 |
| `glass` | `frosted glass`（磨砂）/ `borosilicate glass`（高硼硅——显高级）/ `clear tempered glass` / `tinted glass` | 锁定透明度 + 玻璃种类 |
| `plastic` | `matte ABS finish` / `glossy polycarbonate` / `soft-touch rubber coating` | 锁定质感（塑料也有哑光 / 光面 / 类肤涂层） |
| `fabric` | `linen weave` / `bouclé texture` / `velvet pile` / `denim` / `merino wool knit` | 锁定织法 + 纤维 |
| `wood` | `oak with visible grain` / `walnut matte finish` / `bamboo` / `reclaimed wood with knots` | 锁定木种 + 表面 + 是否有自然特征 |
| `leather` | `full-grain leather with natural marks` / `nubuck` / `pebbled leather` / `vegan leather` | 锁定皮革工艺 + 是否有自然瑕疵 |
| `ceramic` | `matte glazed ceramic` / `porcelain with subtle crackle` / `terracotta` | 锁定釉面 + 陶种 |
| `stone` | `honed marble`（哑光大理石）/ `polished marble` / `concrete with aggregate` | 锁定表面处理（哑光 / 抛光） |

> **附加技巧**：加一个**反光描述**让材质更立体。金属 / 玻璃写 `crisp specular highlights`；哑光材质写 `soft, non-reflective surface`；皮革写 `subtle sheen`。

### 3.3 材质 × 光照组合（关键工艺）

材质不是孤立表达的——**同样的材质在不同光下质感完全不同**。正确的做法是材质描述 + 匹配的光照：

| 材质 | 匹配光照 | 为什么 |
|---|---|---|
| 金属（任何） | 硬光 / 侧光 | 金属质感来自**高光反射点**，硬光才能打出 crisp specular，柔光会让金属显得发灰 |
| 玻璃 | 逆光 / 侧逆光 | 玻璃的通透感来自**穿过它的光**，逆光显透明度和折射，顺光只剩反光 |
| 哑光材质（ABS matte / 哑光陶瓷） | 柔光 / 漫射 | 哑光面没有高光，硬光会产生刺眼的小亮点，柔光显均匀 |
| 丝绒 / 天鹅绒 | 侧光 + 柔光 | 丝绒的「绒毛光泽」只在侧光下出现，这是它的灵魂质感 |
| 皮革 | 侧光 + 柔光 | 侧光显纹理和自然标记，柔光避免反光过度 |

> **反例**：写 `metal product` + `soft diffused lighting` 出来一定是「灰扑扑的塑料感金属」。这两个槽位冲突时，材质永远不会还原——这是最常见的「产品质感不对」原因。

---

## 四、构图工艺

电商构图不只是「好看」，它要服务于**转化**和**平台约束**。同一个产品，电商构图和杂志构图逻辑不同——电商优先「主体清晰 + 信息直达」，杂志优先「氛围 + 留白」。

### 4.1 视线引导（让买家第一眼看对地方）

**原理**：人眼按特定顺序扫一张图——先看**高对比区**、再**亮区**、再**人脸 / 人物视线方向**、再**引导线指向的地方**。电商图要利用这个顺序，把买家视线**引到产品 / 卖点上**。

| 引导技法 | prompt 写法 | 适用场景 |
|---|---|---|
| 主体居中（最直接） | `centered composition, product fills the frame` | 主图、白底图（平台也要求居中） |
| 三分法 | `rule of thirds composition, product at upper-right intersection` | 场景图、生活图 |
| 引导线 | `leading lines from bottom corners pointing to the product` | 场景图、家具图 |
| 色彩对比 | `product in brand red against neutral beige background`（产品用强调色，背景用中性色） | 全场景通用 |
| 人物视线引导 | `model looking toward the product` | 模特图（人眼会跟着模特视线走） |

### 4.2 留白与占比

**留白的两个功能**：
1. **给平台 overlay 留位置**——Amazon / TikTok 搜索结果页会在图上叠文字、价格、按钮，主体顶满四边会被裁掉关键信息
2. **呼吸感**——满构图显得廉价，适度留白显得高级

**Amazon 85% 占比规则的「双重身份」**：
- 它是**平台硬约束**（主体 ≥85% 画面，背景接近纯白）——见 `platform-constraints.md`
- 它也是**构图工艺**——主体大才看得清细节、才「主角感」强

> 但要注意：85% 是**主体占比**，不是「填满整个画面不留缝」。主体四周仍要留少量纯白 padding（约 7-8%），避免边缘被平台裁切。写法：`product centered, fills ~85% of frame, small white margin around`。

### 4.3 电商构图三式

| 构图式 | 特征 | 适用 |
|---|---|---|
| **主图式**（hero） | 居中、纯底、主体大、正投影、无干扰 | 主图、白底图、A+ 主视觉 |
| **场景式**（lifestyle） | 产品置于使用场景、有道具 / 人物、三分法或引导线 | 场景图、A+ 故事模块、社交图 |
| **信息式**（infographic） | 产品 + 标注 / 卖点框 / 对比图、结构化网格 | 信息图、卖点图、对比图、尺寸图 |

**信息式构图的特殊工艺**：标注线 / 卖点框要**围绕产品**布局，不要遮住产品关键部位。写法：`callout labels around the product (not overlapping it), clean sans-serif typography`。

---

## 五、文字渲染三招

### 5.1 为什么 GPT-Image-2 渲染文字容易错

**机制**：扩散模型**不是文字渲染器**——它不「写字」，它是「**画**字」（像素级还原）。这意味着：
- 它没有「字符」概念，只有「**这些像素看起来像字母 A**」
- **长词**（≥6 字母）容易错，因为像素组合更复杂
- **小字**容易糊，因为分辨率不够
- **混合大小写**容易错，因为模型要同时画大写和小写两套像素
- **生僻词 / 品牌名**错率最高，因为训练数据里见得少

**统计规律**（指导三招）：
- ALL CAPS 短词（≤4 字母，如 `NEW` `SALE` `HOT`）准确率最高
- 全大写比混合大小写好
- 引号包裹比裸写好（模型识别为「这是一个整体 token」）
- 逐字母拼写比整词好（强迫模型一个字母一个字母画）

### 5.2 文字渲染三招（按优先级）

> 模板的 `text_assets` 字段（brand_name / selling_points / price / copy）在 Step 5 组装时会**自动**应用这三招。

#### 招 1：自动包引号 + ALL CAPS

把所有要渲染的文字：
- 用英文双引号包裹（`"BRAND NAME"`）
- 转成全大写（`brand name` → `"BRAND NAME"`）

```
render the text "NEW ARRIVAL" on the banner
```

**为什么有效**：引号告诉模型「这是一个不可拆分的文字单元」，降低它「再创作」的概率（裸写时模型会以为是描述词，可能改字）。ALL CAPS 让每个字母都是同一套像素 pattern，降低混合大小写的复杂度。

#### 招 2：逐字母回退（letter-by-letter spelling）

当品牌名 / 卖点词较长（≥5 字母）或第一次渲染出错时，用连字符逐字母拼写：

```
render the text "B-R-A-N-D" spelled letter by letter, left to right
```

**为什么有效**：把「画一个长词」拆解成「画 N 个独立字母」，每个字母是独立的像素任务，准确率远高于整词。这是目前对付长词 / 品牌名错乱最有效的兜底招。

**何时用**：招 1 出图后文字错了 → 重试时切到招 2。或品牌名已知是长词，直接上招 2。

#### 招 3：「no extra words」（禁止添加多余文字）

```
render exactly the text "SALE 50% OFF", no extra words, no additional text anywhere in the image
```

**为什么有效**：模型有个坏习惯——你让它写 `SALE`，它会自作主张在旁边加上 `NEW!` `HOT!` `BEST PRICE`（因为训练数据里的促销图常这样）。`no extra words` 是明确禁止这个行为。

**适用**：所有含文字的图，尤其是 Amazon 主图（平台禁文字，一旦模型加了多余文字就违规）。

### 5.3 何时启用三招 + 何时绕开

| 场景 | 策略 |
|---|---|
| 信息图 / A+ / 卖点图（必须含文字） | 三招全上（`text_assets` 字段自动处理） |
| Amazon 主图（平台禁文字） | 招 3（`no extra words, no text in image`）——防止模型擅自加字违规 |
| 海报 / banner（文字是设计元素） | 招 1 + 招 3，文字尽量短（≤4 字母词最稳） |
| UGC / 场景图（不该有明显文字） | 招 3（`no overlay text, no watermark`）——防止模型加假水印 / logo |
| 纯产品白底图 | 通常不需要文字处理 |

> **兜底原则**：如果文字渲染三次都错，建议**不在图里渲染文字**——改为生成无文字底图，后续用 Figma / PS 叠文字（这是电商设计的标准工作流，图内文字本就不是最佳实践）。AI 渲染文字目前还不是 100% 可靠，工程化绕开比硬逼模型更高效。

### 5.4 GPT-Image-2.5 增量（官方印证 + 新规则）

官方 prompting guide 对 2.5 的文字建议，与三招的关系：

- **招 1 / 招 2 被官方背书**：官方同样要求「必须出现的文案放引号里」「生僻词/品牌名逐字母拼写」——三招方向不变，2.5 上继续用
- **新增规则 ①次数与位置**：文案多时说明每段文字出现几次、在哪个位置（`"SALE 50% OFF" once, top-left corner`）——位置不写，模型自己乱摆
- **新增规则 ②小字密集用中高对比**：官方建议小字/密集信息的图多用 medium 或 high 对比（contrast），低对比小字最先糊
- **能力边界（官方自认）**：2.5 官方 Limitations 原文仍承认 "can still struggle with precise text placement and clarity"——文字渲染依然不是 100%，**兜底原则（5.3 末）不因升级而失效**

---

## 六、品类视觉策略

每品类有一个**视觉关键**——抓住它，图的转化力就有了。下面讲每个品类的视觉关键 + 为什么。

| 品类 | 视觉关键 | 为什么是这个 | 关键 prompt 锚点 |
|---|---|---|---|
| **美妆 / 护肤** | 肤质（skin texture） | 美妆买的本质是「用后变好的皮肤」，图必须让肤质可信——塑料肤质 = 产品不可信 | `visible pores, dewy glow, natural skin texture, soft front light` |
| **数码 / 3C** | 金属 / 材质感（material feel） | 数码产品溢价靠「工艺感」，图必须让人感受到材质是高级的（拉丝 / 哑光 / 棱角），塑料感 = 廉价 | `brushed aluminum, crisp specular highlights, hard side light` |
| **食品** | 食欲感（appetite appeal） | 食品图只有一个标准：让人看了想吃。食欲感来自**湿润度 + 蒸汽 + 色彩饱和 + 阴影纹理**，不是「摆得好看」 | `juicy, steaming, crispy texture, warm side light, fresh ingredients` |
| **时尚 / 服装** | 质感 + 穿搭感（drape + styling） | 服装图不能只拍衣服，要拍「穿在真人 / 模特身上的样子」，面料垂坠 + 搭配场景才有购买欲 | `fabric drape, visible stitching, styled outfit, soft side light` |
| **家居** | 生活温度（lived-in warmth） | 家居图要让人感觉「这是我的家」，不是 showroom——暖光 + 真实生活道具 + 自然木纹 | `warm interior light, natural wood texture, cozy lived-in scene` |
| **珠宝** | 光泽与折射（brilliance & fire） | 珠宝的价值感全在「闪」——宝石的火彩（fire）+ 金属的光泽（luster），拍不出来 = 卖不出价 | `sparkling highlights, brilliant facets, spot + soft combo light` |
| **运动** | 动态与力量（motion & power） | 运动产品的卖点是「让你更强」——图必须有汗水 / 动作 / 肌肉线条，静态会削弱产品力 | `dynamic action, motion blur, sweat detail, high contrast hard light` |

### 品类冲突的优先级

当产品跨品类（如「运动手表」= 数码 + 运动）时，**以主导卖点定品类策略**：
- 运动手表主打「科技感」→ 走数码策略（金属 / 硬光）
- 运动手表主打「运动场景」→ 走运动策略（动态 / 汗水）

判断标准：**Listing 标题和前 3 条卖点里出现频次更高的属性**，通常就是主导卖点。详细冲突避免见 `style-blacklist.md` 第一节。

---

## 七、编辑保真工艺（GPT-Image-2.5 编辑类任务）

> 何时用：所有「改一部分、保一部分」的任务——换背景/换色/换季/本地化/蒙版局部改（edit 矩阵）、爆款换品、模特替换。2.5 的核心卖点「精准编辑」就吃这套写法。

### 7.1 编辑 prompt 的黄金结构：change only X + preserve list

官方编辑规范一句话：**只说要改的，逐项列出要保的**。

```
Replace only the background with {scene}.
Keep unchanged: product shape, proportions, {color} packaging, cap, logo,
label text, material, and visible details.
Match the new background's lighting and contact shadows naturally.
Do not redesign, relabel, duplicate, or obscure the product.
```

（与官方 "change only X + 列出 preserve（identity/geometry/layout/lighting/labels）" 建议一致）

**为什么 preserve list 要逐项写**：模型不知道你的业务底线——「保持产品不变」是模糊指令，`logo, label text, cap, proportions` 才是可核对的像素清单。漏写的项就是会被改掉的项。

### 7.2 参考图角色分配（Image N: role）

多张参考图时**按编号分配角色**（官方建议），每张说清它是谁、保什么：

```
Image 1: my product — preserve logo, color, shape, texture exactly
Image 2: background style reference — take only the scene/lighting mood
```

- 角色不声明 → 模型把两张图的内容「融合」，产品和背景互相污染
- 这与模板 `ref_roles` 字段（Step 5 手动注入）是同一机制，此处讲清为什么

### 7.3 像素级不变的极限

官方明示：mask 与 prompt 都不能保证像素级不变（"Masking is entirely prompt-based... may not follow its exact shape"）。**必须像素级一致的区域**（如已过法务审核的标签文案）→ 官方建议把审核过的素材合成回原图，别指望生成模型。

### 7.4 编辑任务一律走 Sunburst

保产品/标签/logo 的编辑是 sunburst 的定义场景（见 `model-routing.md`）——flare 在多次迭代中保持主体一致性的能力弱于 sunburst，编辑类任务不要用 flare 省钱，改错标签的代价比差价大。

---

出图后（Step 7 质量自检）对照这个清单。命中任何一条 → 回到对应章节调 prompt 重生成（一轮一改纪律）。

**反 AI 感**（适用 UGC / 直播 / 社交）：
- [ ] 皮肤有毛孔 / 纹理，不是塑料感？（→ 1.2 招 3）
- [ ] 构图不是死板对称？（→ 1.2 招 6）
- [ ] 物体边缘清晰没融合？（→ 1.1 边缘融合）
- [ ] 光影有自然变化，不是平光？（→ 1.2 招 1-2）

**光照**：
- [ ] 光照方向明确？（→ 2.1 三要素）
- [ ] 光照质感匹配品类？（金属硬光 / 肤质柔光 / 食物侧光）（→ 2.2 速查）

**材质**：
- [ ] 材质描述精确到工艺 + 表面处理？（→ 3.2 词典）
- [ ] 材质和光照匹配？（金属别配柔光）（→ 3.3 组合表）

**构图**：
- [ ] 主体居中且占比合适？（主图 ≥85%）（→ 4.2）
- [ ] 关键信息不会被平台 overlay 裁掉？（→ 4.2 留白）

**文字**（含文字的图）：
- [ ] 文字全大写 + 引号？（→ 5.2 招 1）
- [ ] 长词是否需要逐字母拼写？（→ 5.2 招 2）
- [ ] 有没有多余的文字 / 水印？（→ 5.2 招 3）

**品类视觉关键**：
- [ ] 抓住了该品类的视觉关键？（→ 六、品类策略）

> **更细的视觉特征判断**（塑料肤质 / 多指 / 空洞眼神等 AI-tell 特征）见 `style-blacklist.md` 第二层（AI-tell 视觉特征过滤）。

---

*本文件是模板之上的「为什么」层。新增工艺原理请在此维护，不要把工艺知识散落在 SKILL.md 或 scenarios/*.json。模板讲「写什么」，本文件讲「为什么这样写」。*
