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
- Team `S4BS47942Q`，自动签名，Bundle ID `com.baodi.vela`
- 依赖我们 fork 的 [swift-tesla-ble](https://github.com/lwshanbd/swift-tesla-ble)，SPM 锁定在 `d07fcac`。原库在 [shoujiaxin/swift-tesla-ble](https://github.com/shoujiaxin/swift-tesla-ble)。fork 补上了原库丢掉的字段：GPS 位置和朝向、播放状态、更多的充电、空调、车身和软件更新状态。车没上报的字段一律是 nil，不会变成 0。

## 结构

```
Vela/
  App/         入口。AppModel 挂在 App 上，不挂在任何 View 上
  Vehicle/     Tesla BLE 层，只有这里 import TeslaBLE
    VehicleConnection   连接、握手、轮询、断线重连、睡眠识别、发命令、查超充站
    PairingSession      首次配对：addKey，然后等车主在车上确认
    NearbyTeslaScanner  设置流程里列出附近的 Tesla
    VehicleIdentity     VIN、车型名、Keychain 私钥
  State/       AppModel、AppSettings、DashboardConfig、VehicleState、NetworkMonitor
               把车辆数据转成界面要显示的值，把用户操作转成命令
  UI/
    Components/  图标（直接解析设计稿的 SVG 路径）、按钮、开关、分段控件
    Dashboard/   DashboardLayout 按屏幕尺寸选布局，模块按列表顺序排，放不下就不放
    Pages/       Now Playing、Climate、Controls、Superchargers、Vehicle、Charging、
                 Settings（含 Dashboard 模块设置、Speed display）
    Onboarding/  欢迎、搜索、选车、输入 VIN、配对、配对失败
  Preview/     SwiftUI Preview 和 DEBUG 启动参数用的假数据，只在 DEBUG 编译
```

## 仪表盘

- 行驶中和停车时（P 档且车速为 0）是两种布局。停车时车速变小，多出车辆面板（锁、开着的门窗、胎压、软件更新），以及 Controls 和 Chargers 两个入口。
- 可选模块：功率、续航、车内外温度、朝向、导航、地图、空调、媒体。竖屏和横屏各有一份顺序和开关，在 Settings › Dashboard 里改。
- 按列表顺序往下排，放不下的模块就不显示，设置页标出「No room」。
- 车没上报的数据，对应模块直接不出现，不画空状态。
- 布局只看屏幕尺寸：短边小于 460 pt 是 iPhone，460 到 600 pt 是 iPhone Duo 外屏，更大是 Duo 内屏。

## 数据刷新

- 车速、档位、功率、导航用 `fetchDrive()`。请求一个接一个发，最快 4 Hz。挂 P 档时降到 1 Hz。
- 电量、充电、空调、媒体、车门车窗、胎压合成一个 `fetch(.categories(...))` 请求，每 5 秒一次；打开详情页时 2 秒一次。开了地图或朝向模块才请求位置，停车时才请求软件更新状态。
- 发完命令立刻再拉一次状态，界面显示的是车实际生效的值。温度和座椅加热会先显示你点的值，等车确认。
- 超充站只在打开 Superchargers 页或点刷新时向车查询。

## 连接生命周期

- `VehicleConnection` 的生命周期跟着 App 走，旋转屏幕、View 重建都碰不到它。
- 断线后自动重连，退避间隔 1、2、4、8、10 秒。车速连续 4 次请求失败，就当作断线处理。
- 握手失败时，用不需要签名的车身状态查询问一下车是不是在睡眠。是的话显示「Model Y is asleep」，继续重试，开门后就能连上。
- 进后台先保持 20 秒，超过 20 秒就断开，免得一直把车吵醒。回到前台自动重连。
- 屏幕常亮只在一处设置（`RootView`）：设置里打开了、App 在前台、在仪表盘上、车已连接或正在重连。

## Tesla BLE 实际能做什么

依赖我们 fork 的 swift-tesla-ble。它把原库丢掉的字段都接上了，并且让车身状态查询不需要签名。对照的是 Tesla vehicle-command 的 protobuf。

能读能控的：车速、档位、功率、导航、位置和朝向、电量、续航、充电、空调、座椅加热和通风、方向盘加热、除雾、保持空调模式、过热保护、生化防御、媒体（包括播放状态、音源、音量）、车门车窗天窗、锁、哨兵、胎压、软件更新、附近超充站。

控制不了或读不到的：

| 功能 | 原因 |
| --- | --- |
| 风量、风量 Auto | 只能读，BLE 没有设置命令 |
| 关前备箱 | BLE 只能打开 |
| 专辑封面 | BLE 不传 |
| FSD、Autopilot、道路限速、转向提示 | 公开协议里没有 |
| 叫醒睡着的车 | 需要完整会话，而睡着时建不起会话 |

这些限制集中写在 `VehicleCapabilities`（`State/VehicleState.swift`）。

## 和设计稿不一样的地方

- **过热保护的触发温度**写的是 Low / Medium / High。设计稿写的是 90° / 100° / 105°，但车只报这三档，不报具体温度。
- **前备箱开着时没有「关」按钮**，只显示状态。
- **Dashboard 设置页的预览**用车当前的数据。还没有数据的模块显示成空面板加「–」，不填示例数字。
- **iPhone Duo 的折叠区和外屏摄像头避让**没有做。设计稿提到的 `ArrangementView`、`ReservedRegion` 在 iOS 27 SDK 里不是公开 API。Duo 的布局按屏幕尺寸选。
- **选车列表只显示信号强弱分档**，不写距离米数。

## 验证情况

**build：**iPhone 17 Pro Max 模拟器 Debug 通过，Vela 自己的代码没有 warning。

**模拟器里看过的界面**（DEBUG 下带 `-VelaFixtures driving|full|parked|charging|asleep|connecting|lost|btoff|noperm [music|climate|settings|controls|chargers|vehicle|charging]` 启动，`-VelaAllModules` 打开全部模块，`-VelaLandscape` 转成横屏）：
- 仪表盘：行驶、全模块加告警、停车、睡眠；横屏行驶和停车
- Climate、Controls、Superchargers、Vehicle、Charging、Now Playing、Settings、Dashboard 设置

**还没看过：**iPhone Duo 模拟器启动后是黑屏，Duo 布局没有看到实际效果。

**必须用真车真机验证的：**
- 首次配对，以及之后自动重连
- 睡眠识别：车睡着时是否显示「asleep」，开门后能否连上
- 所有控制命令：锁、前后备箱、车窗、哨兵、天窗、充电口、车库门、鸣笛、闪灯、座椅、方向盘、除雾、保持空调、过热保护
- 超充站查询、导航和位置数据、胎压和车门状态
- 4 Hz 车速刷新的实际延迟
