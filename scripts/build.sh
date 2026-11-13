#!/bin/bash
set -e
REPO=$(cd "$(dirname "$0")/.." && pwd)
cd /build/openwrt || exit 1
install -D -m 0644 "$REPO/patches/ubus/010-allow-legacy-getrandom.patch" \
    package/system/ubus/patches/010-allow-legacy-getrandom.patch
export FORCE_UNSAFE_CONFIGURE=1
# WSL 会继承 Windows PATH，其中的相对路径会让 find -execdir 拒绝执行
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# 如网络受限，在此处设置 https_proxy / http_proxy

# SY108 用自定义内核源码归档，通过 make 变量覆盖默认的 kernel.org 下载
# （kernel.org 上没有 7.3.0 的官方 tar.xz）
KSRC="LINUX_SOURCE=linux-7.3.0-sy108-14658d97220a.tar.gz"
JOBS=$(nproc 2>/dev/null || echo 8)

echo "START $(date +%H:%M:%S)" > /tmp/dl.log
make -j"$JOBS" download "$KSRC" >> /tmp/dl.log 2>&1 || { tail -20 /tmp/dl.log; exit 1; }

echo "START $(date +%H:%M:%S)" > /tmp/build.log
{
    make -j"$JOBS" tools/install "$KSRC" &&
    make -j"$JOBS" package/feeds/sy108/sy108-image/host/compile "$KSRC" &&
    make -j"$JOBS" "$KSRC"
} >> /tmp/build.log 2>&1 || { tail -20 /tmp/build.log; exit 1; }

echo "DONE $(date +%H:%M:%S)"
tail -8 /tmp/build.log
