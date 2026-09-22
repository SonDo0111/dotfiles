#!/usr/bin/env bash
# tex-get — Install a CTAN package into TEXMFHOME
# Usage: tex-get <ctan-package-name>

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <ctan-package-name>" >&2
  exit 1
}

[[ $# -eq 1 ]] || usage
pkg="$1"

texmfhome=$(kpsewhich -var-value TEXMFHOME)
[[ -n "$texmfhome" ]] || { echo "Error: kpsewhich could not resolve TEXMFHOME" >&2; exit 1; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "==> Querying CTAN for '$pkg'..."
json=$(curl -fsSL "https://ctan.org/json/2.0/pkg/${pkg}") || {
  echo "Error: package '$pkg' not found on CTAN." >&2
  exit 1
}

ctan_path=$(jq -r '.ctan.path // empty' <<<"$json")
[[ -n "$ctan_path" ]] || {
  echo "Error: could not resolve CTAN path for '$pkg'." >&2
  exit 1
}

tds_url="https://mirrors.ctan.org/install${ctan_path}.tds.zip"
echo "==> Trying TDS archive: $tds_url"

if curl -fsSL -o "$tmpdir/pkg.tds.zip" "$tds_url" 2>/dev/null; then
  echo "==> TDS archive found — installing into $texmfhome"
  unzip -oq "$tmpdir/pkg.tds.zip" -d "$texmfhome"
else
  echo "==> No .tds.zip available — falling back to source zip + heuristic sort"

  src_url="https://mirrors.ctan.org${ctan_path}.zip"
  echo "==> Fetching $src_url"
  curl -fsSL -o "$tmpdir/pkg.zip" "$src_url" || {
    echo "Error: could not download source zip either. Check manually: https://mirrors.ctan.org${ctan_path}" >&2
    exit 1
  }

  mkdir -p "$tmpdir/extract"
  unzip -oq "$tmpdir/pkg.zip" -d "$tmpdir/extract"

  echo "==> Sorting files by extension into TDS layout (best-effort)"
  declare -A dest=(
    [sty]="tex/latex/$pkg" [cls]="tex/latex/$pkg" [clo]="tex/latex/$pkg"
    [def]="tex/latex/$pkg" [lua]="tex/latex/$pkg" [fd]="tex/latex/$pkg"
    [cfg]="tex/latex/$pkg"
    [otf]="fonts/opentype/public/$pkg"
    [ttf]="fonts/truetype/public/$pkg"
    [pfb]="fonts/type1/public/$pkg"
    [tfm]="fonts/tfm/public/$pkg"
    [vf]="fonts/vf/public/$pkg"
    [enc]="fonts/enc/dvips/$pkg"
    [map]="fonts/map/dvips/$pkg"
    [mf]="fonts/source/public/$pkg"
    [pdf]="doc/$pkg" [txt]="doc/$pkg" [md]="doc/$pkg"
  )

  for ext in "${!dest[@]}"; do
    while IFS= read -r -d '' f; do
      mkdir -p "$texmfhome/${dest[$ext]}"
      cp "$f" "$texmfhome/${dest[$ext]}/"
    done < <(find "$tmpdir/extract" -iname "*.${ext}" -print0)
  done

  echo "==> WARNING: heuristic sort — verify with 'kpsewhich' and check"
  echo "    $tmpdir/extract for anything unmatched (e.g. README, INSTALL,"
  echo "    non-standard subdirs) before it gets cleaned up."
  read -rp "Press Enter to clean up tmp dir, or Ctrl+C to inspect first..."
fi

echo "==> Refreshing filename database"
mktexlsr "$texmfhome"

echo "==> Verifying"
if kpsewhich "${pkg}.sty" >/dev/null 2>&1; then
  echo "OK: $(kpsewhich "${pkg}.sty")"
else
  echo "No ${pkg}.sty found directly — may be font-only, differently named, or needs manual check."
fi
