#!/bin/sh
set -eu

bin=$(pwd)/isoextract
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/input/sub/empty"
printf 'hello from isoextract\n' > "$tmp/input/readme.txt"
printf 'nested file\n' > "$tmp/input/sub/nested.txt"
# libmirage rejects ISO images smaller than its minimum track length.
dd if=/dev/zero of="$tmp/input/sub/large.bin" bs=2048 count=512 2>/dev/null
xorriso -as mkisofs -quiet -R -J -o "$tmp/test.iso" "$tmp/input"

"$bin" -h > "$tmp/help"
"$bin" -l -v --sz-human-readable -i "$tmp/test.iso" > "$tmp/list"
grep -F '/sub/nested.txt' "$tmp/list"
"$bin" -i "$tmp/test.iso" -o "$tmp/all" > "$tmp/log"
diff -r "$tmp/input" "$tmp/all"
"$bin" --absolute -i "$tmp/test.iso" -o "$tmp/absolute" > "$tmp/log"
diff -r "$tmp/input" "$tmp/absolute"
"$bin" -i "$tmp/test.iso" -o "$tmp/wildcard" 'sub/*.txt' > "$tmp/log"
cmp "$tmp/input/sub/nested.txt" "$tmp/wildcard/sub/nested.txt"
test ! -e "$tmp/wildcard/sub/large.bin"
"$bin" -r -i "$tmp/test.iso" -o "$tmp/recursive" '/sub' > "$tmp/log"
diff -r "$tmp/input/sub" "$tmp/recursive/sub"

if ! grep -q 'DISABLED AT COMPILE TIME' "$tmp/help"; then
    "$bin" -P -i "$tmp/test.iso" -o "$tmp/regex" '(nested)\.(txt)$' > "$tmp/log"
    cmp "$tmp/input/sub/nested.txt" "$tmp/regex/sub/nested.txt"
    test ! -e "$tmp/regex/readme.txt"
    # A later invalid pattern must not crash cleanup of earlier patterns.
    if "$bin" -l -P -i "$tmp/test.iso" 'valid' '[' > "$tmp/log" 2>&1; then
        echo 'invalid regex unexpectedly succeeded' >&2
        exit 1
    fi
fi

# Exercise libmirage's multi-file CUE parser with MODE1/2048 data.
cp "$tmp/test.iso" "$tmp/test.bin"
printf 'FILE "test.bin" BINARY\n  TRACK 01 MODE1/2048\n    INDEX 01 00:00:00\n' > "$tmp/test.cue"
"$bin" -i "$tmp/test.cue" -o "$tmp/cue" > "$tmp/log"
diff -r "$tmp/input" "$tmp/cue"
if "$bin" -l -i "$tmp/missing.iso" > "$tmp/log" 2>&1; then
    echo 'missing image unexpectedly succeeded' >&2
    exit 1
fi
echo 'Integration tests passed'
