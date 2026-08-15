# 股票趋势筛选工作台（原型）

移动端优先的 A 股趋势筛选工作台，含四层漏斗筛选与「个股分析 + 学习辅助」模块。两个形态共享同一套规则与数据：

- `web/`：Vite + React + TypeScript 交互原型（iPhone 尺寸预览）
- `ios/`：SwiftUI iOS 工程（分析引擎为独立 Swift Package，可 `swift test`）

## 数据

演示快照（真实历史日线，截至 2026-08-14）：

```bash
python3 data/scripts/fetch_snapshot.py     # 生成 data/snapshot_<日期>/
python3 data/scripts/validate_snapshot.py  # 校验快照
python3 data/scripts/generate_fixtures.py  # 生成两端一致性测试 fixture
```

数据来源：申万一级行业指数与成分股（akshare / 申万官网口径）、个股与指数日线（腾讯行情，前复权）、市值（Tushare daily_basic，可用时；不可用时按申万权重排序，meta 中标注）。接口失败时明确标注，不编造数据。

## 快照数据服务

`server/server.py` 是一个轻量数据服务：定时抓取最新快照，供 App 启动时自动下载。

```bash
python3 -u server/server.py \
  --host 127.0.0.1 --port 8787 \
  --interval 1800 --fetch-after 18:00
```

- 工作日 18:00 之后且最新快照日期早于今天时，服务会自动抓取新快照；
- `POST /refresh` 可手动触发立即抓取；
- `GET /latest` 返回最新快照元信息，`GET /snapshots/<快照名>/<文件>` 返回快照文件；
- 需要局域网访问时把 `--host` 改为 `0.0.0.0`，App 设置里填电脑的局域网地址。

网页端与 iOS 端都在设置里提供「快照服务地址」；填写后应用启动时会自动下载最新快照，服务不可用时回退到内置快照并提示原因。

## 网页原型

```bash
cd web
npm install
npm run build
npm run preview -- --host 127.0.0.1   # 打开 http://127.0.0.1:4173
```

测试与走查：

```bash
npm test                                  # Vitest：引擎 vs 12 个 fixture
npx playwright install chromium           # 首次
node e2e/walkthrough.mjs                  # 四页走查 + 截图（BASE_URL 可覆盖）
```

## iOS 工程

需要 Xcode 16+（本仓库用 Xcode 26.6 / iOS 26.5 模拟器验证）。

> 注意：若在桌面代理/自动化环境里用命令行构建，系统会给构建产物自动添加
> `com.apple.provenance` 属性，`codesign` 可能报
> “resource fork, Finder information, or similar detritus not allowed”。
> 这种情况请直接用 Xcode 图形界面打开工程运行（Xcode 进程生成的文件不受影响），
> 或把仓库 clone 到新目录后再构建。不要在项目里设置
> `CODE_SIGNING_ALLOWED: NO`，否则真机将无法签名安装。

```bash
brew install xcodegen
python3 data/scripts/sync_ios_assets.py   # 同步快照与 fixture 到工程
cd ios
xcodegen generate
xcodebuild -project TushareWorkbench.xcodeproj \
  -scheme TushareWorkbench \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
cd TushareWorkbenchCore && swift test      # 核心引擎 macOS 单测
```

模拟器验证：

```bash
xcrun simctl boot "iPhone 17 Pro"
xcrun simctl install <UDID> ios/build/Build/Products/Debug-iphonesimulator/TushareWorkbench.app
xcrun simctl launch <UDID> com.example.TushareWorkbench
```

可用启动参数直达个股分析页：`xcrun simctl launch <UDID> com.example.TushareWorkbench -selectedStock 600519.SH`

## 规则

- `docs/analysis-rules.md`：两端分析引擎的唯一事实来源
- `data/rules.json`：默认阈值（两端内嵌，可在 App 设置中调整）
- `docs/data-format.md`：快照 JSON 格式

规则红线：不出现买卖信号；每个分类必须展示判断依据；数据不足时显示【数据不足，不许编造】；不预测确定走势。
