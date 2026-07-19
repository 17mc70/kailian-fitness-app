# 本地小模型集成调研报告

## 目标
将 MiniCPM-V（或其他小型 LLM）集成到开练 Flutter App 中，作为 `LocalLLMAgent` 实现 `FitnessAgent` 接口，实现完全离线的 AI 教练。

## 候选模型

### 1. MiniCPM-2B (OpenBMB)
- 参数量：2B（适合端侧部署）
- 支持量化：4-bit GGUF ~1.2GB
- 推理框架：llama.cpp（C++，通过 FFI 集成）
- 特点：中文能力强，适合健身问答场景
- 多模态：MiniCPM-V 带视觉能力（可看动作图片），纯文本版更轻量

### 2. Qwen2.5-0.5B / 1.5B (Alibaba)
- 参数量：0.5B / 1.5B
- 量化后：~300MB / ~900MB
- 推理框架：llama.cpp / MLC-LLM
- 特点：中文能力优秀，0.5B 极轻量但能力有限

### 3. Llama 3.2-1B (Meta)
- 参数量：1B
- 量化后：~600MB
- 推理框架：llama.cpp
- 特点：英文能力强，中文需要额外微调

## 集成方案对比

| 方案 | 方式 | 包体积 | 首次下载 | 推理速度 | 开发难度 |
|------|------|--------|---------|---------|---------|
| **llama.cpp FFI** | C++ native lib via dart:ffi | +8MB (so) | 下载 GGUF 模型 | 快 (30-50 tok/s) | 🔴 高 |
| **MLC-LLM** | TVM 编译，Android AAR | +15MB | 下载模型 | 快 | 🔴 高 |
| **flutter_llama.cpp** | Flutter plugin (社区) | +8MB | 下载模型 | 快 | 🟡 中 |
| **MediaPipe LLM** | Google 官方方案 | +10MB | 下载 TFLite 模型 | 中 | 🟡 中 |

## 推荐路径

### 近期（可立即开始）
1. 创建 `LocalLLMAgent` 骨架类实现 `FitnessAgent` 接口
2. 模型下载管理器：首次启动时下载 GGUF 模型，支持断点续传
3. 系统要求检查：Android 8+，RAM 4GB+

### 中期（需原生开发）  
1. 使用 `flutter_llama.cpp` 或 `dart:ffi` 直接调用 llama.cpp
2. 封装异步推理接口，与 `FitnessAgent` 接口对接
3. 构建引擎切换逻辑（规则引擎 ↔ API ↔ 本地 LLM）

### 远期
1. 模型下载 + 管理 UI（下载进度、删除、切换模型）
2. 基于健身数据微调专用 0.5B 模型（LoRA）
3. 多模态支持（拍照识别动作）

## 架构建议

```
┌─────────────────────────────────────────────┐
│              FitnessAgent 接口               │
├─────────────┬──────────────┬────────────────┤
│ RuleEngine  │   ApiAgent   │  LocalLLMAgent │
│ (纯 Dart)   │  (HTTP API)  │ (llama.cpp)    │
├─────────────┴──────────────┴────────────────┤
│            FitnessAgentService              │
│           (自动选择可用后端)                  │
└─────────────────────────────────────────────┘
```

`LocalLLMAgent` 骨架代码：

```dart
class LocalLLMAgent implements FitnessAgent {
  // 检查设备是否满足运行要求
  bool get isAvailable => _modelLoaded && _hasEnoughMemory();
  
  // 模型加载状态
  bool _modelLoaded = false;
  double _downloadProgress = 0;
  
  Future<void> loadModel(String modelPath) async {
    // 1. 检查设备兼容性
    // 2. 通过 FFI 初始化 llama.cpp 上下文
    // 3. 加载 GGUF 模型文件
    // 4. 设置推理参数（temperature, max_tokens 等）
  }
  
  Future<String> _inference(String prompt) async {
    // 1. Tokenize prompt
    // 2. 运行推理循环
    // 3. Detokenize output
    // 4. 返回结果
  }
  
  // 实现 FitnessAgent 接口
  Future<AgentPlanResult> generatePlan(PlanRequest request) async { ... }
  Future<AgentAnalysis> analyzeProgress(List<WorkoutSession> sessions) async { ... }
  Future<AgentAnswer> answerQuery(String query, {List<Exercise>? contextExercises}) async { ... }
  Future<String> getExerciseTip(Exercise exercise) async { ... }
}
```

## 需要验证的关键问题

1. flutter_llama.cpp 插件在最新 Flutter 版本上的兼容性
2. GGUF 量化模型在 Android arm64 上的实际推理速度
3. 模型文件下载策略（App 资源包 vs 首次启动下载 vs 可选下载）
4. APK 大小限制：GGUF 模型约 1-2GB，不能内置，需运行时下载
