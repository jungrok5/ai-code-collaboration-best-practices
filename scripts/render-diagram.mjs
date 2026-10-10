// Render the README images from their HTML sources with Playwright Chromium, in light and dark (2x):
//   docs/images/architecture.html → architecture.png, architecture-dark.png
//   docs/images/readme-hero.html  → readme-hero.png,  readme-hero-dark.png
// Usage: node scripts/render-diagram.mjs   (needs playwright; set CHROMIUM_PATH to use an existing Chromium)
// The viewport is short so each PNG is exactly as tall as its content.
// Korean text needs a CJK font installed (e.g. fonts-noto-cjk) if Google Fonts cannot be reached.
import { chromium } from "playwright";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { execFileSync } from "node:child_process";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const images = path.join(root, "docs/images");
// The HTML sources load the design tokens from the pinned ai-design checkout in .cache/.
execFileSync(path.join(root, "scripts/ai-design.sh"), { stdio: ["ignore", "ignore", "inherit"] });
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
const page = await browser.newPage({ viewport: { width: 1600, height: 300 }, deviceScaleFactor: 2 });
for (const name of ["architecture", "readme-hero"]) {
  await page.goto("file://" + path.join(images, `${name}.html`), { waitUntil: "networkidle" });
  await page.evaluate(() => document.fonts.ready);
  for (const theme of ["light", "dark"]) {
    await page.evaluate((t) => { document.documentElement.dataset.theme = t; }, theme);
    const out = path.join(images, theme === "light" ? `${name}.png` : `${name}-dark.png`);
    await page.screenshot({ path: out, fullPage: true });
    console.log("wrote", path.relative(root, out));
  }
}
await browser.close();
