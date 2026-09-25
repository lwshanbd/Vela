# 本地化 / Localization

Vela 支持英文（开发语言）和简体中文（`zh-Hans`），由 iOS 选择应用语言。
iOS 按应用语言设置及系统首选语言顺序，在英文和简体中文中选择匹配语言。
用户也可以在 iOS 的 Vela 应用设置中选择语言。
其他语言遵循系统语言匹配规则，最终回退到英文。语言变更由系统重新启动应用后生效。

## 资源与约定

- `Vela/Resources/Localizable.xcstrings`：页面、状态提示、错误消息、动态文本和 VoiceOver 文案。
- `Vela/Resources/{en,zh-Hans}.lproj/InfoPlist.strings`：系统蓝牙权限说明。
- 使用 `String(localized:)` 在文案产生处完成本地化，自定义组件接收已经翻译的 `String`。
- 动态句子使用带插值的完整词条。数量使用整数插值，英文按需要提供 `one` / `other` 复数形式。
- 品牌、车辆上报的歌曲/地名、数值及不含语言的组合不翻译；字符串目录中以 `shouldTranslate: false` 标记无需翻译的提取项。
- 不翻译 VIN、蓝牙广播名、协议数据、日志分类、UserDefaults 键或持久化枚举原始值。
- 语言和地区分开处理：小数格式遵循 `Locale.current`；速度及胎压单位保留用户选择，首次使用按地区初始化。温度延续现有规则，英里/时对应华氏度，公里/时对应摄氏度。
- `project.yml` 是工程配置源。XcodeGen 从 `.lproj` 目录推导支持语言；启用 `SWIFT_EMIT_LOC_STRINGS` 供编译器提取词条。

## 验证

资源检查：

```sh
python3 scripts/check_localization.py
```

构建及编译器提取覆盖检查：

```sh
xcodegen generate
xcodebuild -project Vela.xcodeproj -scheme Vela \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/VelaLocalizationBuild CODE_SIGNING_ALLOWED=NO build
python3 scripts/check_localization.py \
  --stringsdata /tmp/VelaLocalizationBuild/Build/Intermediates.noindex/Vela.build/Debug-iphonesimulator/Vela.build/Objects-normal/arm64
```

模拟器通过 Debug 预置数据检查各页面，无需真实车辆：

```sh
xcrun simctl launch --terminate-running-process booted com.baodi.vela \
  -VelaFixtures parked settings -AppleLanguages '(zh-Hans)' -AppleLocale zh_CN
```

将页面参数改为 `climate`、`controls`、`chargers`、`vehicle`、`music` 或 `charging`；
充电状态使用 `-VelaFixtures charging charging`。加上 `-VelaLandscape` 检查横屏。
使用 `-AppleLanguages '(en)' -AppleLocale en_US` 检查英文，
使用 `-AppleLanguages '(fr)' -AppleLocale fr_FR` 检查不支持语言的英文回退。
系统蓝牙授权和真实车辆配对仍需要真机及车辆验证。
