# AI 修改日志

> 记录 Codex 对本项目实际完成的修改及验证边界。本文档不代替 Git 历史。

## 2026-09-07 16:10 (UTC+08:00) - 模拟器实测 CoreSpeechKit TTS 可用，并修正大数中文读法

- 目标：
  - 确认“点击按键语音播报”在 HarmonyOS 模拟器上即可运行，而不只限真机；修正中文读数跨“万/亿”段的补零错误。
- 修改文件：
  - `entry/src/main/ets/common/TtsSpeaker.ets`
  - `AI辅助编程说明.md`
- 修改内容：
  - 数字转中文从“分段简单拼接”改为“四位分段 + 跨段补零”算法：例如 `100010000` 现在读“一亿零一万”，此前会漏零读成“一亿一万”；`100000001` 读“一亿零一”。
  - 补充模拟器实测记录：不需要改用预录音频方案，CoreSpeechKit 在模拟器可用。
- 修改原因：
  - 用户目标环境是模拟器，且抽查算法时发现万/亿交界处存在漏“零”边界错误，一并修正，避免结果播报在边界数字上读错。
- 验证：
  - 重新构建 → `BUILD SUCCESSFUL in 10 s 33 ms`。
  - 通过 `hdc install -r` 安装到正在运行的 HarmonyOS 模拟器（`127.0.0.1:5555`）并启动，`hilog` 显示 `TtsSpeaker: TTS engine created`。
  - 此前点击测试的日志中出现完整 `speak start` → `speak finished` 流程；模拟器系统进程列表中存在 `hmsapp.hiai.tts`，说明模拟器镜像自带华为 TTS 服务，非仅真机可用。
- 未验证边界：
  - 实际是否听到声音取决于模拟器/电脑音频输出设置，请人工听音确认；超大数（万亿以上）读法按“数字过大”提示处理，未逐字人工听。
  - 语音识别（Speech Kit ASR）仍未接入。
- 回滚建议：
  - 同前一条：删除 `TtsSpeaker.ets` 并把 `Index.ets` 恢复旧版即可；无需处理持久数据。

## 2026-09-07 16:05 (UTC+08:00) - 接入点击按键的语音播报（CoreSpeechKit TTS）

- 目标：
  - 让用户点击计算器按键时能立即听到中文语音反馈，为后续接入语音识别先打通系统发声链路。
- 修改文件：
  - `entry/src/main/ets/common/TtsSpeaker.ets`（新增）
  - `entry/src/main/ets/pages/Index.ets`
  - `AI辅助编程说明.md`
- 修改内容：
  - 新增 `TtsSpeaker` 单例，封装系统 CoreSpeechKit 的 `textToSpeech`：使用离线中文合成，不依赖麦克风权限和联网。
  - 播报文本进入队列串行朗读，快速连点不会造成多条语音重叠；清空、退格、计算等关键操作前会丢弃积压的旧播报，让反馈及时响起。
  - 页面 `aboutToAppear` 时异步初始化 TTS 引擎，`aboutToDisappear` 时释放引擎资源；初始化失败时提示区会显示当前设备不支持。
  - 数字、小数点和运算符按键点击后朗读对应中文（如“一”“加”），清空、删除、等号等有对应反馈；计算成功后朗读“计算完成，结果是…”，计算失败时朗读屏幕上的错误提示。
  - 新增阿拉伯数字转中文读法（含负数、小数、千位分隔段落），方便 TTS 直接朗读结果。
- 修改原因：
  - 原代码中“语音”按钮只是 UI 占位（`Speech Kit 待接入`），没有任何发声能力；本次先接入无需联网、无需账号的离线 TTS，实现“点击按键即有语音响应”，便于在真机上尽快验收。
- 验证：
  - 临时设置 `DEVECO_SDK_HOME`、`JAVA_HOME` 并把 DevEco `jbr\bin` 加入本次进程的 `Path`，运行 `hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --no-daemon` → `BUILD SUCCESSFUL in 10 s 370 ms`。
  - 编译器仅给出系统能力提示（`TextToSpeech` 非所有设备支持）和未配置签名的提示，均不阻断构建。
- 未验证边界：
  - 未在真机运行，TTS 引擎能否成功初始化、音色是否可用需在 HarmonyOS 真机上确认。
  - 语音识别（Speech Kit ASR）仍未接入，点击“语音”按钮仍提示“尚未接入”。
  - 项目未配置签名，本次产物仍为未签名 HAP。
- 回滚建议：
  - 删除 `entry/src/main/ets/common/TtsSpeaker.ets`，并将 `Index.ets` 中新增的语音播报调用恢复为上一版行为即可；无数据库或持久化数据影响。

## 2026-09-07 15:21 (UTC+08:00) - 将 ArkUI 首页文字改为“电子”

- 目标：
  - 将首页显示的 `Hello World` 改为“电子”，并记录 AI 辅助生成、调试和人工审核过程。
- 修改文件：
  - `entry/src/main/ets/pages/Index.ets`
  - `AI辅助编程说明.md`
- 修改内容：
  - 首页初始文字由 `Hello World` 改为“电子”。
  - 点击后的文字由 `Welcome` 改为“电子页面”，避免交互后重新出现无关英文。
  - 组件 ID 由 `HelloWorld` 改为 `ElectronicText`，使名称与当前用途一致。
  - 新增原始提示词、优化提示词、代码、真实报错修复过程和人工审核意见。
- 修改原因：
  - 满足页面中文内容需求，并避免只改初始值而遗漏点击逻辑。
- 验证：
  - 未设置有效 `DEVECO_SDK_HOME` 时运行 Hvigor → 失败，报错 `Invalid value of 'DEVECO_SDK_HOME'`。
  - 临时设置 `DEVECO_SDK_HOME` 后构建 → `CompileArkTS` 通过，`PackageHap` 因 `spawn java ENOENT` 失败。
  - 临时设置 `DEVECO_SDK_HOME`、`JAVA_HOME` 并把 DevEco `jbr\bin` 加入本次进程的 `Path`，运行 `hvigorw.bat assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon` → `BUILD SUCCESSFUL in 4 s 299 ms`，生成 `entry/build/default/outputs/default/entry-default-unsigned.hap`（119396 字节）。
- 未验证边界：
  - 未启动 Previewer、模拟器或真机，页面视觉效果及点击交互仍需人工运行确认。
  - 项目未配置签名，构建日志提示跳过签名，当前产物是未签名 HAP。
- 回滚建议：
  - 若需恢复模板页面，将 `message` 初始值改回 `Hello World`，点击赋值改回 `Welcome`，组件 ID 改回 `HelloWorld`；删除本次新增的两份说明文档即可。

## 2026-09-07 15:48 (UTC+08:00) - 实现智能语音计算器界面与四则运算

- 目标：
  - 按用户提供的课堂参考图，将简单文字首页改造成可操作的 ArkUI 智能语音计算器，并保留真实的 AI 辅助、调试和人工审核记录。
- 修改文件：
  - `entry/src/main/ets/pages/Index.ets`
  - `AI辅助编程说明.md`
- 修改内容：
  - 使用 `Column`、`Row`、`Text`、`Button`、`ForEach` 完成标题、显示、5×4 按键和语音提示区域。
  - 新增表达式、结果、提示和语音占位状态；实现数字、小数、加减乘除、优先级、清空、退格、等号和确认逻辑。
  - 使用双栈计算表达式，没有调用 `eval()`；增加表达式长度、重复小数点、末尾运算符和除零保护。
  - 语音入口仅更新等待状态并明确标注 `Speech Kit 待接入`，未伪装语音识别已经完成。
  - 更新 AI 过程说明，记录 GitHub 资料取舍、核心代码、实际编译错误和人工验收步骤。
- 修改原因：
  - 满足课堂图片对可运行计算器界面和工程审核过程的要求，同时保持未接入能力的真实边界。
- 验证：
  - 第一次构建 → `CompileArkTS` 失败，编译器报告 `RowAttribute` 不存在 `minHeight`，定位到 `Index.ets:130`。
  - 将语音提示区 `.minHeight(44)` 改为 `.height(44)` 后，临时设置构建所需的 `DEVECO_SDK_HOME`、`JAVA_HOME` 和 `Path`，运行 `hvigorw.bat assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon` → `BUILD SUCCESSFUL in 9 s 314 ms`。
  - 生成 `entry/build/default/outputs/default/entry-default-unsigned.hap`（151864 字节）。
- 未验证边界：
  - 未在 Previewer、模拟器或真机执行点击测试，计算交互和响应式视觉效果仍需人工运行确认。
  - Speech Kit、麦克风权限、真实识别和结果播报均未接入。
  - 项目未配置签名，本次产物是未签名 HAP。
- 回滚建议：
  - 本目录不是 Git 仓库；如需回滚，应先备份当前 `Index.ets`，再手工恢复上一版页面。不要删除构建环境或用户文件。
