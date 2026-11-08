# 美术生产线交付说明 / ART PRODUCTION BRIEF
## 项目：SCI-FI SHIP 俯视角射击（Godot 4.7 / Windows / 1920×1080）

版本：v1.0  
适用阶段：第一批资产已验收，第二批「场景结构件 + 宇航员 8 向 + 射击特效」  
现有资产目录：`art_placeholder/scifi_ship/`  
参考图：
- `art_placeholder/scifi_ship/_scene_mockup.png`（构图 / 素材使用方式）
- `art_placeholder/scifi_ship/_contact_sheet.png`（风格基准）
- `art_placeholder/00_style_probe/duck_style_probe_512.png`（仅参考描边粗细与可爱比例，不是角色设定）

---

## 1. 项目与视角

- 2D 俯视 2.5D 射击游戏，角色全身可见，场景为深色金属飞船内舱。
- 视角：3/4 俯视，相机仰角约 30°~35°，所有资产必须共享同一地平线。
- 禁止：纯顶视（看不到墙立面）、45° 等距、正面横版、写实照片风。
- 引擎会对地面做 0.72 的纵向压缩，墙体/道具/角色保持直立。**不要在素材里预先压扁地面**，交付正方形顶视地砖即可。
- 游戏内镜头缩放 1.3~1.4；资产需要在缩小到约 25% 时仍能读懂轮廓。

## 2. 比例规范（重要）

| 对象 | 游戏内世界高度 | 源文件建议 |
|---|---|---|
| 1 个地砖 | 384 世界单位 | 512×512 px |
| 气闸门 | 约 300 | 512×512 px（内容高度约 400） |
| 宇航员 | 约 150 | 单帧 384×384 px（含透明边距） |
| 控制台 | 约 300 | 512×512 px |
| 大货箱 | 约 170 | 256×256 px |
| 反应堆 | 约 380 | 512×512 px |
| 管道束 | 约 180 | 256×256 px |

- 所有站立类资产：**底边中心 = 地面接触点**，透明背景，不烘焙地面。
- 角色身高约为门的 1/2，货箱约为角色身高的 1.1 倍。
- 交付时附一张「比例参考图」：门 + 宇航员 + 货箱 + 控制台站在同一条基线上。

## 3. 视觉风格

关键词：半写实硬表面、深色枪械金属、倒角面板、青色能量灯、琥珀警示灯、厚描边、干净卡通比例、工业飞船。

建议色板（可微调，需整套统一）：
- 枪金属 `#242A33`
- 钢板 `#39424F`
- 边缘高光 `#5C6B7E`
- 青色发光 `#39D6E8` / 深青 `#1B7E8C`
- 琥珀警示 `#F2A63B`
- 警示黄 `#D8B23A`
- 锈红管道 `#7C3B33`
- 宇航服米白 `#EDE6D6`，橙色点缀 `#F08A3C`，面罩深青 `#1D3A44`

要求：
- 主光源统一来自左上；允许烘焙 AO/倒角高光，**不允许烘焙地面投影**。
- 发光条不要过曝，不要整屏 bloom；素材本身保持可读的中间调。
- 磨损、划痕、污渍要克制，不能破坏可平铺和轮廓。
- 禁止：照片纹理、赛博朋克过量霓虹、日式二次元、纯黑轮廓糊成一团、细线小于 2px（512 画布下）。

## 4. 现有资产与用途

| 文件 | 用途 | 当前问题 |
|---|---|---|
| `floor_corridor.png` | 主地面，四方连续 | 可用 |
| `floor_engineering.png` | 右侧工程格栅区 | 可用 |
| `wall_segment.png` | 北侧墙段，横向平铺 6 段 | 只有正面墙，无侧墙/转角 |
| `door_airlock.png` | 北墙中央气闸门（装饰，封闭） | 无门框、无开门状态 |
| `console_terminal.png` | 左右控制台 | 需要变体/亮暗状态 |
| `cargo_crate.png` | 货箱 | 需要尺寸/开合变体 |
| `pipe_bundle.png` | 地面管道 | 与反应堆无接口衔接 |
| `reactor_core.png` | 右侧反应堆 | 需要底座/管道接口 |

## 5. 本批次交付清单

### 优先级 A（阻塞场景完整度）
1. **侧墙 + 转角 + 墙端收口**
   - 侧墙（左右两面）、内转角、外转角、墙端封口
   - 512×512，底边中心锚点，高度与 `wall_segment` 一致
   - 不要通过旋转正面墙来冒充侧墙，需要独立绘制的透视
2. **门框 + 开门状态**
   - `door_frame`：独立门框，可套在墙段上
   - `door_open`：门扇打开/收起后的可通行状态
   - 512×512，含地面门槛/导轨，底边中心锚点
3. **地板过渡与收边**
   - 走廊砖 ↔ 工程格栅的 512×128 过渡条
   - 地板边缘收边、转角件、墙脚压条
   - 明确标注哪条边可平铺
4. **宇航员 8 向动画 + 独立影子**（见第 6 节）
5. **射击特效**（见第 8 节）

### 优先级 B（场景密度）
6. 货箱变体（大/小/开启/不同警示色）
7. 桶、工具箱、货架、长椅、桌椅、异星植物
8. 墙面/顶面件：壁挂控制台、通风口、顶灯、缆线
9. 反应堆配套：底座、管道接口、控制面板
10. 地面贴花：警示条、编号、磨损/污渍（可平铺或独立贴花）

### 优先级 C（后续）
11. 可交互状态：终端正常/激活/损坏、门开关、任务点高亮
12. HUD 图标、准星、小地图边框（若确定走鹅鸭杀式 HUD）

## 6. 宇航员角色规格

- 设定：可爱比例的宇航员，浅色宇航服 + 橙/青点缀，深青面罩，紧凑背包，厚底靴。
- 右手持**能量步枪**：深色枪身 + 青色能量核心；枪口位置在所有方向/帧中固定。
- 8 个方向，顺序固定：
  `S / SE / E / NE / N / NW / W / SW`
- 单帧画布 384×384，透明背景，脚底中心锚点；帧间不裁切、不缩放。
- 动画集：
  - Idle：4 帧/向，循环
  - Walk：8 帧/向，循环，脚底不滑步
  - Shoot：4 帧/向，含后坐，枪口位置固定
  - 下一步：Hit / Death / Reload
- 图集布局（推荐，便于程序读取）：
  - 每个动作一张横向图集：行 = 8 个方向（按上面的顺序），列 = 帧
  - 帧之间留 8px 透明间隔，防止采样串色
  - 若单张过大，可拆成 8 个方向各一张，命名 `astronaut_walk_s.png` 等
- 左右方向不要简单镜像：背包、枪械、面罩高光有不对称细节。
- 角色缩小到 100px 高仍能看出朝向，尤其是 N 与 S 的背包/面罩差异。
- 不烘焙影子；影子单独交付（见第 8 节）。

**角色一致性流程（重要）**
1. 先出一张 8 向 turnaround（全身、静态、同基线、同比例），确认设计。
2. 用已确认的 turnaround 作为参考图，再生成/绘制每个方向的 idle/walk/shoot。
3. 不要指望一次提示词直接产出完整 128 帧图集；先关键帧，后补间。
4. 如使用 AI 生图，请附上参考图，并固定种子/角色描述，减少服装与枪械漂移。

## 7. 场景结构件规格

- 墙体系列必须能无缝拼接：直墙（正面）、侧墙、内转角、外转角、端盖。
- 墙高与 `wall_segment` 一致；顶部有一致的压条/灯带；底部有踢脚线。
- 侧墙需要窄顶面 + 内侧立面，不要用正面墙旋转。
- 门框可叠加在任意墙段上；门洞宽度与门扇匹配；提供开门后的通行状态。
- 地板过渡条需要覆盖两种地砖的接缝，不能出现硬切。
- 所有可平铺件在文件名或 manifest 中标注可重复方向（横向/纵向/四方）。

## 8. 射击与特效资产

| 资产 | 规格 | 说明 |
|---|---|---|
| 枪口火光 | 6 帧，192×192，横向图集 | 叠加用，青色为主，中心白热 |
| 能量弹 | 64×64（或 3 帧 64×64） | 青色发光弹丸，透明背景 |
| 命中火花 | 5 帧，128×128 | 墙体/目标通用，青色 + 少量橙色 |
| 命中标记 | 64×64 | 准星命中反馈，可做 2~3 帧 |
| 准星 | 128×128 | 青色描边，中心留空 |
| 角色影子 | 192×96 / 256×128 | 柔和椭圆，35%~45% 黑，边缘羽化 |
| 道具影子 | 按道具尺寸 | 独立贴花，统一光照方向 |
| 地面光池 | 256×256 或 512×512 | 青色/暖色各一张，叠加用，边缘渐隐 |

- 发光类素材保持透明背景，不要把光晕烘焙到场景贴图上。
- 枪口火光与能量弹的色相必须与角色枪械的发光核心一致。

## 9. 可直接复制的提示词

> 说明：以下英文提示词用于 AI 生图；中文为约束说明。每次生成都请附上 `_contact_sheet.png` 与 `_scene_mockup.png` 作为风格/构图参考。

### 9.1 通用风格前缀（所有环境/道具资产）

```text
semi-stylized sci-fi hard-surface game asset, top-down 3/4 view with 30 degree camera elevation, dark gunmetal steel with beveled panels, cyan emissive light strips, amber warning lamps, subtle scratches, crisp thick outline, soft top-left lighting, no baked cast shadow, transparent background, centered object, 512x512, high readability at small size
```

### 9.2 通用负面提示词

```text
photorealistic, pure top-down, 45 degree isometric, side view only, flat front view, anime, cel-shaded character, oversaturated neon, bloom halo, heavy dirt, baked ground shadow, background scenery, floor included, text, watermark, logo, cropped object, thin lines, noisy texture, inconsistent perspective, duplicate limbs, extra fingers, deformed hands, motion blur
```

### 9.3 地砖（四方连续，正交顶视）

```text
seamless square floor tile for a sci-fi spaceship interior, orthographic top-down view, dark gunmetal panel with recessed center, cyan light strips and small amber bolts, beveled edges, subtle scratches, tileable on all four edges, no shadow, no background, 512x512, game texture
```

工程格栅地板：

```text
seamless square engineering deck floor tile, orthographic top-down view, dark steel frame with diamond grate panels, yellow hazard stripes on top and bottom edges, cyan corner lights, oil stains, tileable on all four edges, no shadow, no background, 512x512, game texture
```

### 9.4 墙体（正面 / 侧墙 / 转角）

正面墙段：

```text
front-facing sci-fi wall segment for a top-down 3/4 game, dark gunmetal panel with beveled frame, recessed center plate, cyan vertical light strips, amber status lamps, heavy top cap and bottom baseboard, transparent background, bottom-center anchor, 512x512, consistent with reference wall_segment.png
```

侧墙（左右）：

```text
sci-fi interior side wall segment, top-down 3/4 view, visible narrow top cap and inner vertical face, dark gunmetal beveled panels, cyan light strip, amber warning light, same height as reference wall_segment.png, transparent background, bottom-center anchor, 512x512
```

内外转角：

```text
sci-fi wall corner module for a top-down 3/4 modular wall kit, inner corner and outer corner variants, same height and trim as reference wall_segment.png, beveled gunmetal panels, cyan strip light, amber lamp, transparent background, bottom-center anchor, 512x512
```

### 9.5 门与门框

```text
sci-fi airlock door frame module for a top-down 3/4 game, dark gunmetal beveled frame, twin sliding doors, cyan light strips, amber warning lamps, yellow-black hazard chevrons at the base, floor threshold rail, transparent background, bottom-center anchor, 512x512, matching reference door_airlock.png
```

开门状态：

```text
sci-fi airlock doorway in open state, door leaves retracted into the frame, dark gunmetal frame, cyan interior light, amber warning lamps, floor threshold, transparent background, bottom-center anchor, 512x512, same style as reference door_airlock.png
```

### 9.6 道具

控制台变体：

```text
sci-fi control console, top-down 3/4 view, dark beveled body, large cyan holographic screen with radar and bars, amber buttons, small cyan status lights, transparent background, bottom-center anchor, 512x512, matching reference console_terminal.png
```

货箱变体：

```text
sci-fi cargo crate, top-down 3/4 view, dark armored panels with teal stripes, amber latch, beveled corners, small warning label, transparent background, bottom-center anchor, 256x256, matching reference cargo_crate.png
```

管道束：

```text
sci-fi pipe bundle prop, top-down 3/4 view, three cylindrical dark metal pipes with brass bands, red valve wheel, small cyan gauge light, transparent background, bottom-center anchor, 256x256, matching reference pipe_bundle.png
```

反应堆：

```text
sci-fi reactor core, top-down 3/4 view, cylindrical dark metal housing, glowing cyan vertical core, amber warning strips, beveled armor ribs, transparent background, bottom-center anchor, 512x512, matching reference reactor_core.png
```

### 9.7 宇航员

8 向 turnaround：

```text
character turnaround sheet, cute semi-stylized astronaut, full body, 8 views in this order: front, front-right, right, back-right, back, back-left, left, front-left, identical character and scale, feet aligned to a common baseline, cream-white spacesuit with orange and cyan accents, dark teal visor, compact backpack, chunky boots, holds a compact energy rifle with cyan core in right hand, thick clean outline, flat cel shading, no cast shadow, transparent background, 2048x2048
```

行走（以向右为例）：

```text
8-frame walk cycle of the same cute sci-fi astronaut, facing right, full body, feet anchored on a common baseline, cream-white suit with orange and cyan accents, energy rifle in right hand, readable silhouette, thick clean outline, flat cel shading, no cast shadow, transparent background, sprite sheet, 8 columns, 384x384 per frame
```

射击（以向右为例）：

```text
4-frame shooting animation of the same cute sci-fi astronaut, facing right, energy rifle aimed right, muzzle position fixed across frames, recoil in the shoulders, cyan muzzle glow, thick clean outline, flat cel shading, no cast shadow, transparent background, sprite sheet, 4 columns, 384x384 per frame
```

> 角色必须先用 turnaround 定稿，再按方向生成动作；所有帧保留同一把枪、同一背包、同一配色。

### 9.8 特效

枪口火光图集：

```text
muzzle flash sprite sheet, 6 frames in a horizontal strip, stylized sci-fi energy shot, cyan core with white hot center, soft star-shaped flare, transparent background, additive-friendly, 192x192 per frame
```

能量弹：

```text
sci-fi energy bolt projectile sprite, horizontal, cyan glowing core with white center and soft outer glow, clean readable shape, transparent background, 64x64
```

命中火花：

```text
impact spark sprite sheet, 5 frames, small cyan and orange energy burst with sharp shards, transparent background, additive-friendly, 128x128 per frame
```

角色影子：

```text
soft oval character shadow decal, top-down view, feathered edges, 40 percent black, no hard outline, transparent background, 256x128
```

地面光池：

```text
soft radial floor light pool texture, cyan and warm amber variants, feathered edges, transparent background, additive-friendly, 512x512
```

## 10. 交付格式与命名

目录建议：

```text
art_placeholder/scifi_ship_v2/
  characters/
    astronaut/
      astronaut_turnaround.png
      astronaut_idle.png
      astronaut_walk.png
      astronaut_shoot.png
      astronaut_shadow.png
  environment/
    floors/
      floor_corridor_tile.png
      floor_engineering_tile.png
      floor_transition_corridor_to_engineering.png
    walls/
      wall_straight.png
      wall_side.png
      wall_corner_inner.png
      wall_corner_outer.png
      wall_end_cap.png
      wall_top_trim.png
      wall_base_trim.png
    doors/
      door_frame.png
      door_closed.png
      door_open.png
  props/
    console_terminal_01.png
    console_terminal_off.png
    cargo_crate_large.png
    cargo_crate_small.png
    cargo_crate_open.png
    pipe_bundle.png
    reactor_core.png
  vfx/
    muzzle_flash.png
    projectile_energy.png
    impact_spark.png
    hit_marker.png
    crosshair.png
    shadow_character.png
    light_pool_cyan.png
    light_pool_amber.png
  ui/
  _reference/
    scale_reference.png
    contact_sheet_v2.png
    scene_mockup_v2.png
```

- 全部 PNG，直通 alpha（straight alpha），不要预乘。
- 命名：小写 + 下划线 + 状态后缀（`_open`、`_off`、`_broken`）。
- 每个资产在 manifest 中标注：用途、世界尺寸、锚点、可平铺边、帧网格。
- 如有多方向角色图集，附一个 `astronaut_manifest.json` 或在图集中标注方向顺序。

## 11. 验收清单

- [ ] 视角统一为 3/4 俯视，墙、道具、角色在同一地平线
- [ ] 底边中心锚点正确，脚/底座贴合统一基线
- [ ] 透明背景干净，无白边、无黑边、无采样本底
- [ ] 地砖四方连续，接缝不可见
- [ ] 墙段横向平铺无缝，转角/端盖能闭合
- [ ] 角色 8 向可区分，缩小到 25% 仍能读懂朝向
- [ ] 角色帧间比例、枪械、背包、配色一致
- [ ] 枪口位置固定，枪口火光能对齐
- [ ] 无烘焙地面投影；影子为独立贴图
- [ ] 发光不过曝，缩到游戏尺寸仍清晰
- [ ] 文件命名、目录、manifest 与本文一致
- [ ] 附带比例参考图、新版 contact sheet、场景 mockup

## 12. 本轮优先沟通项

1. 侧墙/转角采用什么透视方案？是否沿用 `wall_segment` 的高度与压条？
2. 门框与墙段的拼接尺寸（建议门洞宽 256、门框外宽 384）。
3. 角色 turnaround 先定稿，确认后再进入 8 向动画；预计每向先交 idle + walk 关键帧。
4. 影子与发光层是否分层交付（推荐：PNG 分层 + 可选 PSD/ASE）。
5. 若管线使用 AI 生图，请固定角色参考图与种子，避免服装/武器漂移。

---

**备注**：现有占位角色、子弹、枪口火光均为程序化临时表现，美术资产到位后只替换视觉，不改移动、碰撞、射击与相机逻辑。
