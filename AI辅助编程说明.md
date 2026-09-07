# AI 辅助编程过程说明：智能语音计算器

## 1. 原始提示词

> 按照我的要求帮我做计算机，可以先从 GitHub 上找可用资料。

附图要求被整理为：使用 ArkUI 搭建智能语音计算器首页，包含标题区、表达式区、结果区、按键区和语音入口；按钮可点击、状态可变化、代码命名清晰。本阶段语音按钮只预留 Speech Kit 接入口。

## 2. 优化后的提示词

> 请在现有 HarmonyOS ArkUI 工程中实现一个可运行的智能语音计算器首页。使用 `Column`、`Row`、`Text`、`Button` 和 `ForEach` 构建标题区、显示区、5×4 按键网格及语音提示区；使用 `@State` 驱动表达式、结果、提示信息和语音状态。实现数字与小数输入、加减乘除、运算符优先级、清空、退格、等号和确认功能。语音按钮只显示“Speech Kit 待接入”，不得伪装成已完成语音识别。不要使用 `eval()`；完成 ArkTS 编译和 HAP 打包，并记录真实报错、修复过程及人工审核结论。

## 3. GitHub 资料检索与取舍

- 参考 [OpenHarmony codelabs](https://github.com/openharmony/codelabs) 中的 ArkTS 简易计算器目录，确认计算器属于官方基础 UI 示例场景。
- 参考 [OpenHarmony ArkUI 文档](https://github.com/openharmony/docs) 中 `Column`、`Row`、`ForEach` 等声明式组件的组合方式。
- 没有直接复制第三方完整项目。当前工程 API 版本为 26，因此保留现有工程结构并针对本机 SDK 编写、编译和修正代码。
- 对网络示例进行人工筛选：仅借鉴页面分区和数组生成按钮的思路；计算部分自行使用双栈解析，拒绝采用 `eval()` 执行表达式。

## 4. AI 生成代码与结构说明

完整代码位于 `entry/src/main/ets/pages/Index.ets`，主要结构如下：

```typescript
@State inputText: string = '';
@State resultText: string = '0';
@State tipText: string = '点击数字或语音输入';
@State isListening: boolean = false;

private readonly keys: string[][] = [
  ['C', '⌫', '÷', '×'],
  ['7', '8', '9', '−'],
  ['4', '5', '6', '+'],
  ['1', '2', '3', '='],
  ['语音', '0', '.', '确认']
];
```

页面由四个构建器组成：

```typescript
build() {
  Column({ space: 14 }) {
    this.TitleArea();
    this.DisplayArea();
    this.KeyBoardArea();
    this.VoiceArea();
  }
}
```

按钮通过数组统一生成，并由 `handleKey()` 分发：

```typescript
private handleKey(key: string): void {
  if (key === 'C') {
    this.clearAll();
  } else if (key === '⌫') {
    this.deleteLast();
  } else if (key === '=' || key === '确认') {
    this.calculate();
  } else if (key === '语音') {
    this.startVoiceInput();
  } else {
    this.appendInput(key);
  }
}
```

计算逻辑采用“数字栈 + 运算符栈”，支持先乘除后加减。代码没有使用 `eval()`，避免将输入内容作为程序执行。

## 5. 调试与报错修复过程

### 报错一：SDK 环境变量无效

- 现象：`Invalid value of 'DEVECO_SDK_HOME' in the system environment path.`
- 判断：构建尚未进入 ArkTS 编译阶段，属于命令行环境问题，不是页面代码错误。
- 处理：只在当前 PowerShell 构建进程中把 `DEVECO_SDK_HOME` 指向 DevEco Studio 的 `sdk` 目录。

### 报错二：找不到 Java

- 现象：ArkTS 编译通过，但 HAP 打包时报 `spawn java ENOENT`。
- 判断：`PackageHap` 找不到 Java，代码本身已经通过 `CompileArkTS`。
- 处理：只在当前构建进程中设置 DevEco Studio 自带的 `JAVA_HOME`，并将 `jbr\bin` 加入 `Path`。

### 报错三：Row 不支持 minHeight

- 现象：`Property 'minHeight' does not exist on type 'RowAttribute'. Did you mean 'height'?`，定位到 `Index.ets` 的语音提示区。
- 判断：当前 SDK 的 `RowAttribute` 类型没有 `minHeight` 属性。
- 修复：将 `.minHeight(44)` 改为 `.height(44)`。
- 复测：再次运行完整构建，`CompileArkTS`、`PackageHap` 和 `assembleHap` 均通过，最终显示 `BUILD SUCCESSFUL in 9 s 314 ms`。

## 6. 人工审核意见

- 界面完整性：具备标题、表达式、结果、按键网格和语音提示五个区域，符合附图的核心结构。
- 交互完整性：支持数字、小数、四则运算、连续表达式、清空、退格、等号和确认；可拦截重复小数点、空表达式、末尾运算符及除零情况。
- 安全性：没有为了省事使用 `eval()`；表达式长度限制为 24 个字符。
- AI 纠偏：AI 初稿使用了当前 SDK 不支持的 `minHeight`，经真实编译定位后改用 `height`，说明生成代码必须经过工具链验证。
- 能力边界：语音按钮目前只改变 `isListening` 和提示文字，并明确显示 `Speech Kit 待接入`；没有宣称已获得麦克风权限或完成语音识别、语音播报。
- 尚待人工验收：需要在 Previewer、模拟器或真机上检查不同屏幕下的视觉效果，并逐项点击验证；构建成功不能代替运行验收。

## 7. 建议的人工测试步骤

1. 输入 `12+8`，点击 `=`，预期结果为 `20`。
2. 输入 `8×7`，点击“确认”，预期结果为 `56`。
3. 输入 `2+3×4`，预期结果为 `14`，确认运算优先级正确。
4. 点击 `⌫`，确认删除最后一个字符；点击 `C`，确认表达式和结果清空。
5. 输入 `1÷0`，预期显示错误提示，应用不能崩溃。
6. 点击语音按钮，预期提示“正在准备语音识别…（Speech Kit 待接入）”，不得出现虚假的识别结果。

## 8. 追加：点击按键的语音播报接入

### 8.1 原始需求

> 现在点击按键时希望有语音响应播报。

### 8.2 实现内容

- 新增 `entry/src/main/ets/common/TtsSpeaker.ets`，封装 CoreSpeechKit 的 `textToSpeech`：
  - `createEngine` 使用中文离线合成（`language: 'zh-CN'`、`person: 0`、`online: 1`），不需要麦克风权限和联网；
  - 播报文本进入队列串行朗读，避免快速连点时多条语音重叠；
  - 提供 `speak`、`clearPending`、`shutdown`，页面加载时初始化、销毁时释放引擎。
- `Index.ets` 中接入播报点：
  - 数字、运算符、小数点：朗读“一、加、点”等中文；
  - `C`：播报“已清空”；`⌫`：播报“已删除/没有可删除的内容”；
  - `=`/“确认”：成功后播报“计算完成，结果是…”，失败朗读屏幕错误提示；
  - “语音”按钮：仍明确提示“语音识别功能尚未接入”，不伪装识别结果。
- 新增数字转中文读法（支持负数、小数、最大到 9999 亿），保证结果播报自然。

### 8.3 真实构建结果

- 临时设置 `DEVECO_SDK_HOME`、`JAVA_HOME` 并临时把 DevEco `jbr\bin` 加入 `Path` 后运行
  `hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`
  → `BUILD SUCCESSFUL in 10 s 370 ms`。
- 编译器提示 `TextToSpeech` 系统能力非所有设备支持，属于能力边界警告，不阻断构建；项目未配置签名，产物为未签名 HAP。

### 8.4 尚待人工验收

- 已在 HarmonyOS 模拟器（`127.0.0.1:5555`）实测：安装并启动应用后，日志输出 `TTS engine created`；点击按键后出现完整 `speak start` → `speak finished` 流程。模拟器系统进程中有 `hmsapp.hiai.tts`，说明本模拟器镜像自带华为 TTS 服务，功能不限于真机。
- 仍需人工听音确认：模拟器/电脑音频输出是否正常、连续快速点击时播报是否清晰不重叠。
- 若某些设备提示“语音播报初始化失败”，说明该设备缺少 CoreSpeechKit TTS 能力。
- 语音识别仍未接入，后续可在 `startVoiceInput` 中接入 Speech Kit 识别，并申请麦克风权限。
