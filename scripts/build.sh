#!/bin/bash
cd /build/openwrt || exit 1
export FORCE_UNSAFE_CONFIGURE=1
# WSL 会继承 Windows PATH，其中的相对路径会让 find -execdir 拒绝执行
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# 如网络受限，在此处设置 https_proxy / http_proxy

# SY108 用自定义内核源码归档，通过 make 变量覆盖默认的 kernel.org 下载
# （kernel.org 上没有 7.3.0 的官方 tar.xz）
KSRC="LINUX_SOURCE=linux-7.3.0-sy108-14658d97220a.tar.gz"
JOBS=$(nproc 2>/dev/null || echo 8)

echo "START $(date +%H:%M:%S)" > /tmp/dl.log
make -j$JOBS download $KSRC >> /tmp/dl.log 2>&1
echo "DL_EXIT=$?" >> /tmp/dl.log
grep -E 'DL_EXIT=[^0]' /tmp/dl.log && { tail -20 /tmp/dl.log; exit 1; }

echo "START $(date +%H:%M:%S)" > /tmp/build.log
make -j$JOBS $KSRC >> /tmp/build.log 2>&1
echo "BUILD_EXIT=$?" >> /tmp/build.log

echo "DONE $(date +%H:%M:%S)"
tail -8 /tmp/build.log
