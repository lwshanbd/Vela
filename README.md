# Vela

Vela 让 iPhone 当 Tesla 的副屏用。

手机放在车里的支架上，用蓝牙直接连车。车速、档位、电量一眼就能看到，空调和音乐也能在手机上调。不用联网，也不用登录 Tesla 账号。

## 能做什么

- 看车速、档位、功率、电量和续航。停车以后会多显示车门、车窗和胎压。
- 调空调温度、座椅加热和通风、方向盘加热、除雾。
- 播放暂停、切歌、调音量。
- 锁车，开后备箱、车窗、天窗和充电口，开关哨兵模式。
- 查附近的超充站。
- 仪表盘上放哪些内容可以自己选，竖屏和横屏分开设置。

## 使用条件

你需要一台 iOS 17 以上的 iPhone，和一辆能用手机钥匙的 Tesla。第一次连车时，要在车里的屏幕上点一下确认，把这台手机加成钥匙。

## 从源码构建

工程文件用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成：

```bash
brew install xcodegen
xcodegen generate
open Vela.xcodeproj
```

打开以后，在 Signing 里把 Team 和 Bundle ID 换成你自己的，就能装到手机上。

## 感谢

蓝牙部分基于 [shoujiaxin/swift-tesla-ble](https://github.com/shoujiaxin/swift-tesla-ble)。项目用的是[我 fork 的版本](https://github.com/lwshanbd/swift-tesla-ble)，多读了位置、播放状态这些字段。
