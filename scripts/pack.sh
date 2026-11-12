#!/bin/bash
# 方案 B：把 OpenWrt 已组装好的根文件系统打包成裸 UBIFS，直接写入 system 分区
# 几何参数全部来自原厂 system.bin 的 UBIFS 超级块，不要改
set -e

OW=/build/openwrt
OUT=/build/out
ROOT=$(find "$OW/build_dir" -maxdepth 2 -type d -name 'root-sprd' | head -1)

if [ -z "$ROOT" ]; then
    echo "找不到 root-sprd，根文件系统尚未组装"
    exit 1
fi

echo "== 根文件系统来源 =="
echo "$ROOT"
ls "$ROOT"
echo
echo "== 关键文件 =="
ls -la "$ROOT/sbin/init" "$ROOT/etc/preinit" "$ROOT/etc/os-release" 2>&1
cat "$ROOT/etc/os-release" 2>/dev/null | head -4
echo

mkdir -p "$OUT"
rm -rf "$OUT/rootdir"
cp -a "$ROOT" "$OUT/rootdir"

# 这些 7.3 内核模块在原厂 4.14 内核上永远加载不了，删掉省空间
if [ -d "$OUT/rootdir/lib/modules" ]; then
    echo "== 删除不可用的 7.3 内核模块 =="
    du -sh "$OUT/rootdir/lib/modules"
    rm -rf "$OUT/rootdir/lib/modules"
fi

echo "== 打包前大小 =="
du -sh "$OUT/rootdir"
echo "== 分区容量上限: 285 LEB x 126976 = 34.5 MiB =="

mkfs.ubifs -m 2048 -e 126976 -c 285 -x zlib -r "$OUT/rootdir" -o "$OUT/system.ubifs"

echo
echo "== 产物 =="
ls -la "$OUT/system.ubifs"
echo -n "镜像头: "
xxd -l 8 -p "$OUT/system.ubifs"
echo "原厂头: 311810066a9b7a5c"
