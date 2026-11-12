#!/bin/bash
# ZLT X03 / SXL-D01 (UDX710 4h10) OpenWrt 构建准备脚本
# 在 WSL Ubuntu 内以 root 运行
set -e

BUILD=/build
OW=$BUILD/openwrt
SY=$BUILD/sy108
KERNEL=$BUILD/kernel

echo "== 1. 复制 SY108 集成树 =="
rm -rf "$SY"
cp -r /mnt/c/Users/Administrator/Downloads/spd/owrt/sy108-mainline "$SY"
rm -rf "$SY/.git"
echo "   -> $SY"

echo "== 2. 复制 target/linux/sprd =="
mkdir -p "$OW/target/linux"
rm -rf "$OW/target/linux/sprd"
cp -r "$SY/integration/openwrt/target/linux/sprd" "$OW/target/linux/sprd"
echo "   -> $OW/target/linux/sprd"

echo "== 3. 应用 OpenWrt 补丁 =="
cd "$OW"
if [ ! -d .git ]; then
  git init -q .
  git add -A >/dev/null 2>&1
  git -c user.email=b@b -c user.name=b commit -qm base
fi
while read -r name; do
  [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac
  p="$SY/integration/openwrt/patches/$name"
  if git apply --reverse --check "$p" 2>/dev/null; then
    echo "   skip (already applied): $name"
  else
    git apply "$p" && echo "   applied: $name"
  fi
done < <(tr -d '\r' < "$SY/integration/openwrt/series")

echo "== 4. feeds.conf =="
cp "$SY/integration/openwrt/feeds.conf" "$OW/feeds.conf"
echo "src-link sy108 $SY/packages" >> "$OW/feeds.conf"
cat "$OW/feeds.conf"

echo "== 5. 生成内核源码归档 =="
if [ ! -f "$KERNEL/Makefile" ]; then
  echo "   SKIP: 内核源码尚未就绪 ($KERNEL)"
  echo "== DONE (partial) =="
  exit 0
fi
cd "$KERNEL"
VER=$(python3 -c "import json;print(json.load(open('$SY/manifests/kernel.json'))['version'])")
SERIES=$(echo "$VER" | cut -d. -f1,2)
ARCH_NAME="linux-${VER}-sy108-14658d97220a.tar.gz"
mkdir -p "$OW/dl"
if [ ! -f "$OW/dl/$ARCH_NAME" ]; then
  git -C "$KERNEL" archive --format=tar --prefix="linux-${VER}/" HEAD | gzip -n > "$OW/dl/$ARCH_NAME"
fi
HASH=$(sha256sum "$OW/dl/$ARCH_NAME" | cut -d' ' -f1)
printf 'LINUX_VERSION-%s = %s\nLINUX_KERNEL_HASH-%s = %s\n' "$SERIES" "${VER#$SERIES}" "$VER" "$HASH" \
  > "$OW/target/linux/sprd/kernel-$SERIES"
echo "   archive=$ARCH_NAME size=$(du -h "$OW/dl/$ARCH_NAME" | cut -f1)"
echo "   hash=$HASH"

echo "== 6. feeds update/install =="
cd "$OW"
./scripts/feeds update -a
./scripts/feeds install -a

echo "== DONE =="
