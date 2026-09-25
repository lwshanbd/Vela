# Vela

Tesla 的本地蓝牙副屏。手机固定在车里的支架上，通过 BLE 直连车辆，显示车速、档位、电量，并控制空调和音乐。不需要网络，不需要 Tesla 账号。

## 构建

工程由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成。改了 `project.yml` 或增删了源文件，重新生成一次：

```bash
xcodegen generate
```

然后用 Xcode 打开 `Vela.xcodeproj`，选 `Vela` scheme。

- 最低系统 iOS 17，仅 iPhone
- Swift 6，strict concurrency
- 签名沿用 BeadInventory：Team `S4BS47942Q`，自动签名，Bundle ID `com.beadinventory.vela`
- 依赖我们 fork 的 [swift-tesla-ble](https://github.com/lwshanbd/swift-tesla-ble)，SPM 锁定在 `d07fcac`。原库在 [shoujiaxin/swift-tesla-ble](https://github.com/shoujiaxin/swift-tesla-ble)。fork 补上了原库丢掉的字段：GPS 位置和朝向、播放状态、更多的充电、空调、车身和软件更新状态。车没上报的字段一律是 nil，不会变成 0。

## 结构

```
Vela/
  App/         入口。AppModel 挂在 App 上，不挂在任何 View 上
  Vehicle/     Tesla BLE 层，只有这里 import TeslaBLE
    VehicleConnection   连接、握手、轮询、断线重连、发命令
    PairingSession      首次配对：addKey，然后等车主在车上确认
    NearbyTeslaScanner  设置流程里列出附近的 Tesla
    VehicleIdentity     VIN、车型名、Keychain 私钥
  State/       AppModel、AppSettings、VehicleState
               把车辆数据转成界面要显示的值，把用户操作转成命令
  UI/          只读 AppModel，只发用户意图
    Dashboard/   竖屏、横屏两套布局，共用 Instrument 和各个模块
    Pages/       Now Playing、Climate、Settings、Speed display
    Onboarding/  欢迎、搜索、选车、输入 VIN、配对
  Preview/     SwiftUI Preview 用的假数据，只在 DEBUG 编译
```

## 数据刷新

- 车速和档位用 `fetchDrive()`，这是库给的 drive-only 快速通道。请求一个接一个发，最快 4 Hz，和设计稿里「数字不闪」的上限一致。挂 P 档时降到 1 Hz。
- 电量、空调、媒体合成一个 `fetch(.categories(...))` 请求，每 5 秒一次。Now Playing 或 Climate 页打开时改成 2 秒一次。
- 发完命令立刻再拉一次状态，所以界面上显示的是车实际生效的值。
- 车速不做补间。车没回车速时，挂 P 档显示 0，其他档位显示占位横条。

## 连接生命周期

- `VehicleConnection` 的生命周期跟着 App 走，旋转屏幕、View 重建都碰不到它。
- 断线后自动重连，退避间隔 1、2、4、8、10 秒。车速连续 4 次请求失败，就当作断线处理。
- 进后台先保持 20 秒。切出去看一眼地图再回来，连接不断。超过 20 秒就断开，免得一直把车吵醒。回到前台自动重连。
- 屏幕常亮只在一处设置（`RootView`）。同时满足这几条才常亮：设置里打开了、App 在前台、在仪表盘上、车已连接或正在重连。

## Tesla BLE 实际能做什么

对照了 swift-tesla-ble（我们的 fork）的公开 API 和 Tesla vehicle-command 的 protobuf。fork 里还能读到位置、胎压、车身、充电细节等，界面上还没用，等新设计稿。

| 功能 | 状态 |
| --- | --- |
| 车速、档位 | 已接入，`DriveState` |
| 电量 | 已接入，`ChargeState.batteryLevel` |
| 空调开关 | 已接入，`.climate(.on / .off)` |
| 主驾、副驾温度 | 已接入，`.climate(.setTemperature)` |
| 两侧同步 | App 自己的逻辑：打开时两侧发同一个温度 |
| 风量 | 只能读（`fanStatus`）。BLE 没有调风量、没有 Auto 的命令，所以界面上不放这两个按钮 |
| 播放、上一首、下一首、音量 | 已接入，`.media(...)` |
| 曲名、歌手、音量、进度 | 已接入，`MediaState` 和 `MediaDetailState` |
| 播放还是暂停 | 已接入，fork 里的 `MediaState.playbackStatus`。车没上报时，播放键退回成播放和暂停合在一起的图标 |
| 专辑封面 | BLE 不传，显示音符占位 |
| FSD 状态、FSD 目标车速、道路限速 | 公开协议里没有，没有实现 |

这些限制集中写在 `VehicleCapabilities`（`State/VehicleState.swift`）。

## 和设计稿不一样的地方

- **多了一步「输入 VIN」。** 车的蓝牙广播名是 VIN 的哈希，反推不出 VIN，而配对和连接都要用 VIN。选车之后要输入一次 VIN。输入后会校验：这个 VIN 算出来的广播名，必须和刚才选的那辆车对得上。
- **选车列表只显示信号远近**（很近、附近、稍远、很远）。设计稿里写的是「About 10 m away」，但蓝牙信号强度估不准距离，所以不写米数。
- **车在睡眠时连不上。** 库的 `connect()` 会一次握手 VCSEC 和 Infotainment 两个域。车睡着时 Infotainment 不回应，整个连接就失败，也就没有机会先发唤醒命令。实际表现是：人上车、开门把车叫醒以后，Vela 下一轮重试就能连上。

## 验证情况

**已经 build 通过：**
- Debug 和 Release，iPhone 17 Pro Max 模拟器
- 真机 target，用 Team `S4BS47942Q` 自动签名

**模拟器里看过的界面**（DEBUG 下带 `-VelaFixtures driving|parked|connecting|lost [music|climate|settings]` 启动，带 `-VelaLandscape` 转成横屏）：
- 仪表盘：竖屏和横屏，深色和浅色，连接中，连接断开
- Now Playing、Climate、Settings
- 设置流程：从欢迎页一直走到「Confirm in your car」

**必须用真车真机验证的：**
- 首次配对：addKey 发出去以后，刷卡、在中控屏上确认，最后进到「You're all set」
- 重新打开 App 能自动连上，4 Hz 车速刷新的实际延迟
- 空调和音乐各个命令在车上真的生效
- 车走远、蓝牙关掉、车睡着再醒来，各种情况下的重连
- 切到后台再回来，20 秒以内和超过 20 秒两种情况
- 附近车辆扫描，以及 VIN 和广播名的匹配
