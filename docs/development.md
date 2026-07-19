# 开练 — 开发指南

## 环境要求

- Flutter 3.44.4+ (Dart 3.12.2+)
- Android SDK (已配置国内镜像)
- Android 设备或模拟器

## 开发流程

### 1. 首次运行

```bash
flutter pub get
flutter run
```

首次运行会下载 Gradle + NDK + Android SDK 组件，耗时较长。
后续运行直接 `flutter run` 即可。

### 2. 无线调试

详细步骤见 [WIRELESS_DEV.md](../WIRELESS_DEV.md)。

要点：
- 手机和电脑连同一 WiFi
- 首次需 USB 数据线配一次
- 运行 `.\wireless.bat` 切换无线模式
- 之后 `flutter run` 即可

### 3. 热重载

| 按键 | 用途 |
|------|------|
| `r` | 热重载（改 UI、样式等，1 秒生效） |
| `R` | 完全重启（改数据模型、全局状态） |

### 4. 代码检查

```bash
flutter analyze
```
目标：零 error、零 warning。

## 国内镜像说明

首次构建时已配置：
- **Gradle**：腾讯云镜像 (`mirrors.cloud.tencent.com`)
- **Maven**：阿里云镜像 (`maven.aliyun.com`)

如需恢复官方源：
- 改 `android/gradle/wrapper/gradle-wrapper.properties` 中 `distributionUrl`
- 改 `android/settings.gradle.kts` 和 `android/build.gradle.kts` 中 repositories

## 添加新页面

1. 在 `lib/screens/` 下创建页面文件
2. 在 `lib/main.dart` 的 `MainScreen` 中注册底部导航（如需）
3. 使用 `Navigator.push(MaterialPageRoute(...))` 跳转

## 本地化

练习说明支持 6 语言：zh/en/es/it/tr/ru
App UI 目前仅中文，如需切换：
- `ExerciseDetailScreen` 中 `_lang` 变量改为 `'en'`
- 或通过 `Exercise.getSteps('en')` / `Exercise.getInstruction('en')` 获取
