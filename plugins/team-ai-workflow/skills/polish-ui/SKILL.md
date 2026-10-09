---
name: polish-ui
description: Remove the generic AI look from web UI and make it fit the product — landing pages, developer/API docs sites, SaaS dashboards — and meet the team's accessibility and Korean typography floor. Use whenever you build, restyle or review HTML/CSS/Tailwind/JSX/TSX/Vue/Svelte UI, or when asked to 디자인 다듬기, AI 티 빼기, polish the UI, make it look less generic, or review a page.
paths:
  - "**/*.html"
  - "**/*.css"
  - "**/*.scss"
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.vue"
  - "**/*.svelte"
  - "**/*.astro"
---

# Polish UI

The team standard is `docs/17-writing-and-design-standards.md`. A deterministic check runs after every edit and
reports the mechanical tells (purple gradients, gradient text, emoji icons, disabled zoom…). This skill is the part
that needs judgment. Copy on the page follows `polish-writing`.

## 1. Start from the product, not a template

- Name the page's one job (Redis-like product page: show what it does with a real command and a real number; API docs:
  get a developer to a working call; dashboard: let a user read a result and act on it).
- Use the product's own material as the visual: a code sample, a live console, a real result screen, a diagram of
  how it works. Not 3D blobs, stock gradients or a generic hero.
- Reuse the repo's design tokens (colors, type, spacing, radius). If none exist, define a small set first and use
  only those. One accent color, used for actions and state, not decoration.

## 2. Avoid the defaults that read as generated

Centered hero + gradient + two CTAs + logo marquee + three identical feature cards with icon tiles; purple/indigo
gradients and glows; gradient-filled headline words; glass blur as decoration; `rounded-2xl` and the same soft
shadow on everything; ALL-CAPS eyebrow labels over every heading; `01 / 02 / 03` markers on things that are not steps;
`→` on every link; emoji as icons; fade-up animation on every section; invented testimonials, logos or "10,000+ teams".
Each is fine once, for a reason. Banning one default is not enough: do not swap it for the next default — decide
from the content.

## 3. Layout and type

- Layout follows content: tables for comparisons and specs, code next to its explanation, steps only for sequences.
- Korean text: `lang="ko"`, `word-break: keep-all` with `overflow-wrap: anywhere` for long URLs and code,
  body line-height about 1.6–1.8, Pretendard or the system stack (`-apple-system, "Apple SD Gothic Neo",
  "Malgun Gothic", sans-serif`). Numbers in tables: `font-variant-numeric: tabular-nums`.
- Sentence-case headings. Spend boldness in one place per page.

## 4. Quality floor (not optional)

- Contrast 4.5:1 for body text, 3:1 for large text, UI components and focus rings (WCAG 2.2 SC 1.4.3, 1.4.11).
- Visible `:focus-visible` on everything interactive; never `outline: none` without a replacement.
- Targets 44 px (24 px absolute minimum, WCAG 2.2 SC 2.5.8); pinch zoom allowed.
- Respect `prefers-reduced-motion`; motion only where it explains a change (150–250 ms ease-out).
- Responsive at 375, 768, 1024 and 1440 px; light and dark themes both legible (`color-scheme`).
- Images have `width`/`height` and real `alt`; icon-only buttons have `aria-label`.

## 5. Verify

Render the page (Playwright is available: `executablePath` from `PLAYWRIGHT_BROWSERS_PATH`) at mobile and desktop
widths, look at the screenshots, and fix what looks generic or broken before you say it is done. Report what you
checked and what you could not.

Sources and licenses: `THIRD_PARTY_NOTICES.md` in this plugin.
