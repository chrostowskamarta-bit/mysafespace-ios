#!/usr/bin/env bash
# Generates Asset Catalog colour sets (light + dark) for the MySafeSpace design tokens.
# Usage: bash scripts/make_colorsets.sh   (run from the repo root)
set -euo pipefail
ASSETS="MySafeSpace/Resources/Assets.xcassets"
mkdir -p "$ASSETS"

cat > "$ASSETS/Contents.json" <<'EOF'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

component() { printf '0x%s' "${1:$2:2}"; }

entry() { # $1 hex (no #), $2 appearance json or empty
  local hex=$1
  local r g b
  r=$(component "$hex" 0); g=$(component "$hex" 2); b=$(component "$hex" 4)
  local appearance=""
  if [ "$2" = "dark" ]; then
    appearance='"appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],'
  fi
  cat <<EOF
    {
      $appearance
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "$b", "green" : "$g", "red" : "$r" }
      },
      "idiom" : "universal"
    }
EOF
}

colorset() { # name light dark
  local dir="$ASSETS/$1.colorset"
  mkdir -p "$dir"
  {
    echo '{'
    echo '  "colors" : ['
    entry "$2" light
    echo '    ,'
    entry "$3" dark
    echo '  ],'
    echo '  "info" : { "author" : "xcode", "version" : 1 }'
    echo '}'
  } > "$dir/Contents.json"
}

#        name                light    dark
colorset AccentColor         6C4CF5   9B85FF
colorset brandPrimary        6C4CF5   9B85FF
colorset brandPrimaryStrong  5B3FD9   B3A2FF
colorset brandSecondary      D4F55A   D4F55A
colorset onBrandPrimary      FFFFFF   140F26
colorset onBrandSecondary    1E1636   1E1636
colorset ink                 1E1636   F3F0FF
colorset inkSecondary        544C6B   BDB6D6
colorset background          F9F7F3   120E22
colorset surface             FFFFFF   1E1834
colorset surfaceMuted        ECE8FA   2B2448
colorset crisisBackground    F5F4F8   15131B
colorset moodInk             1E1636   1E1636
colorset mood1               C4D4FF   4E6DC4
colorset mood2               D5C8FF   947CD9
colorset mood3               FFDE8F   CDAF68
colorset mood4               FEBB87   DA8749
colorset mood5               DCFFA0   96C842
colorset callBackground      1E1636   0B0815

echo "Colour sets written to $ASSETS"
