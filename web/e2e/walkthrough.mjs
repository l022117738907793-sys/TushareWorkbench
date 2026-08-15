import { chromium } from "playwright";

const base = process.env.BASE_URL || "http://localhost:4173";
const browser = await chromium.launch();
const page = await browser.newPage({
  viewport: { width: 430, height: 900 },
  deviceScaleFactor: 2,
});
const errors = [];
page.on("console", (msg) => {
  if (msg.type() === "error") errors.push(msg.text());
});
page.on("pageerror", (err) => errors.push(String(err)));

await page.goto(base, { waitUntil: "networkidle" });
await page.getByText("第一层 · 大盘环境").waitFor({ timeout: 20000 });
await page.screenshot({ path: "/tmp/web_workbench.png" });
console.log("workbench ok");

// 展开第一个板块
await page.locator(".sector-row").first().click();
await page.locator(".stock-row").first().waitFor({ timeout: 10000 });
await page.screenshot({ path: "/tmp/web_sector.png" });
console.log("sector expanded ok");

// 进入个股分析
await page.locator(".stock-row").first().click();
await page.getByText("【市场环境】").waitFor({ timeout: 10000 });
await page.screenshot({ path: "/tmp/web_analysis.png" });
const bodyText = await page.locator("body").innerText();
for (const bad of ["买入", "卖出", "目标价", "必涨", "必跌"]) {
  if (bodyText.includes(bad)) {
    throw new Error(`页面出现禁用词: ${bad}`);
  }
}
console.log("analysis ok, no forbidden words");

// 设置页
await page.getByRole("button", { name: "设置", exact: true }).click();
await page.getByText("阈值 · 大盘环境").waitFor({ timeout: 5000 });
await page.screenshot({ path: "/tmp/web_settings.png" });
console.log("settings ok");

if (errors.length) {
  console.log("console errors:", errors.slice(0, 5));
}
await browser.close();
