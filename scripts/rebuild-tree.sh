#!/bin/bash
# 用项目锁定的 OpenWrt 提交重建源码树，保留 feeds / dl / target
set -e
COMMIT=f0a60eee2fe051741c643ea6118718aae1ef17fb
B=/build
OW=$B/openwrt

echo "== 备份保留目录 =="
rm -rf $B/keep && mkdir -p $B/keep
[ -d $OW/feeds ] && mv $OW/feeds $B/keep/feeds
[ -d $OW/dl ] && mv $OW/dl $B/keep/dl
[ -d $OW/target/linux/sprd ] && mv $OW/target/linux/sprd $B/keep/sprd

echo "== 下载锁定提交 =="
cd $B && rm -rf ow.tar.gz openwrt-src
curl -sL --retry 3 -o ow.tar.gz "https://codeload.github.com/openwrt/openwrt/tar.gz/$COMMIT"
ls -la ow.tar.gz
mkdir -p openwrt-src && tar xzf ow.tar.gz -C openwrt-src --strip-components=1
rm -rf $OW && mv openwrt-src $OW

echo "== 还原保留目录 =="
[ -d $B/keep/feeds ] && mv $B/keep/feeds $OW/feeds
[ -d $B/keep/dl ] && mv $B/keep/dl $OW/dl
[ -d $B/keep/sprd ] && mv $B/keep/sprd $OW/target/linux/sprd

find $OW/target/linux/sprd -type f -exec sed -i 's/\r$//' {} + 2>/dev/null || true

echo "== 建 git 基线 =="
cd $OW
git init -q .
git add -A >/dev/null 2>&1
git -c user.email=b@b -c user.name=b commit -qm base >/dev/null 2>&1 || true

echo "== 应用补丁 =="
bash /mnt/c/Users/Administrator/WorkBuddy/2026-11-12-21-13-01/firmware/apply-patches.sh
