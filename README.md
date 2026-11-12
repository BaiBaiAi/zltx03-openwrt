# ZLT X03 (SXL-D01) OpenWrt 移植

为通则康威 ZLT X03 5G CPE（紫光展锐 UDX710 SoC）构建定制 OpenWrt 固件的工作仓库。
当前采用 **方案 B：保留原厂内核（4.14.98），仅替换根文件系统**，不触碰任何 RSA 签名分区。

## 设备概况

| 项目 | 内容 |
|---|---|
| 型号 | ZLT X03 / SXL-D01（中国移动定制） |
| 主 SoC | Unisoc UDX710（Cortex-A55 x2，512MB DRAM） |
| IDU | Realtek RTL8198D 路由协处理器 |
| 存储 | NAND，24 分区，根文件系统为**裸 UBIFS**（无 UBI 层） |
| 根分区几何 | min_io=2048 / LEB=126976 / LEB 上限 285（约 34.5 MiB） |
| 内核 | MOCORTM_21A BSP，Linux 4.14.98 |

## 关键结论（已从二进制证实）

- **boot 分区受 DHTB + RSA-PSS 签名保护**（U-Boot 内含 `sprd_secure_check` / `orca_cpe_boot_verify`），
  因此第一版固件不换内核。
- `system` 分区是**裸 UBIFS 镜像**（三个数据分区均无 `UBI#` 头），可直接用
  `mkfs.ubifs` 产出同格式镜像替换。
- 引导链：`BootROM → splloader → sml → uboot → boot(ANDROID! 头) → ubi?/system(UBIFS)`。
- BootROM 位于片内掩膜 ROM，flash 刷坏仍可进入下载模式救援，**变砖可完全恢复**。

## 分区备份状态

已备份：`splloader / uboot / boot / misc / miscdata / system / userdata / prodnv / recovery`。
缺 `sml`（1MB，不影响刷写，原厂固件包可补）。

## 当前固件构建状态

- OpenWrt **v25.12.5**（锁定提交 `f0a60ee`）+ [sy108-mainline](https://github.com/jason-liu-4980/sy108-mainline) 集成（7/7 补丁）
- 内核源码 [linux-udx710](https://github.com/jason-liu-4980/linux-udx710) 提交 `14658d9`（Linux 7.3.0，打包为校验归档）
- 目标 `sprd/udx710 · DEVICE_sy108 · aarch64_cortex-a55`
- 根文件系统 71 包 / 约 7MB，打包后 **system.ubifs 4.6MB**（分区上限 34.5MB）
- 工具链、内核、软件包全部编译通过；产出物通过 `scripts/pack.sh` 直接生成

## 仓库结构

```
scripts/
  rebuild-tree.sh        # 按锁定提交重建 OpenWrt 源码树并注入 SY108 集成
  apply-patches.sh       # 转换行尾后应用 7 个补丁
  mk-kernel-archive.sh   # 生成 OpenWrt 校验内核归档（pigz 并行压缩）
  build.sh               # 编译（含 FORCE_UNSAFE_CONFIGURE、干净 PATH、LINUX_SOURCE 覆盖）
  pack.sh                # root-sprd -> 裸 UBIFS 镜像（几何参数锁死原厂值）
  setup.sh               # 首次环境准备
config/
  zltx03-rootfs.config   # 方案 B 的 .config 种子（禁用全部 kmod / firewall4 / dnsmasq）
.github/workflows/
  build.yml              # GitHub Actions 云端构建（手动触发）
```

## 本地构建要点（踩过的坑）

1. WSL 下是 root：需要 `FORCE_UNSAFE_CONFIGURE=1`
2. 从 Windows 复制的文件是 CRLF：`target/linux/sprd`、补丁、series 全部要先转 LF
3. `v25.12.5` 标签 ≠ 锁定提交 `f0a60ee`：补丁只对提交生效，必须用提交
4. WSL 会继承 Windows PATH：`find -execdir` 因此拒绝执行，需显式清理 PATH
5. 自定义内核源码必须以 make 变量传入：`LINUX_SOURCE=linux-7.3.0-sy108-<hash>.tar.gz`
   （kernel.org 上没有 7.3.0 的官方 tar.xz）
6. `git.openwrt.org` / WSL 直连 GitHub 不稳定：走本机代理

## 启用云端构建

`ci/build.yml` 是 GitHub Actions 工作流，已写好但未启用（推送 workflow 文件需要令牌具备 `workflow` 权限）。
启用方法：`gh auth refresh -s workflow` 后，把 `ci/build.yml` 移到 `.github/workflows/build.yml` 再推送，即可在 Actions 页手动触发。

## 路线图

- [x] 引导链逆向与分区备份
- [x] 确认 system 为裸 UBIFS、确定替换格式
- [x] OpenWrt 用户态构建（71 包，4.6MB 镜像）
- [ ] 移植原厂 USB gadget（configfs RNDIS）初始化脚本到 OpenWrt rootfs —— **刷写前必须完成**，否则设备启动后无法通过 USB 网络访问
- [ ] 静态 IP 规划（usb0=192.168.10.1）与 root 密码预置
- [ ] 通过 FDL2 写入 system 分区，验证启动
- [ ] 第二版：接入 LuCI / feeds，恢复完整 Web 管理
- [ ] 第三版（可选）：验证 secure boot 熔丝，评估是否可换 mainline 内核

## 免责声明

仅供该设备所有者用于自有设备的系统研究，备份镜像与固件请勿用于商业用途。
刷写操作有变砖风险，请先完成全部分区备份。
