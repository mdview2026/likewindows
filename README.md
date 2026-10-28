# LikeWindows

[![build](https://github.com/mdview2026/likewindows/actions/workflows/build.yml/badge.svg)](https://github.com/mdview2026/likewindows/actions/workflows/build.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)

> 把 Windows 的键盘操作习惯搬到 macOS。原生 Swift，一个菜单栏小 App，无第三方依赖、不联网、不改系统设置。
>
> **English** — A tiny macOS menu bar app that brings Windows keyboard habits to macOS: `Win+R` = Run, `Win+D` = show desktop, `Win+←/→` = snap windows, `Win+V` = clipboard history, `Alt+Tab`/`Alt+F4`, and more. Native Swift + CGEventTap + Accessibility API. No dependencies, no network, MIT licensed.


```
Win+Tab      任务视图（调度中心）
Win+D        显示桌面 / 再按一次还原
Win+E        资源管理器（Finder）
Win+← / →    左右贴边分屏（再按一次变 2/3 宽）
Win+↑        最大化（填满工作区，不进 macOS 全屏）
Win+↓        还原 / 最小化
Win+M        最小化当前窗口
Win+Shift+←/→  把窗口丢到左/右那块显示器
Win+Ctrl+←/→   切换虚拟桌面（macOS 空间）
Win+L        锁屏
Win+S        搜索（Spotlight）
Win+Shift+S  区域截图
Win+R        运行（打开终端）
Win+Q        退出当前应用
Win+V        剪贴板历史面板
Win+1…9      切换到 Dock 上第 n 个应用（已在前台则循环它的窗口）
Win（轻按）   开始菜单（启动台 / macOS 26 的「Apps」）

Alt+Tab      切换应用
Alt+F4       关闭窗口
```

> Windows 键盘模式下（Win 键 = ⌘），`Win+S` / `Win+V` 会让位给 `⌘S` 保存 / `⌘V` 粘贴，
> 剪贴板历史改用 `Win+Shift+V`，搜索用原生 `⌘Space` —— 详见下文「关于 Win 键」。

## 关于「Win 键」

### 用 Windows 键盘（PC 键盘）

插在 Mac 上的 PC 键盘，**Win 键会被 macOS 识别成 ⌘**（左 Win → 左⌘，右 Win → 右⌘）。所以只需要选：

> 菜单栏图标 → **键盘：Windows 键盘（Win 键 = ⌘）**

（等价于配置 `"winKey": "anyCommand"`，左右两侧 ⌘ 都算 Win 键。）

代价是 ⌘ 上原有的几个快捷键会变成 Windows 语义，这是躲不开的，因为它们是同一颗键：

| 冲突 | 处理 |
| --- | --- |
| `⌘V` 粘贴 vs Win+V 剪贴板 | **粘贴优先**，剪贴板历史改到 `Win+Shift+V` |
| `⌘S` 保存 vs Win+S 搜索 | **保存优先**，搜索直接用 `⌘Space`（macOS 原生 Spotlight，本来就能用） |
| `⌘⇧S` 存储为 vs Win+Shift+S 截图 | **存储为优先**，系统截图快捷键 `⌘⇧4` 照常可用 |
| `⌘R` 刷新 / `⌘D` 书签 / `⌘L` 地址栏 | **被 Win+R / Win+D / Win+L 接管**（这就是你要的 Windows 习惯） |
| `⌘1…9` 浏览器切标签 | **被 Win+1…9 接管**（想保留就在菜单里取消勾选 `Win+1…9`） |
| `⌘←/→` 行首行尾 | **被窗口贴边接管**（想保留就在菜单里取消勾选「方向键贴边」） |

没在上面的 `⌘` 组合（`⌘C` `⌘X` `⌘A` `⌘Z` `⌘W` `⌘T` `⌘N` `⌘F` `⌘Tab`…）都不会被拦截，照常工作。

### 用 Mac 键盘

Mac 键盘没有 Win 键。默认用 **右侧 ⌘** 当 Win 键：应用几乎不会单独使用右侧 ⌘，不会抢走任何现有快捷键，你平时用左 ⌘ 的肌肉记忆完全不受影响。

其他可选：左⌘ / 左⌥ / 右⌥ / 左⌃ / 右⌃（选 ⌥ 时会自动关闭 Alt+Tab / Alt+F4，避免抢掉输入特殊字符的 Option 组合）。

## 首次启动

没有授权时会弹一个引导窗口：

```
还差一步就能用了
● 尚未授权 —— 现在按 Win 组合键不会有任何反应
1  点下面的「打开系统设置」，会跳到 隐私与安全性 → 辅助功能
2  在列表里打开 LikeWindows 的开关（列表里没有？点左下角 ＋ 手动选择）
3  回到这个窗口，状态会自动变成「已授权」，不用重启
```

- 状态每秒自动检测，授权后**自动关闭**，不用重启 App
- 窗口里会提醒 Windows 键盘用户去菜单里切「键盘：Windows 键盘（Win 键 = ⌘）」
- 关掉之后随时可以从菜单 →「新手引导…」重新打开

## 图标

```bash
make icon          # 重新生成 Resources/AppIcon.icns（1024px 预览在 build/icon-1024.png）
```

图标是代码画的（`scripts/make-icon.swift`，纯 CoreGraphics，无外部素材）：Windows 蓝渐变 squircle + 左右两块面板的分屏窗口。
10 个尺寸各自独立渲染，16px 下也清晰。`build.sh` / `release.sh` 会自动把它写进 `CFBundleIconFile`。

## 安装

```bash
cd ~/study/like_windows

make build      # 编译 + 打包到 build/LikeWindows.app
make run        # 启动

# 或者装到 ~/Applications 并设置开机自启
make install
make login-item
```

首次启动会弹出权限请求，或者手动操作：

**系统设置 → 隐私与安全性 → 辅助功能 → 打开 LikeWindows**

> 必须授权，否则既收不到键盘事件，也无法控制窗口。
> 未授权时菜单栏图标是黄色警告三角形，`~/Library/Logs/LikeWindows.log` 里会看到
> `事件监听创建失败…没有辅助功能权限`。

### 权限和签名（重要）

macOS 用「可执行文件的签名」认人。**ad-hoc 签名（`-`）的要求里包含 cdhash，每次重新编译都会变**，所以老授权会失效，表现为：改完代码重新编译 → 所有 Win 组合键都没反应。

两种解决方式：

1. **推荐**：用你自己的开发证书签名（脚本会自动找 `Apple Development` / `Developer ID Application`）。
   在**你自己的终端**里跑一次 `make build`，钥匙串弹窗点「始终允许」——
   之后证书不变，requirement 稳定，授权一次长期有效：

   ```bash
   make identity   # 看看本机有哪些签名身份
   make build      # 首次会让你授权钥匙串
   ```

2. 用 ad-hoc 签名时，每次重新编译后执行：

   ```bash
   make regrant    # 清掉旧授权记录
   make restart    # 重启 App（必须重启，旧进程还是旧身份）
   ```

> **重新编译后一定要 `make restart`**。`make build` 只是替换磁盘上的 App，
> 已经在跑的进程还是内存里的旧二进制，它的授权早就失效了，看起来就是「怎么按都没反应」。
> `make status` 会直接告诉你有没有这种旧进程。

判断当前状态（一条命令看全）：

```bash
make status
```

会打印：磁盘上 App 的签名方式、运行中的进程是不是重新编译前的旧二进制、最近 6 行日志、以及针对性的修复建议。

## 配置文件

`~/.config/likewindows/config.json`（菜单里「打开配置文件」，改完 2 秒内自动生效）：

```json
{
  "altTab" : true,
  "clipboardHistory" : true,
  "dockShortcuts" : true,
  "enabled" : true,
  "snap" : true,
  "tapForStartMenu" : true,
  "winKey" : "rightCommand"
}
```

| 字段 | 说明 |
| --- | --- |
| `enabled` | 总开关，热生效 |
| `winKey` | `rightCommand` / `leftCommand` / `leftOption` / `rightOption` / `leftControl` / `rightControl` |
| `altTab` | Alt+Tab 切换应用、Alt+F4 关闭窗口 |
| `tapForStartMenu` | 单独轻按 Win 键打开启动台 |
| `snap` | 方向键贴边 / 最大化 |
| `dockShortcuts` | Win+1…9 切换 Dock 应用 |
| `clipboardHistory` | Win+V 剪贴板历史（关掉即停止轮询剪贴板） |

## Win+V 剪贴板历史

按 `Win+V` 在鼠标所在屏幕下方弹出面板：

- `↑` `↓` 选择，`回车` 粘贴，`Esc` 关闭，直接打字可搜索过滤，双击也能粘贴
- 自动回到你原来的 App，再替你按一次 `⌘V`
- 最多保留 **50 条**，重复内容会自动提到最前
- **只存在内存里**，退出 App 即清空，不落盘
- 自动跳过密码管理器标记为「机密」的内容（`org.nspasteboard.ConcealedType`）

## Win+1…9 切换 Dock 应用

按 Dock 上**固定项**的顺序编号（`persistent-apps`，不含「最近使用」和文件夹）：

- 应用没开 → 启动它
- 已开着 → 激活它
- 已经在前台 → 按 `⌘\`` 循环它的窗口（对齐 Windows 点任务栏按钮的行为）

Dock 顺序变了不用改配置，每次按键都重新读 `com.apple.dock` 的 plist。

## 自定义按键

改 `Sources/LikeWindows/KeyTable.swift` 里的 `winBindings`：

```swift
Binding(keyCode: 3, modifiers: [], title: "Win+F 打开访达", run: { Synth.open("/System/Applications/Finder.app") }),
```

`keyCode` 是 macOS 虚拟键码（F=3、D=2、E=14…），`modifiers` 是除 Win 之外额外需要的修饰键（`.maskShift` / `.maskControl` / `.maskAlternate` / `.maskCommand`，精确匹配）。
改完 `make build && open build/LikeWindows.app`。

## 实现说明

| 文件 | 作用 |
| --- | --- |
| `KeyTap.swift` | `CGEventTap` 全局键盘捕获，只处理 `keyDown/keyUp/flagsChanged`，回调里只做匹配，动作异步派发（避免 tap 超时被系统关掉） |
| `KeyTable.swift` | 键码 → 动作 的映射表 |
| `WindowManager.swift` | 贴边、最大化、最小化、显示桌面、跨屏移动 |
| `AX.swift` | `AXUIElement` 读写封装 + AX/NSScreen 两套坐标系换算 |
| `Synth.swift` | 合成按键，复用系统快捷键（Spotlight / 调度中心 / 锁屏 / 截图），带标记位防止自触发 |
| `Actions.swift` | 每个 Windows 动作的具体实现 |
| `ClipboardStore.swift` | 剪贴板轮询（`changeCount`）、去重、机密内容过滤 |
| `ClipboardPanel.swift` | Win+V 面板：`NSPanel` + `NSTableView` + 搜索过滤 |
| `DockApps.swift` | 解析 `com.apple.dock` 的 `persistent-apps`，按序号激活 |
| `SelfTest.swift` | `--selftest` 自检：权限 / Dock 解析 / 剪贴板监听 / 生效组合 |
| `Onboarding.swift` | 首次启动引导窗口：三步图解 + 授权状态实时检测 + 授权后自动关闭 |
| `Permissions.swift` | 辅助功能权限的统一入口（弹框 / 打开设置 / 重置授权） |

细节处理：

- 被拦截的 `keyDown` 会把配对的 `keyUp` 一起吞掉，并把按键重复（auto-repeat）也吞掉，避免贴边动作连续触发；
- 最大化前记录原窗口尺寸，`Win+↓` 能精确还原；
- 合成的按键带 `eventSourceUserData` 标记，事件监听看到就放行，不会自我循环；
- 窗口操作跨屏时按 `visibleFrame`（扣掉菜单栏 / Dock）计算，贴边不留缝；
- 走的是 Accessibility 接口而不是 macOS 原生全屏，所以不会把窗口丢进独立空间。

## 打包发布（Developer ID + 公证）

App Store 上不了（必须开沙箱，沙箱里拿不到全局键盘事件，见下文「为什么不在 App Store」），所以走**直接分发**：

```bash
# 一次性：把公证凭证存进钥匙串（需 Apple ID + Team ID + App 专用密码）
make notary-setup            # profile 名默认 likewindows-notary，可用 PROFILE= 覆盖

# 正式发布
make release                 # 版本号取 Resources/Info.plist
make release VERSION=1.1.0

# 本地演练：ad-hoc 签名、跳过公证，只验证打包 / DMG / 校验流程
make release-dry
```

流水线（`scripts/release.sh`）：

```
编译 → 组装 .app（写入版本号，可选 AppIcon.icns）
     → codesign --options runtime --timestamp（Developer ID Application）
     → 打包 zip → notarytool 提交 → stapler 装订进 .app
     → 制作 DMG（含 /Applications 软链，拖拽安装）
     → 签名 DMG → 公证 DMG → stapler 装订进 .dmg
     → codesign -dv / spctl -a -t exec / spctl -a -t open 校验
```

产物：`dist/LikeWindows-<版本>.dmg`、`dist/stage/LikeWindows.app`

公证失败时会打印 submission id，直接：

```bash
make notary-log ID=<submission-id>
```

注意事项：

- 必须用 `Developer ID Application` 证书（`Apple Development` 只在本机有效，别人下载会被 Gatekeeper 拦）。
- 首次签名钥匙串会弹窗，点「始终允许」；脚本在拿不到私钥时会给出明确提示。
- 图标可选：放一个 `Resources/AppIcon.icns`，打包时会自动写进 `CFBundleIconFile`。
- **换了签名身份的构建需要重新授权辅助功能**，发布前在干净环境里验证一遍安装 + 授权流程。

### 发布前检查清单

- [ ] `make icon` 已生成图标（否则 Dock 里是空白图标）
- [ ] `make release-dry` 跑通
- [ ] `make release` 产出 `dist/LikeWindows-<版本>.dmg`
- [ ] 在干净环境（另一个账号 / 另一台 Mac）装一遍：挂载 DMG → 拖进 Applications → 首次启动看到引导窗口 → 授权 → Win+R 生效

### 为什么不在 App Store

Mac App Store 强制 App Sandbox，而这个工具的核心能力在沙箱里都拿不到：

| 能力 | 沙箱 | 后果 |
| --- | --- | --- |
| `CGEventTap` 监听并吞掉键盘组合 | ❌ | Win+R / Win+D 这类"抢占 ⌘ 语义"全部失效 |
| `AXUIElement` 控制其他 App 窗口 | ✅ | 贴边 / 最大化可以（Magnet 就是这么做的） |
| 读 `~/Library/Preferences/com.apple.dock.plist` | ❌ | Win+1…9 失效 |
| `CGEvent.post` 合成 ⌘V / ⌘Tab | ⚠️ | 审核风险，剪贴板自动粘贴不可用 |

能上架的部分只剩「固定快捷键 + 窗口贴边」，那已经是另一个产品（又一个 Magnet），而差异化恰好全在被沙箱禁掉的那一半。同类工具（Alfred、Raycast、Rectangle、BetterTouchTool）也都在 App Store 之外，走 Developer ID 公证直发。

## 自检

```bash
build/LikeWindows.app/Contents/MacOS/LikeWindows --selftest
```

会打印：辅助功能权限、当前 Win 键、Dock 里解析出的 9 个应用、2 秒剪贴板采样结果、以及所有生效的组合键。装完了不放心可以先跑这个。

单独验证某个动作（不需要键盘监听，用来区分「键没收到」和「动作执行失败」）：

```bash
./build/LikeWindows.app/Contents/MacOS/LikeWindows --do "Win+D"
./build/LikeWindows.app/Contents/MacOS/LikeWindows --do "运行"
```

`--panel` 参数可直接弹出剪贴板面板，用来单独调 UI。

## 常见问题

**用了 PC 键盘，Win 键完全没反应**
macOS 把 Win 键认成 ⌘（左 Win=左⌘ 55，右 Win=右⌘ 54）。菜单里切到「键盘：Windows 键盘」，或把配置改成 `"winKey": "anyCommand"`。确认具体键码：菜单 →「记录按键 12 秒」，然后按一下 Win+R，看日志里的 `按键诊断：按下 keyCode=… 修饰=[⌘]`。

**按了没反应 / 只有部分键有效**

先看菜单栏图标是不是黄色警告 → 没给辅助功能权限。

然后看日志：

```bash
tail -5 ~/Library/Logs/LikeWindows.log
```

- `事件监听创建失败：没有辅助功能权限` → 没授权，或授权已因重新编译失效 → `make regrant && make restart`
- **「辅助功能」列表里根本看不到 LikeWindows** → 说明系统授权框没弹出来过（这个框才是把 App 登记进列表的唯一途径）。菜单里点「② 重新注册授权」，或 `make regrant && make restart`，然后在系统弹窗里点「打开系统设置」；还是没有就点列表下方的 `＋` 手动选中 `build/LikeWindows.app`（菜单「③ 在访达中显示」能直接定位它）
- `事件监听已启动` 但按键没有 `触发 …` 日志 → 事件被系统或前台 App 抢走了（比如输入法、其他键盘工具）
- 有 `触发 Win+D 显示桌面` 但没有 `显示桌面：最小化成功 N 个` → 动作执行失败，看下一行日志

**注意**：右⌘ 本身就是 ⌘，所以未授权时按 `⌘Tab`/`⌘M`/`⌘Q` 看起来「能用」其实是 macOS 原生快捷键；`⌘D`、`⌘R` 在 Finder/桌面上本来就没反应，于是最容易先被怀疑「坏了」。

**某个 App 里 Win+← 无效**
部分 App（如部分 Electron 应用）会拒绝 AX 改窗口尺寸。可尝试在 App 内先退出全屏（⌃⌘F）。

**Win+D 之后想恢复**
再按一次即可。如果某次没恢复，手动点 Dock 图标即可；程序也加了「无窗口被最小化时不进入已隐藏状态」的保护。

**Win+1 打开的 App 不是我想要的**
Win+1…9 对应的是 Dock 里的**固定项顺序**（左起第 1 个），不是「最近使用」。把想要的 App 拖到 Dock 排好序即可。

**剪贴板里没记录我刚才复制的东西**
一是确认菜单里「Win+V 剪贴板历史」是勾选状态；二是某些 App 复制的是富文本/图片，当前只记纯文本；三是密码管理器会主动打「机密」标记，这类内容按设计不记录。

**想彻底卸载**
```bash
make uninstall
rm -rf ~/.config/likewindows
# 再到「系统设置 → 隐私与安全性 → 辅助功能」里移除 LikeWindows
```

## 已知限制

- `Alt+Tab` 是「合成一次 ⌘Tab」，会切到上一个应用，而不是像 Windows 那样按住不放循环选择；
- `Win+D` 是逐个窗口最小化，窗口多的应用略有延迟（几百毫秒）；
- 虚拟桌面切换依赖系统默认快捷键 `⌃←/→`，改过系统快捷键就失效；
- 不支持 Windows 的贴边布局（Snap Layouts）缩略图面板；
- 剪贴板历史只处理纯文本（图片、富文本会退化为其文本形式或跳过），且不落盘、不跨设备同步；
- Win+1…9 只识别 Dock 固定项，不含「最近使用」区域和被收起的分组。
