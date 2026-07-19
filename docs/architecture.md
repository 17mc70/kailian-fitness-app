# 开练 — 架构说明

## 整体架构

```
┌─────────────────────────────────────────────────────┐
│  UI 层 (lib/screens/)                              │
│  Home → ExerciseList → ExerciseDetail              │
│  Plans → PlanDetail → Workout → Finish Summary     │
│  Plans → AIPlanConfig → CreatePlan                 │
│  QuickWorkout (自由训练, 无需计划)                   │
│  Progress → SessionDetail                          │
│  AgentChat (AI 教练对话)                            │
├─────────────────────────────────────────────────────┤
│  AI Agent层 (lib/agent/)                           │
│  FitnessAgent 接口 ← RuleEngine / APIAgent          │
│  AgentService (初始化/后端切换)                     │
├─────────────────────────────────────────────────────┤
│  数据模型 (lib/models/)                             │
│  Exercise / WorkoutPlan / WorkoutSession            │
├─────────────────────────────────────────────────────┤
│  服务层 (lib/services/)                             │
│  ExerciseService (JSON 内存缓存)                    │
│  DatabaseService (SQLite CRUD)                     │
├─────────────────────────────────────────────────────┤
│  设计系统 (lib/design/)                             │
│  主题 (亮/暗) + Token (颜色/排版/间距) + 组件库      │
├─────────────────────────────────────────────────────┤
│  存储层                                             │
│  assets/data/exercises.json  ← 只读                 │
│  kailian.db (SQLite)          ← 用户数据             │
└─────────────────────────────────────────────────────┘
```

## 数据流

### 练习浏览流程
```
assets/data/exercises.json
    → rootBundle.loadString()
    → json.decode() → List<dynamic>
    → Exercise.fromJson()  (补 assets/ 前缀)
    → ExerciseService._exercises (内存缓存)
    → ExerciseService.search() / filter()
    → ExerciseListScreen state → GridView
```

### 训练记录流程
```
WorkoutPlan (SQLite) 或 QuickWorkoutScreen (选动作)
    → WorkoutScreen (计时 + ExerciseLogEntry)
    → 每动作: ExerciseSet[组号, 重量, 次数, 完成状态]
    → 完成: DatabaseService.saveSession() + saveExerciseLog()
    → ProgressScreen: DatabaseService.getVolumeByDay() 读历史
    → ProgressScreen tap → SessionDetailScreen (每组详情)
```

### AI 教练对话流程
```
用户输入 → AgentChatScreen
    → FitnessAgentService (自动选择后端)
    → RuleEngineAgent (离线): ExerciseRetriever 检索 + 规则树 → 回复
    → APIAgent (在线): ExerciseRetriever 检索候选动作
        → 工具调用循环 (_agenticChat, 上限 5 轮):
          search_exercises / get_exercise_detail / get_workout_history
        → LLM 基于工具结果生成回复
    → 回复 + relatedExerciseIds 显示在聊天界面（动作缩略卡，可点击进详情）
```

### AI 生成计划流程
```
AIPlanConfigScreen (填写目标/频率/偏好)
    → FitnessAgentService.generatePlan()
    → RuleEngineAgent: 基于模板规则生成
    → APIAgent: 调用远程 LLM 生成
    → 返回 PlanRequest → CreatePlanScreen 预填
    → 用户确认 → DatabaseService.savePlan()
```

## 关键设计决策

### 1. 图片路径自动补全
JSON 中路径为 `images/xxx.jpg`，Flutter 需要 `assets/images/xxx.jpg`。
`Exercise._assetPath()` 在 `fromJson` 时自动补全，调用方无需关心。

### 2. 数据全离线
1324 个练习 + 图片 + GIF 全部打包在 assets 中（~148MB）。
App 无需网络连接即可使用全部功能。

### 3. 中文优先
UI 全部中文显示，练习说明优先取 `zh`，fallback 到 `en`。

### 4. 器材筛选可折叠
默认只显示部位分类 chip，器材筛选通过 AppBar 右上角图标展开，
避免初次加载时筛选栏过长。

### 5. AI 双后端架构
Agent 层通过 `FitnessAgent` 接口抽象，支持离线规则引擎（`RuleEngineAgent`）和在线 API（`APIAgent`）双模式。
- `RuleEngineAgent`：纯 Dart 实现，基于关键词匹配 + 规则树，零依赖，设备端即时响应
- `APIAgent`：通过 HTTP 调用远程 LLM，需网络连接，支持 function-calling 工具循环
- `FitnessAgentService`：应用启动时初始化，根据配置自动选择可用后端

### 6. 中文检索避免 LLM 瞎编 exerciseId
`ExerciseRetriever`（`lib/services/exercise_retriever.dart`）对 1324 个练习做打分式中文关键词检索，
复用 `ExerciseLabels` 的反向映射（`categoryMap`/`equipmentMap`/`targetMap`/`muscleGroupMap`）做双向包含匹配。
`RuleEngineAgent` 和 `APIAgent` 的 `answerQuery` 都先检索候选动作再回答/调用工具，
避免早期版本把前 50 个练习硬塞给 LLM、导致其编造不存在的 exerciseId 的问题。

### 7. Agent 工具调用（function calling）
`APIAgent` 定义 3 个工具供 LLM 调用：`search_exercises`（关键词检索）、
`get_exercise_detail`（按 ID 取详细步骤）、`get_workout_history`（读训练历史）。
`_agenticChat` 跑工具调用循环（上限 5 轮），支持多轮对话（`FitnessAgent.answerQuery` 的可选 `history` 参数，类型 `ChatTurn`）。
回复中命中的 exerciseId 会在聊天界面渲染为可点击的动作缩略卡（`_ExerciseCardStrip`）。

## 数据库 E-R

```
workout_plans ──1:N──▶ workout_sessions ──1:N──▶ exercise_logs
       │                                              │
       │                                              │ sets_data: JSON array
       │ exercise_ids: "id1,id2,id3..."               │ [{set_number,reps,weight,is_completed}]
```

## 导航结构

```
MainScreen (KLBottomNavigation, 4标签)
├── [0] HomeScreen
│       ├── 快速开练 → QuickWorkoutScreen
│       ├── 今日推荐 → ExerciseDetailScreen
│       ├── 部位分类 → ExerciseListScreen
│       └── 器材分组 → ExerciseListScreen
├── [1] PlansScreen
│       ├── 模板推荐 → PlanDetailScreen
│       ├── AI 生成 → AIPlanConfigScreen
│       ├── FAB → CreatePlanScreen
│       └── tap plan → PlanDetailScreen → WorkoutScreen → Finish
├── [2] ProgressScreen
│       └── tap session → SessionDetailScreen
└── [3] AgentChatScreen (AI 教练对话)
```
