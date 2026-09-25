# Vela

把 iPhone 变成 Tesla 的副屏。

手机放在车里的支架上，通过蓝牙直接连车，显示车速、档位、电量，也能控制空调和音乐。不走网络，不需要登录 Tesla 账号。

## 功能

- 仪表盘：车速、档位、功率、续航、电量。行驶和停车各有一套布局。
- 可选模块：车内外温度、朝向、导航、地图、空调、媒体。竖屏和横屏分别设置顺序和开关。
- 空调：温度、座椅加热和通风、方向盘加热、除雾、保持空调模式、过热保护、生化防御。
- 车辆控制：锁车、前后备箱、车窗、天窗、哨兵、充电口。
- 状态查看：车门车窗、胎压、充电、软件更新。
- 附近超充站。
- 车睡着时会提示，开车门之后自动连上。

## 要求

- iPhone，iOS 17 或更高
- 支持蓝牙钥匙的 Tesla
- 第一次使用要在车上确认，把手机加为钥匙

## 构建

工程文件由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成。

```bash
brew install xcodegen
```

```bash
xcodegen generate
```

```bash
open Vela.xcodeproj
```

在 Xcode 里把 Signing 的 Team 换成你自己的，Bundle ID 也改成你自己的，然后装到手机上。

## 致谢

蓝牙通信用的是 [swift-tesla-ble](https://github.com/shoujiaxin/swift-tesla-ble)。本项目依赖的是一个 [fork](https://github.com/lwshanbd/swift-tesla-ble)，补上了位置、媒体播放状态等原库没有解析的字段。
