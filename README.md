# 悬浮时钟 iOS

Android 版 [time_float](https://github.com/niasand/time_float) 的原生 iOS 移植。SwiftUI 做设置页，画中画、取色圆盘和采样缓冲用 UIKit / AVKit。

最低系统：**iOS 17.0**（iPhone、iPad）。选 17 是因为锁屏实时活动按钮、可交互小组件从 iOS 17 才完整；控制中心按钮要 iOS 18，没有就自动不出现。画中画采样缓冲本身 iOS 15 就有，但整套功能放在一个版本上，少写兼容分支。

用 **Xcode 16 或更新版本**打开。2026 年的 Xcode 都可以。

占位 Bundle ID：`com.yourname.timefloat`。签名团队留空，装到自己手机前要在 Xcode 里选 Personal Team。

## 悬浮是怎么做的

iOS 不让第三方 App 像 Android `TYPE_APPLICATION_OVERLAY` 那样，自己开一个永远盖在别的 App 上的窗口。能稳定浮在其他 App 上、又能用免费个人团队签名的做法，是系统 **画中画（Picture in Picture）**：

1. 把时钟画成一帧帧图像。
2. 放进 `AVSampleBufferDisplayLayer`。
3. 用 `AVPictureInPictureController` 的 `ContentSource` 交给系统。
4. 打开 Background Mode 里的 Audio（`UIBackgroundModes = audio`），并循环播放一段几乎听不见的声音，让进程在离开 App 之后还活着，时钟才不会冻住。

这是 iOS 上悬浮时钟的通行做法，不需要付费账号才有的 entitlement。画中画窗口可以拖、可以捏合缩放，位置由系统记住。

另外两条不依赖画中画的表面，用来补「字幕点不到」和「锁屏上看时间」：

| 表面 | 作用 | 免费签名 |
| --- | --- | --- |
| 画中画 | 浮在其他 App 上的时钟，秒和毫秒以这里为准 | 可以。只要 Info.plist 里的 audio 后台模式，不是付费能力 |
| 锁屏实时活动 / 灵动岛 | 秒级时间、记录当前字幕、切换、关闭。本机 `Activity.request(pushType: nil)`，不申请推送 | 可以。不要打开 Push Notifications |
| 主屏幕 / 锁屏小组件 | 分钟级时间，中号和锁屏矩形小组件上有「记录」按钮 | 可以 |
| 控制中心（仅 iOS 18） | 一个「记录字幕」按钮 | 可以。和小组件是同一个扩展 |

只用了 **两个** Bundle ID：主 App，和 `主 ID.widget` 扩展。实时活动、小组件、控制中心都在这一个扩展里。免费账号的 App ID 数量有限，所以没有再拆扩展。

刻意没用这些免费个人团队签不上的能力：远程推送、iCloud / CloudKit、Associated Domains、App 内购买、Sign in with Apple、Apple Pay。实时活动不申请 push token，否则个人团队会直接创建失败。

## 功能

### 原版就有

- 日期 `yyyy-MM-dd 周几`，时间 `HH:mm:ss`，等宽数字。
- 默认深灰背景 `#2E2E2E`。
- HSV 圆盘：角度是色相，半径是饱和度，明度固定为最亮。拖动才改颜色，默认深灰会一直留到你去拖圆盘。
- 不透明度 20%–100%，字号 12–48。文字按背景亮度自动黑/白（亮度阈值 0.6，和原版同一套系数）。
- 字幕最多 16 条，每条最多 12 个字，不能空、不能重复。
- 首次安装内置那 12 条路测停车动线。你改过之后以你的列表为准，删光了也不会再自动填回来。
- 点字幕：淡绿色 `#66BB6A` 高亮 3 秒，白字加粗，并追加一行 SRT。
- 行格式与原版一致：`2026-11-07 14:25:30：停车前`（冒号是全角 `：`）。打开「显示毫秒」后，这一行会多 `.毫秒`。
- 悬浮卡片可拖，位置记住。时间区域拖动，字幕区域点按。
- 开关打开时，下次进入 App 会自己再打开（对应原版 `onResume` 自愈）。
- 有明确的关闭入口：本页开关、画中画关闭按钮、控制中心里这次播放的暂停/停止、实时活动上的「关闭」。

### 新加的

- **网络对时**。先并行问 SNTP：`time.apple.com`、`time.cloudflare.com`、`ntp.aliyun.com`、`cn.pool.ntp.org`，取往返最短的一次。都失败再读 HTTPS 响应头里的 `Date`（Cloudflare、Apple、百度、阿里云），HTTP 只能到秒。页面上写出偏差、往返和来源。校正默认开，关掉就只显示设备时间，但上次测到的偏差还留着。
- **毫秒**。打开后画中画大约 30 帧/秒，数字是这一帧的真实毫秒，会跳着走，不是每毫秒加 1。关掉时大约 10 帧/秒，秒的跳动误差在一帧以内。
- **外部记录**。画中画里的画面点不到。字幕列表里标星的那条，可以由锁屏实时活动、小组件、控制中心（iOS 18）和快捷指令写入，不必先打开 App。锁屏上的按钮设成未解锁也能跑。
- **「下一条」**。锁屏上切换标星字幕。
- **快捷指令**「记录指定字幕」，可以绑到轻点背面或操作按钮，一条字幕一个快捷指令。
- **SRT 查看、分享、清空**。文件在 App 沙盒里，并复制一份到「文件」App：我的 iPhone → 悬浮时钟 → TimeFloat → `road_test_srt.srt`。
- **本页保持常亮**，方便手机架在车上时看设置页。盖不住别的 App 的自动锁屏。
- **「不打断其他 App 的声音」**默认开，保活音频和音乐混在一起。如果离开 App 后时钟停住，关掉这一项，让它独占音频，会更稳，但会暂停音乐。
- **主屏幕和锁屏小组件**，以及灵动岛。小组件的时间按分钟刷新，这是 WidgetKit 的限制。
- 设置页跟随系统深色模式。悬浮卡片本身仍是你选的颜色。

## 和原版比，做不到的地方

- 没有真正的系统悬浮窗。画中画是一个系统视频小窗，会挡住一块区域，不能做成原版那种任意透明、贴着别的 App 内容的形状。不透明度是和黑色混合，不是透视后面的 App。
- 画中画里的字幕不能点。记录要靠本页、锁屏、小组件、控制中心或快捷指令。
- 不能开机自启。重启后要再打开一次本 App，开关如果还是开的，会自己再挂上画中画。
- 不能像 Android 前台服务那样在通知栏常驻。代替品是控制中心里的播放项（暂停/停止会关掉悬浮）和实时活动。
- 保活需要一段近乎无声的循环音频。状态栏或灵动岛上可能出现播放标记。这不是在录音，没有麦克风权限。
- 省电模式、来电、或者系统把后台音频停掉时，画中画可能停住。回到 App 再开一次。
- 同一时间系统只允许一个画中画。别的视频正在画中画时，这个时钟起不来。
- 模拟器通常没有画中画。设置、对时、字幕和 SRT 可以在模拟器里看，悬浮要真机。
- SRT 不在「下载 / TimeFloat」。iOS 没有对应的公共下载目录可写。用「文件」App 里这个 App 的文件夹，或本页的分享。
- 没有 Android 那种「卸载重装后 MediaStore 把文件改名」的情况，所以没有那条改名提示。
- 小组件不是逐秒的。要看秒和毫秒，用画中画或打开 App。
- 实时活动的秒数靠 App 在画中画期间每秒推一次。系统如果限流，以画中画为准。没有服务器推送，App 不在跑的时候它不会自己跳秒。
- 免费描述文件 7 天过期，过期后 App 打不开，要重新 Run 一次。最多注册有限台自己的设备，不能发给别人装。

## 用 Xcode 打开并装到自己的 iPhone

免费 Apple ID 即可，不需要加入付费的 Apple Developer Program。描述文件 7 天后过期。

### 1. 打开工程

```bash
git clone <这个仓库>
open TimeFloat.xcodeproj
```

直接打开 `TimeFloat.xcodeproj`。仓库里的 `project.yml` 是同一份工程的 XcodeGen 描述，这台构建机上没有 XcodeGen，**不要**为了打开工程先去跑 `xcodegen`。已经提交的 `.xcodeproj` 就是能开的那份。

Xcode 若提示升级工程格式，同意即可。

### 2. 改 Bundle ID

只改 `Config/Shared.xcconfig` 这一个文件：

```
APP_BUNDLE_ID = com.你的名字.timefloat
WIDGET_BUNDLE_ID = com.你的名字.timefloat.widget
APP_GROUP_ID = group.com.你的名字.timefloat
DEVELOPMENT_TEAM =
```

三条要一起改，而且必须是你自己的、没被别人占用的 ID。`WIDGET_BUNDLE_ID` 保持「主 ID + `.widget`」。`APP_GROUP_ID` 必须以 `group.` 开头。

`DEVELOPMENT_TEAM` 留空。团队不写在这个文件里。

Info.plist 和 entitlements 里用的是 `$(APP_GROUP_ID)`、`$(APP_BUNDLE_ID)`，Swift 再从 Info.plist 读 App Group。改这一处就够，不用改源码。

改完后菜单 **Product → Clean Build Folder**。

### 3. 选 Personal Team

两个 Target 都要签，只签主 App 不够：

1. 用你的 Apple ID 登录 Xcode（Settings → Accounts）。
2. 点工程，Target 选 **TimeFloat**。
3. Signing & Capabilities → 勾选 Automatically manage signing。
4. Team 选你的 **Personal Team**（名字一般是 “你的名字 (Personal Team)”）。
5. Target 换成 **TimeFloatWidget**，同样选这个 Team。

不要添加 Push Notifications、iCloud、Associated Domains、In-App Purchase。实时活动不需要它们。

Signing 里应该能看到 App Groups，标识是你在 xcconfig 里写的 `group...`。两个 Target 必须是同一个组。Xcode 会在第一次编译时向苹果注册这个组。

如果报 App Groups 个人团队不支持、或注册失败：

1. 两个 Target 的 entitlements 里删掉 `com.apple.security.application-groups` 整段，或者在 Signing 里关掉 App Groups。
2. 主 App 的画中画、本页字幕、SRT、对时仍然可用。记录文件改落在本 App 的文档目录。
3. 小组件上的「记录」按钮和主 App 对不上，因为两边不再共享同一份数据。小组件上的钟点仍然会走。

### 4. 装到 iPhone

1. 数据线连上 iPhone，解锁，点「信任这台电脑」。
2. 窗口顶部运行目标选你的 iPhone，不要选模拟器（模拟器没有画中画）。
3. 按 Run。

第一次会要你在手机上开启开发者模式：设置 → 隐私与安全性 → 开发者模式，打开后按提示重启。

免费账号在每台设备上同时只能装很少的几个这样签名的 App（常见限制是 3 个）。这个工程占 2 个 App ID（主 App + 小组件扩展），在设备上是一个图标。

### 5. 信任开发者

装好后如果点图标打不开，提示不受信任的开发者：

设置 → 通用 → VPN 与设备管理（有的系统写「设备管理」）→ 开发者 App → 你的 Apple ID → 信任。

然后回主屏幕再打开「悬浮时钟」。

### 6. 每 7 天重签一次

免费描述文件从生成起 **7 天**有效。到期后图标还在，点开会立刻退出。

重签：手机连上电脑，用同一个 Apple ID 打开这个工程，再按一次 Run。不需要改代码，也不需要删掉手机上的 App。开关、字幕、SRT、颜色都在本机，重装 Run 不会清掉，除非你把 App 删掉。

建议到期前一天连上电脑跑一次。没有电脑在身边时，过期后只能等下一次连接。

## 使用

1. 打开 App，看一眼对时结果。偏差是「设备慢 / 设备快多少毫秒」。
2. 打开「显示悬浮窗」。本页会出现可拖的时钟卡片。
3. 离开 App（上滑回主屏幕或切到别的 App），系统画出画中画。
4. 点卡片上的字幕，或列表里的「记录」，会高亮并写一行 SRT。
5. 人在别的 App 里时：锁屏看实时活动，点标星的那条；或者下拉控制中心点「记录字幕」（iOS 18，需要先把按钮加进控制中心）。
6. 回到本 App：点画中画上的「回到 App」。这对应原版「点一下时钟回设置」。
7. 关掉悬浮：本页开关、画中画的关闭、实时活动的「关闭」，或控制中心里这次播放的暂停。

系统「设置 → 通用 → 画中画」要开着，默认就是开的。

小组件：长按主屏幕 → 编辑 → 左上角加号 → 悬浮时钟。锁屏小组件同样从锁屏自定义里加。

## 工程里有什么

```
Config/Shared.xcconfig          Bundle ID、App Group、空的 Team
Shared/                         App 和小组件共用的设置、SRT、对时包、实时活动、App Intents
TimeFloat/                      主 App：设置页、圆盘、画中画、保活音频、SNTP
TimeFloatWidget/                小组件、实时活动、iOS 18 控制中心按钮
SelfCheck/main.swift            不依赖 UIKit 的逻辑自检
Scripts/generate_xcodeproj.py   重新生成 .xcodeproj（这台机器没有 Xcode）
```

逻辑自检（有 Swift 工具链时，不需要 iOS SDK）：

```bash
swiftc -o /tmp/timefloat-selfcheck \
  Shared/ColorMath.swift \
  Shared/CaptionRules.swift \
  Shared/NTPPacket.swift \
  Shared/ClockFaceText.swift \
  SelfCheck/main.swift
/tmp/timefloat-selfcheck
```

## 这次实际验证了什么

这台构建机是 Linux，没有 macOS，也没有 Xcode，**没有编译过 iOS 工程，没有在模拟器或真机上跑过**。

做过的检查：

- 按原版源码对过功能：圆盘、透明度、字号、12 条默认字幕、16 条 / 12 字限制、高亮 3 秒、SRT 行格式、位置记忆、开关自愈。
- `project.pbxproj` 能被解析：括号配对，对象 ID 不重复，主 App 21 个 Swift 文件、扩展 14 个（含共用代码），小组件扩展嵌进主 App，部署目标 iOS 17，Bundle ID 和 App Group 走 xcconfig。
- 生成了 1024 的 App 图标并看过图。
- 用 Linux 上的 Swift 6.0.3 编译并跑过 `SelfCheck`（颜色、字幕规则、SNTP 编解码、时钟偏差、SRT 行格式）。**通过。** 这不包含 UIKit、画中画、小组件和实时活动，那些 API 在 Linux 上不存在。

没有做过的：

- 没有 `xcodebuild`，没有模拟器，没有真机。iOS 工程没有被苹果的编译器编过。

装到手机上之后，请你自己确认这几件事：画中画能在桌面和其他 App 上拖动且秒在走；点字幕能写出 `road_test_srt.srt`；锁屏实时活动的「记录」在 App 退到后台时也能追加一行。这三件在这里都没法替你点。
