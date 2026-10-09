#!/bin/sh
set -eu
# Pinned official release; no key generation, signing or account access.
VERSION=2.10.0
SHA256=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
CACHE="${USAGE_TOPBAR_DEPENDENCY_CACHE:-${TMPDIR:-/private/tmp}/usage-topbar-dependencies}"
ARCHIVE="$CACHE/Sparkle-$VERSION.tar.xz"
DEST="$CACHE/Sparkle-$VERSION"
mkdir -p "$CACHE"
if [ ! -f "$ARCHIVE" ]; then
  curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 \
    "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz" -o "$ARCHIVE.download"
  mv "$ARCHIVE.download" "$ARCHIVE"
fi
printf '%s  %s\n' "$SHA256" "$ARCHIVE" | shasum -a 256 -c - >&2
if [ ! -d "$DEST/Sparkle.framework" ]; then
  mkdir -p "$DEST"
  tar -xf "$ARCHIVE" -C "$DEST"
fi
codesign --verify --deep --strict "$DEST/Sparkle.framework"
printf '%s\n' "$DEST"
