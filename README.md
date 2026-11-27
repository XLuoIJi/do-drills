# 刷题

一款完全离线的 Android TXT 题库刷题应用。导入本地题库后，可以按章节、题型进行顺序练习、随机练习、背题或真实考试，答错的题目会自动进入错题库。

当前版本：`1.1.1+7`

## 功能

- TXT 题库多选导入，一个文件对应一个章节
- 章节列表按导入时间倒序展示，显示单选 / 多选 / 判断数量
- 题型筛选：全部 / 单选 / 多选 / 判断
- 练习方式：顺序练习 / 随机练习 / 真实考试
- 背题模式：直接显示答案，可自由滑动
- 练习进度自动保存，再次进入章节可继续上次位置
- 单选 / 判断点击即判，多选提交后判定
- 答对后约 800ms 自动进入下一题；答错停留并允许切换
- 题号预览面板，点击题号直接跳题
- 真实考试支持自定义题数和时间，满分 100 分
- 考试倒计时、低正确率提醒、成绩结算
- 错题库按最近答错时间排序，支持单条删除和全部清空
- 同名章节覆盖、长按删除章节、本地持久化

## 技术栈

- Flutter 3.35.x / Dart 3.9.x
- Provider
- Material 3
- 本地 JSON 存储
- Android 7.0（API 24）及以上

## 项目结构

```text
lib/
  main.dart                 应用入口与 Provider
  models/                   章节、题目、错题、练习进度等数据模型
  services/                 题库解析、TXT 读取、本地 JSON 存储
  state/app_state.dart      全局状态管理
  pages/                    主页、答题页、错题库页
  widgets/                  练习设置弹窗、题型标签
  theme.dart                颜色、圆角和组件主题
test/                       解析器、状态和答题交互测试
android/                    Android 工程
sample_chapter1.txt         示例题库
```

## 本地运行

环境要求：

- Flutter 3.35.x（Dart 3.9.x）
- JDK 17
- Android SDK Platform 36
- Android SDK Build-Tools 35.0.0 或更高

```bash
flutter doctor -v
flutter pub get
flutter run
```

手机需要开启开发者模式与 USB 调试。

Linux/macOS 如果提示 `Permission denied`，执行一次：

```bash
chmod +x android/gradlew
```

## 打包 APK

```bash
flutter build apk --release
```

输出：

```text
build/app/outputs/flutter-apk/app-release.apk
```

只构建常用的 arm64 版本：

```bash
flutter build apk --release --target-platform android-arm64
```

当前 `android/app/build.gradle.kts` 默认使用 debug 签名，便于本地直接安装测试。正式发布前请配置自己的 release keystore，详见 [DEVELOPMENT.md](DEVELOPMENT.md)。

> 仓库不提交 APK。构建产物请通过 GitHub Releases 或自己的分发渠道发布。

## 签名与密钥安全

请勿把以下文件提交到仓库：

- `android/key.properties`
- `*.jks` / `*.keystore` / `*.p12` / `*.pfx`
- `android/local.properties`
- 任何密码、token、API Key

根目录 `.gitignore` 已默认排除这些文件。正式签名文件请只保存在本地或安全的密钥管理系统中。

## 数据存储

应用数据保存在应用私有目录：

```text
data/questions.json
```

包括章节、错题和练习进度。App 不申请网络权限，不进行云同步；卸载应用会删除本地数据。

## 题库格式

- 扩展名 `.txt`
- 编码 UTF-8；UTF-8 解码失败时自动尝试 GBK
- 一个文件对应一个章节
- 题目：数字 + `.` 或 `、` + 题干
- 选项：`A-F` + `.` 或 `、` + 内容
- 答案：`答案：B`、`答案：ACD`、`答案：对`
- 题型标记支持 `【单选题】`、`【多选题】`、`【判断题】`，也兼容 `[]` 和「单选 / 多选 / 判断」

示例：

```text
【单选题】
1. 中华人民共和国的首都是？
A. 上海
B. 北京
C. 广州
D. 深圳
答案：B

【多选题】
2. 下列哪些属于可再生能源？
A. 太阳能
B. 煤炭
C. 风能
D. 水能
答案：ACD

【判断题】
3. 水的化学式是 H2O。
答案：对
```

完整示例见 [sample_chapter1.txt](sample_chapter1.txt)。

## 测试

```bash
flutter analyze
flutter test
```

解析器、状态管理和答题交互的测试位于 `test/` 目录。部分新增交互测试仍在完善中。

## 上传到 GitHub

在本目录执行：

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin <你的仓库地址>
git push -u origin main
```

也可以直接在 GitHub 网页新建仓库，然后把本目录中的文件上传。

## 已知限制

- 仅支持 TXT 题库，一个文件只能对应一个章节
- 错题库只支持查看和删除，不提供错题重练
- 真实考试中途退出不保存本次成绩
- 不包含登录、云同步、收藏、设置、深色模式等额外功能
- 当前仅包含 Android 工程

## License

本项目暂未添加开源许可证。如需公开分发或允许他人复用，请自行补充合适的 LICENSE。
