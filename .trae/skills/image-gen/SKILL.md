---
name: "image-gen"
description: "Generates project images through api.openai-next.com using ONLY gpt-image-2.5, with locked project style presets and multi-candidate output. Invoke whenever a session needs game art, UI art, icons, characters, VFX, or concept illustrations."
---

# 项目生图通道（image-gen）

项目唯一的生图入口。固定调用 `gpt-image-2.5`，自带项目风格预设，默认一次出 4 张候选。

## 铁律

1. **只准用 gpt-image-2.5**。脚本已锁死模型；不要把 `config.json` 里的 `model` 改成别的，也不要用内置 GenerateImage、其他渠道或第三方模型替代。
2. **每次生图都必须走本 skill 的脚本和风格预设**，不允许裸提示词直连 API。
3. **次数不限，鼓励多出候选**。重要资产建议 4~8 张对比，必要时换提示词再迭代几轮。
4. **新美术资产进入游戏前必须先给用户看候选并由用户确认**（项目硬约束），选中后再移动到正式美术目录并接入。
5. 提示词用英文写，具体、可视觉化。文字不要交给模型生成（UI 文案由 Godot 绘制）。

## 快速调用

```bash
python .trae/skills/image-gen/gen_image.py --preset prop --name cargo_crate \
  --prompt "heavy reinforced cargo crate, rusted corner bolts, cyan status strip, two latch handles" \
  --candidates 4
```

带参考图（推荐用于角色/风格一致性）：

```bash
python .trae/skills/image-gen/gen_image.py --preset character --name rig7_idle \
  --prompt "RIG-7 android standing idle, full body" \
  --reference art_placeholder/scifi_ship/_contact_sheet.png --candidates 4
```

## 参数

| 参数 | 说明 |
|---|---|
| `--prompt` / `-p` | 英文画面描述，必填 |
| `--name` / `-n` | 输出文件名前缀，snake_case |
| `--preset` | 风格预设：`env` `prop` `character` `character-sheet` `ui` `fx` `icon` `illustration`，默认 `env` |
| `--candidates` / `-c` | 候选数量，默认 4 |
| `--size` | `1024x1024`（默认）/ `1536x1024` 横版场景 / `1024x1536` 竖版 UI、人物；自定义尺寸报错就回退 1024x1024 |
| `--out` | 输出目录，默认 `art_placeholder/_generated/<preset>/<日期>/` |
| `--reference` | 参考图路径，可重复（≤4 张），走 `/v1/images/edits` |
| `--transparent` | 请求透明背景 PNG（道具/角色优先开） |
| `--json` | 只输出 JSON 元数据，便于程序处理 |

## 输出约定

- 文件名：`<name>_v1.png` ... `<name>_vN.png`，同目录附 `<name>_meta.json`（含最终提示词、尺寸、批次数）。
- `art_placeholder/_generated/` 自带 `.gdignore`，候选图不会被 Godot 导入；选定后再复制/移动到正式目录。
- 生成结束后用 Read 工具逐张查看，按以下维度对比：色板是否落在项目区间、轮廓可读性、透视角度、是否有文字/水印/多余肢体。把差异总结给用户挑。

## 风格系统

脚本自动拼接 `config.json` 中的 `common_prefix` + 预设 `prefix` + 你的描述 + `common_negative`。

统一基准（与 `ART_BRIEF_scifi_shooter.md` 一致）：

- 枪金属 `#242A33`、钢板 `#39424F`、边缘高光 `#5C6B7E`
- 青色发光 `#39D6E8`、琥珀警示 `#F2A63B`、锈红管道 `#7C3B33`
- 半写实硬表面、倒角面板、厚描边、左上主光、不烘焙地面投影、克制磨损
- 禁止：照片纹理、过量霓虹、二次元、文字水印、糊成一团的纯黑轮廓

预设选择：场景结构件用 `env`；可拾取/可碰撞道具用 `prop`；角色单帧用 `character`；多视图定稿用 `character-sheet`；面板/按钮/边框用 `ui`；特效帧用 `fx`；小图标用 `icon`；菜单主视觉/剧情插图用 `illustration`。

## 配置与密钥

- 非敏感配置：`config.json`（base_url、模型、尺寸、风格预设）。
- 密钥：`config.local.json` 的 `api_key`，已被 `.gitignore` 忽略；也可用环境变量 `IMAGE_API_KEY` 覆盖。
- 鉴权失败（401/403）先检查 `config.local.json` 密钥是否完整。

## 失败排查

- 超时或 429/5xx：脚本自动重试 3 次。
- 400 尺寸不支持：改用 `1024x1024`、`1536x1024` 或 `1024x1536`。
- 返回无图：检查响应体提示，确认模型名仍是 `gpt-image-2.5`。
