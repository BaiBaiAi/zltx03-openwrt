#!/bin/bash
set -e
OW=/build/openwrt
K=/build/kernel
A=$OW/dl/linux-7.3.0-sy108-14658d97220a.tar.gz

rm -f "$A" "$OW/.part" /build/openwrt/dl/*.part

# 用符号链接构造 linux-7.3.0/ 前缀，tar -h 跟随链接，避免 --transform 留下 './' 根条目
rm -rf /tmp/kt
mkdir -p /tmp/kt
ln -s "$K" /tmp/kt/linux-7.3.0

cd /tmp/kt
tar -chf - linux-7.3.0 | pigz -6 -p 12 -n > "$A"

ls -la "$A"
echo "--- 条目抽样 ---"
tar -tzf "$A" | head -3
echo "--- 条目总数 ---"
tar -tzf "$A" | wc -l

H=$(sha256sum "$A" | cut -d' ' -f1)
echo "HASH=$H"

V=$(awk '/^VERSION =/{v=$3} /^PATCHLEVEL =/{p=$3} /^SUBLEVEL =/{s=$3} END{print v"."p"."s}' "$K/Makefile")
echo "KVER=$V"

printf 'LINUX_VERSION-7.3 = .0\nLINUX_KERNEL_HASH-7.3.0 = %s\n' "$H" > "$OW/target/linux/sprd/kernel-7.3"
cat "$OW/target/linux/sprd/kernel-7.3"
echo DONE
