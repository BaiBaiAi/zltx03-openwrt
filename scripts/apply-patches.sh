#!/bin/bash
# 顺序应用 SY108 的 OpenWrt 补丁（先统一转 LF）并报告结果
cd /build/openwrt || exit 1
SERIES=/build/sy108/integration/openwrt/series
PATCHDIR=/build/sy108/integration/openwrt/patches
TMPP=/tmp/patches
rm -rf $TMPP && mkdir -p $TMPP
for f in $PATCHDIR/*.patch; do
  tr -d '\r' < "$f" > "$TMPP/$(basename "$f")"
done

while IFS= read -r name; do
  name=$(printf '%s' "$name" | tr -d '\r')
  [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  if git apply --reverse --check "$TMPP/$name" 2>/dev/null; then
    echo "[skip ] $name (already applied)"
    continue
  fi
  if git apply "$TMPP/$name" 2>/tmp/patch.err; then
    echo "[ OK  ] $name"
  else
    echo "[FAIL ] $name"
    sed 's/^/        /' /tmp/patch.err | head -8
  fi
done < "$SERIES"

echo "--- kernel-version 检查 ---"
grep -n 'PLATFORM_DIR)/kernel-' include/kernel-version.mk | head -4 || echo "未打上"
