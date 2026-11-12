#!/bin/bash
# CI 版打包：从已组装好的 root-sprd 生成裸 UBIFS 镜像
# 几何参数来自原厂 system 分区 UBIFS 超级块，不要改
set -e

OW=/build/openwrt
OUT=/build/out
ROOT=$(find "$OW/build_dir" -maxdepth 2 -type d -name 'root-sprd' | head -1)

if [ -z "$ROOT" ]; then
    echo "root-sprd not found" >&2
    exit 1
fi

mkdir -p "$OUT"
rm -rf "$OUT/rootdir"
cp -a "$ROOT" "$OUT/rootdir"

# 7.3 内核模块在原厂 4.14 内核上不可用，删除以省空间
rm -rf "$OUT/rootdir/lib/modules"

du -sh "$OUT/rootdir"
mkfs.ubifs -m 2048 -e 126976 -c 285 -x zlib -r "$OUT/rootdir" -o "$OUT/system.ubifs"

ls -la "$OUT/system.ubifs"
# 校验 UBIFS 魔数 0x06101831（小端 31181006）
H=$(xxd -l 4 -p "$OUT/system.ubifs")
[ "$H" = "31181006" ] || { echo "bad magic: $H" >&2; exit 1; }
echo "system.ubifs OK"
