#!/usr/bin/env bash
# Build docs/site/index.html (standalone page for GitHub Pages) from docs/site/guide.body.html and the team
# design system "Clear" (tokens.css + components.css + theme.js + copy.js, inlined so the page is one file).
# The same build is published as the claude.ai Artifact.
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1
body=docs/site/guide.body.html
design=plugins/team-ai-workflow/skills/polish-ui/design
out=docs/site/index.html
{
  printf '<!doctype html>\n<html lang="ko">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
  printf '<style>\n'; cat "$design/tokens.css" "$design/components.css"; printf '</style>\n'
  printf '<script>\n'; cat "$design/theme.js"; printf '</script>\n'
  # <title>, font links and the page <style> come first in the body file
  sed -n '1,/<\/style>/p' "$body"
  printf '</head>\n<body>\n'
  sed -n '/<\/style>/,$p' "$body" | tail -n +2
  printf '<script>\n'; cat "$design/copy.js"; printf '</script>\n'
  printf '<script src="https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js"></script>\n'
  # Mermaid colors come from the design tokens, so diagrams follow the light/dark theme of the page.
  cat <<'JS'
<script>
(() => {
  const nodes = [...document.querySelectorAll("pre.mermaid")];
  nodes.forEach((n) => { n.dataset.src = n.textContent; });
  const draw = () => {
    const css = getComputedStyle(document.documentElement), v = (n) => css.getPropertyValue(n).trim();
    mermaid.initialize({startOnLoad: false, theme: "base", themeVariables: {
      darkMode: window.clearTheme.isDark(), fontFamily: v("--font-sans"), fontSize: "15px",
      background: v("--bg"), textColor: v("--fg"), lineColor: v("--subtle"),
      primaryColor: v("--accent-soft"), primaryBorderColor: v("--accent"), primaryTextColor: v("--fg"),
      secondaryColor: v("--sunk"), tertiaryColor: v("--surface"), mainBkg: v("--accent-soft"), nodeBorder: v("--accent"),
      clusterBkg: v("--surface"), clusterBorder: v("--line-strong"), edgeLabelBackground: v("--bg"),
      actorBkg: v("--accent-soft"), actorBorder: v("--accent"), actorTextColor: v("--fg"), actorLineColor: v("--line-strong"),
      signalColor: v("--fg"), signalTextColor: v("--fg"), labelBoxBkgColor: v("--sunk"), labelBoxBorderColor: v("--line-strong"),
      labelTextColor: v("--fg"), loopTextColor: v("--fg"), noteBkgColor: v("--sunk"), noteTextColor: v("--fg"),
      noteBorderColor: v("--line-strong"), sequenceNumberColor: v("--accent-fg")
    }});
    nodes.forEach((n) => { n.removeAttribute("data-processed"); n.textContent = n.dataset.src; });
    mermaid.run({nodes});
  };
  draw();
  document.addEventListener("themechange", draw);
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => { if (!document.documentElement.dataset.theme) draw(); });
})();
</script>
JS
  printf '</body>\n</html>\n'
} > "$out"
echo "wrote $out"
