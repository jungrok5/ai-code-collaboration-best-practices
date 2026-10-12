#!/usr/bin/env bash
# Publish the native draw.io editor bundled by Next AI Draw.io without committing vendor assets.
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1
out=${1:-_site/assets}
version=0.4.1
pkg=${DRAWIO_PACKAGE_DIR:-.cache/next-ai-drawio-$version/package}
if [ ! -d "$pkg/dist/drawio" ]; then
  cache=".cache/next-ai-drawio-$version"
  mkdir -p "$cache/package"
  packed=$(npm pack "@next-ai-drawio/mcp-server@$version" --pack-destination "$cache" --json)
  filename=$(printf '%s' "$packed" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["filename"])')
  tar -xzf "$cache/$filename" --strip-components=1 -C "$cache/package"
fi
actual=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$pkg/package.json")
if [ "$actual" != "$version" ]; then echo "Expected Next AI Draw.io $version, got $actual" >&2; exit 1; fi
mkdir -p "$out"
cp -R "$pkg/dist/drawio" "$out/drawio"
echo "Prepared Next AI Draw.io $version editor in $out/drawio"
