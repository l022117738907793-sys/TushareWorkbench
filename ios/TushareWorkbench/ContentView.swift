import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.loading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在加载演示快照…")
                        .foregroundStyle(Palette.muted)
                }
            } else if let error = model.errorText {
                VStack(spacing: 12) {
                    Text(error).foregroundStyle(.orange)
                    Button("重试") { model.load() }
                        .buttonStyle(.bordered)
                }
            } else {
                TabView(selection: $model.selectedTab) {
                    WorkbenchView()
                        .tabItem { Label("工作台", systemImage: "funnel") }
                        .tag(AppTab.workbench)
                    AnalysisView()
                        .tabItem { Label("个股分析", systemImage: "chart.line.uptrend.xyaxis") }
                        .tag(AppTab.analysis)
                    HistoryView()
                        .tabItem { Label("学习记录", systemImage: "book") }
                        .tag(AppTab.history)
                    SettingsView()
                        .tabItem { Label("设置", systemImage: "gearshape") }
                        .tag(AppTab.settings)
                }
            }
        }
        .tint(Palette.accent)
        .onAppear {
            if model.snapshot == nil {
                model.load()
            }
        }
    }
}
