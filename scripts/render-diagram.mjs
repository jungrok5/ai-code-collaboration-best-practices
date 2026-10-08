// Render docs/images/architecture.html to docs/images/architecture.png (2x) with Playwright Chromium.
// Usage: node scripts/render-diagram.mjs   (needs playwright; set CHROMIUM_PATH to use an existing Chromium)
// Korean text needs a CJK font installed (e.g. fonts-noto-cjk).
import { chromium } from "playwright";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const src = path.join(root, "docs/images/architecture.html");
const out = path.join(root, "docs/images/architecture.png");
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
const page = await browser.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 2 });
await page.goto("file://" + src);
await page.screenshot({ path: out, fullPage: true });
await browser.close();
console.log("wrote", path.relative(root, out));
