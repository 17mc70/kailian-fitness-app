# 开练 🏋️

**你的私人锻炼助手** — 基于 1324 个练习数据集的离线 Android 健身 App。

数据来自 [exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset)，包含 1324 个练习的动画 GIF、180×180 缩略图、6 语言步骤说明。

## 功能

| 页面 | 功能 |
|------|------|
| 🏋️ **练习** | 按部位/器材分类浏览，1324 个动作 GIF 动画 + 中文步骤说明 |
| 📋 **计划** | 自定义训练计划，从练习库选取动作保存到本地 |
| ▶️ **训练** | 按计划训练，实时计时，逐组记录重量/次数，自动保存 |
| 🤖 **AI 教练** | AI 健身问答 + 智能生成训练计划，离线规则引擎 + 在线 API |

## 技术栈

- **Flutter** 3.44.4 (Dart 3.12.2)
- **sqflite** — 本地 SQLite 存储训练计划和记录
- **Material Design 3** — 主题和 UI 组件
- **自定义设计系统** — 颜色/排版/间距/阴影 token 体系
- **AI 后端** — 离线规则引擎 + 可选在线 API 双模式

所有数据离线存储，无需网络连接。

## 快速开始

```bash
# 依赖安装（首次）
flutter pub get

# 开发运行（需连接 Android 设备）
flutter run

# 构建 APK
flutter build apk --debug
```

> 无线调试指南见 [WIRELESS_DEV.md](WIRELESS_DEV.md)。

## 项目结构

```
lib/
├── main.dart                     # 入口：初始化 AI Agent，4 标签导航
├── agent/                        # AI 教练系统
│   ├── fitness_agent.dart        # FitnessAgent 接口
│   ├── rule_engine_agent.dart    # 离线规则引擎
│   ├── api_agent.dart            # 在线 AI 后端
│   └── agent_service.dart        # Agent 管理服务
├── models/                       # 数据模型
│   ├── exercise.dart             # 练习模型（JSON → 对象）
│   ├── workout_plan.dart         # 训练计划模型
│   └── workout_session.dart      # 训练记录 + 组/重量/次数
├── services/                     # 服务层
│   ├── exercise_service.dart     # JSON 加载 + 搜索/筛选
│   └── database_service.dart     # SQLite CRUD
├── navigation/                   # 导航
│   ├── app_router.dart           # 集中路由工厂
│   └── kl_bottom_navigation.dart # 自定义底部导航
├── design/                       # 设计系统
│   ├── theme/                    # 主题（亮/暗）
│   ├── tokens/                   # 设计 token（颜色/排版/间距/圆角/阴影/动画）
│   └── components/               # 可复用组件（按钮/卡片/搜索框/骨架屏等）
├── screens/                      # 页面
│   ├── home_screen.dart          # 首页：快速开练 + 推荐 + 分类
│   ├── exercise_list_screen.dart # 练习浏览（搜索 + 分类筛选）
│   ├── exercise_detail_screen.dart # 练习详情（GIF + 步骤）
│   ├── plans_screen.dart         # 计划列表 + 模板 + AI 生成
│   ├── plan_detail_screen.dart   # 计划详情 + 开始训练
│   ├── create_plan_screen.dart   # 创建/编辑计划
│   ├── workout_screen.dart       # 训练中（计时 + 组记录 + 跳转）
│   ├── quick_workout_screen.dart # 自由训练（选动作直接练）
│   ├── progress_screen.dart      # 进度追踪（统计 + 图表）
│   ├── session_detail_screen.dart # 历史训练详情
│   ├── agent_chat_screen.dart    # AI 教练对话
│   └── ai_plan_config_screen.dart # AI 生成计划配置
├── utils/                        # 工具
│   ├── exercise_labels.dart      # 标签中文映射
│   └── equipment_groups.dart     # 器材分组
├── data/                         # 模板数据
│   └── workout_templates.dart    # 内置训练计划模板
└── widgets/                      # 可复用小组件
    ├── exercise_card.dart        # 练习卡片
    └── skeleton_card.dart        # 骨架屏
assets/
├── data/exercises.json           # 1324 个练习数据（9.4MB）
├── images/                       # 1324 张缩略图
└── videos/                       # 1324 个动画 GIF
```

## 数据来源

- 数据集：[exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset) (MIT License)
- 媒体版权：© [Gym visual](https://gymvisual.com/)
- 1324 个练习，10 个分类（背部/胸部/肩部/上臂/前臂/大腿/小腿/腰部/有氧/颈部）
- 28 种器材类型
- 6 语言支持（中文/英文/西班牙语/意大利语/土耳其语/俄语）

## License

MIT — see [LICENSE](LICENSE).
