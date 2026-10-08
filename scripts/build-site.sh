#!/usr/bin/env bash
# Build docs/site/index.html (standalone page for GitHub Pages) from docs/site/guide.body.html
# (the same body is published as a claude.ai Artifact, which supplies its own <html>/<head> skeleton).
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1
body=docs/site/guide.body.html
out=docs/site/index.html
{
  printf '<!doctype html>\n<html lang="ko">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
  # <title>, font links and <style> come first in the body file
  sed -n '1,/<\/style>/p' "$body"
  printf '</head>\n<body>\n'
  sed -n '/<\/style>/,$p' "$body" | tail -n +2
  printf '<script src="https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js"></script>\n'
  printf '<script>mermaid.initialize({startOnLoad:true,theme:window.matchMedia("(prefers-color-scheme: dark)").matches?"dark":"default"});</script>\n'
  printf '</body>\n</html>\n'
} > "$out"
echo "wrote $out"
