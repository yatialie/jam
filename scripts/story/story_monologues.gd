class_name StoryMonologues
extends RefCounted

## 第一关至第三关的全部内心独白。
## 台词按剧情事件集中管理，关卡脚本只负责在正确时机调用 Monologue.play()。
## emotion 对应 monologue_overlay.gd 的 EMOTION_PORTRAITS：
## question / exclaim / anger / remorse / question_respawn。
## 空字符串表示使用默认（平静）立绘。

# ── 第一关：驾驶舱 ─────────────────────────────────────────────

## 开局控制室屏幕旁白：系统即将切到单人控制模式，文字带信号干扰。
const L1_OPENING := [
	{"text": "没时……了……启用单人……控……", "emotion": "question"},
]

## 左舷门：从内侧被堵死，只能绕路。
const L1_LEFT_DOOR := [
	{"text": "这扇门……打不开。", "emotion": "question"},
	{"text": "似乎从对面被堵上了，可以从其他地方绕过去。", "emotion": "question"},
]

## 拾取脏脏小咪。
const L1_MIMI := [
	{"text": "这个让我感觉好温暖。", "emotion": ""},
]

## 被机械臂杀死后回到驾驶舱。
const L1_RESPAWN := [
	{"text": "......又回来了", "emotion": "remorse"},
	{"text": "总觉得有一个很重要的日期……是什么。", "emotion": "question_respawn"},
]

## 重生后第一次查看日历。
const L1_CALENDAR_DATE := [
	{"text": "925……明天是什么重要的日子。", "emotion": "question"},
]

# ── 第二关：储物补给舱 ─────────────────────────────────────────

## 第一次进入补给舱：还没有敌人，注意到的只是远处行为异常的机械臂。
const L2_FIRST_ENTRY := [
	{"text": "前面的机械臂有点奇怪，过去看看。", "emotion": "question"},
]

## 被机械臂击杀后第二次进入补给舱。
const L2_RESPAWN_ENTRY := [
	{"text": "又来了！外星怪物！", "emotion": "anger"},
	{"text": "糟了……机械臂怎么狂暴了，和刚刚不一样……？", "emotion": "question"},
	{"text": "也许，有办法让它停下来。", "emotion": "question"},
	{"text": "我记得操作……可以攻击！", "emotion": "exclaim"},
]

## 输入 925 让机械臂停机。
const L2_ARM_MEMORY := [
	{"text": "这个日期看来真有什么深意。", "emotion": "question"},
]

# ── 第三关：卫生废物处理仓 ─────────────────────────────────────

## 进入处理仓：先看到怪物，几秒后注意到墙上的红色攻击按钮。
const L3_ENTRY := [
	{"text": "好多外星怪物啊！", "emotion": "exclaim"},
	{"text": "攻击按钮！启动机器！来啊，伙计！", "emotion": "anger"},
]

## 按下红按钮、抽取机启动。
const L3_EXTRACTOR := [
	{"text": "感觉就像我的肌肉记忆。", "emotion": ""},
]
