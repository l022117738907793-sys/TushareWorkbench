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

## 发布到 GitHub Pages（让别人直接打开用）

仓库已包含 GitHub Actions 工作流（`.github/workflows/deploy-web.yml`）：

1. 在 GitHub 新建一个公开仓库，把本仓库推上去；
2. 仓库 `Settings → Pages → Source` 选择 **GitHub Actions**；
3. 之后每次 push 到 `main`，网页版会自动构建并部署，链接形如
   `https://<用户名>.github.io/<仓库名>/`，分享给朋友即可。

注意：源码里没有提交任何密钥；Tushare token 只从环境变量读取，公开仓库是安全的。

## 每日自动更新快照（方案 1）

仓库包含定时工作流 `.github/workflows/update-snapshot.yml`：

- 每个工作日 18:30（北京时间）自动抓取最新快照并推送到 `main`；
- 推送会自动触发网页版重新部署，朋友刷新就是最新数据；
- 节假日/周末没有新交易日数据时不会产生提交；
- 可以随时在 `Actions → Update Daily Snapshot → Run workflow` 手动触发一次。

首次使用建议配置 Tushare token（可选，不配置也能抓取，只是市值排序会退化为权重排序）：
仓库 `Settings → Secrets and variables → Actions → New repository secret`，
名称填 `TUSHARE_TOKEN`，值填你的 token。token 只存在于 GitHub 加密存储中，不会出现在仓库里。

## 常见问题

### Xcode 报 “Error opening input file … (Operation timed out)”

如果项目放在 iCloud 同步的目录（例如 `~/Documents`），磁盘空间不足时 macOS 会把文件
“卸载”成云端占位文件（`ls -lO` 会显示 `dataless`），Xcode 读取时就会超时。处理方法：

```bash
python3 scripts/materialize.py   # 强制把整个仓库取回本地
ls -lO ios/TushareWorkbench/TushareWorkbenchApp.swift  # 确认不再显示 dataless
```

然后完全退出 Xcode 重新打开工程即可。长期建议把项目放到非同步目录
（例如 `~/Developer/Tushare`），避免再次被 iCloud 卸载。

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

如果你的 Xcode 是 beta 版（应用名 `Xcode-beta.app`），请用
`open -a Xcode-beta TushareWorkbench.xcodeproj` 打开工程；如需在命令行使用
`xcodebuild`，先执行 `sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer`。

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
