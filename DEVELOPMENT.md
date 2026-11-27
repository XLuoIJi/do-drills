# 刷题 App 开发与打包说明

## 1. 项目结构

```text
lib/
  main.dart                 应用入口与全局 Provider
  models/                   章节、题目、错题、练习进度、持久化数据结构
  services/                 题库解析、TXT 读取、本地 JSON 存储
  state/app_state.dart      单一全局状态管理（含练习进度的保存/清理）
  pages/                    主页、答题页、错题库页
  widgets/                  练习设置弹窗（顺序/随机/考试/背题）、题型标签
  theme.dart                颜色、圆角、组件主题
test/                       解析器、状态、答题交互、新功能行为测试
android/                    Android 工程
pubspec.yaml                依赖与版本号
sample_chapter1.txt         示例题库
```

## 2. 本地环境

推荐直接安装 Android Studio，然后用它安装 Flutter 和 Android SDK。

- Flutter 3.35.x（Dart 3.9）
- JDK 17（Android Studio 自带的 JBR 即可）
- Android SDK Platform 36
- Android SDK Build-Tools 35.0.0 或更高

检查环境：

```bash
flutter doctor -v
flutter doctor --android-licenses
```

手机开启开发者模式与 USB 调试，连接电脑后确认：

```bash
flutter devices
```

## 3. 运行项目

在项目根目录执行：

```bash
flutter pub get
flutter run
```

## 4. 打包 APK

```bash
flutter build apk --release
```

产物：

```text
build/app/outputs/flutter-apk/app-release.apk
```

当前项目默认仍使用 debug 签名，方便本地覆盖安装：

```kotlin
// android/app/build.gradle.kts
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

需要减小体积、只打 arm64：

```bash
flutter build apk --release --target-platform android-arm64
```

也可以按 ABI 拆分：

```bash
flutter build apk --release --split-per-abi
```

## 5. 常见修改位置

### 修改应用名

`android/app/src/main/AndroidManifest.xml`：

```xml
android:label="刷题"
```

### 修改包名

需要同时修改：

- `android/app/build.gradle.kts` 中的 `namespace` 与 `applicationId`
- `android/app/src/main/AndroidManifest.xml`（如果有显式包名）
- Kotlin 源码目录 `android/app/src/main/kotlin/<包路径>/MainActivity.kt` 以及它的 `package` 声明

不建议在已有用户数据的版本上随意改包名，否则会变成另一个应用，旧数据读不到。

### 修改版本号

`pubspec.yaml`：

```yaml
version: 1.1.1+7
#        ^name ^code（Android 用 versionCode 判断升级）
```

每次发布新 APK 时递增最后的数字（例如 `+8`）。

### 修改水印

`lib/pages/home_page.dart` 搜索：

```text
测试版0.2
```

### 修改题库解析规则

`lib/services/question_parser.dart`。解析器已有独立测试：

```text
test/question_parser_test.dart
```

### 修改本地存储

`lib/services/storage_service.dart`，数据文件位于：

```text
<应用私有目录>/data/questions.json
```

### 修改练习和答题逻辑

- 主页和导入：`lib/pages/home_page.dart`
- 答题页与判题：`lib/pages/quiz_page.dart`（含自由滑动、题号预览面板、背题渲染、
  考试计时/中断判定/成绩结算、练习进度自动保存与恢复）
- 错题库：`lib/pages/wrong_book_page.dart`
- 练习设置（顺序/随机/真实考试/背题模式/考试题数与时间）：`lib/widgets/practice_setting_sheet.dart`
- 全局状态：`lib/state/app_state.dart`
- 练习进度数据结构：`lib/models/practice_progress.dart`（随 questions.json 持久化，
  每章仅保留最近一次进度；章节覆盖/删除时自动清理）

## 6. 自己生成正式签名

先生成密钥文件：

```bash
keytool -genkey -v \
  -keystore quiz-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias quiz
```

在项目根目录创建 `android/key.properties`（不要提交到公开仓库）：

```properties
storePassword=你的仓库密码
keyPassword=你的密钥密码
keyAlias=quiz
storeFile=/绝对路径/quiz-release.jks
```

修改 `android/app/build.gradle.kts`，在文件顶部增加：

```kotlin
import java.util.Properties
import java.io.FileInputStream
```

在 `android {}` 块之前增加：

```kotlin
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

在 `android {}` 内增加：

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

以后发版务必使用同一个签名文件；换成另一个签名后，旧版本无法直接覆盖安装。

## 7. 修改后的验证

```bash
flutter analyze
flutter test
flutter build apk --release
```

如果需要重新验证 APK 的包名、权限和签名：

```bash
aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

## 8. 注意事项

- 当前工程 release 默认使用 debug 签名，只适合你自己安装测试。
- 不要提交 `build/`、`.dart_tool/`、`android/.gradle/`、`android/local.properties`、`android/key.properties`、`*.jks`、`*.keystore`。
- 数据保存在应用私有目录，卸载应用会删除题库和错题记录。
- App 完全离线，不需要网络权限。
- 如只需要 `arm64-v8a`，构建时加上 `--target-platform android-arm64`；需要兼容更多设备时使用 `--split-per-abi` 或构建 universal APK。
