# ZLT X03 (SXL-D01) OpenWrt 移植

为通则康威 ZLT X03 5G CPE（紫光展锐 UDX710 SoC）构建定制 OpenWrt 固件的工作仓库。
当前验证 **方案 B：保留原厂内核（4.14.98），仅替换根文件系统**。实机首刷未启动，随后已恢复原厂 `system`。原厂 U-Boot 同时校验 `system` 的签名尾部。

## 设备概况

本机的销售型号由机主确认为中国移动 5G 随心联 SXL-D01。备份中的 `/system/version` 将 `device` 和 `real_device` 均标记为 `ZLT X03`，版本为 `1.8.17 usr`，构建时间为 `2025-02-07 18:13`。查运营商售后资料时使用 SXL-D01，核对本机固件时同时匹配内部型号与版本。中国移动的公开商城条目列有 SXL-D01，尚未取得可验证的调试固件。随附改串包描述的 `/goform/` 接口尚未证实适用于该版本，本机对其查询路由返回 HTTP 404。

| 项目 | 内容 |
|---|---|
| 型号 | ZLT X03 / SXL-D01（中国移动定制） |
| 主 SoC | Unisoc UDX710（Cortex-A55 x2，512MB DRAM） |
| IDU | Realtek RTL8198D 路由协处理器 |
| 存储 | NAND，原厂启动参数从 UBI 的 `system` 卷挂载 UBIFS 根文件系统 |
| `system` 备份几何 | min_io=2048 / LEB=126976 / 当前 285 LEB / 超级块 max_leb_cnt=516 |
| 内核 | MOCORTM_21A BSP，Linux 4.14.98 |

## 关键结论（已从二进制证实）

- **boot 分区受 DHTB + RSA-PSS 签名保护**（U-Boot 内含 `sprd_secure_check` / `orca_cpe_boot_verify`），
  因此第一版固件不换内核。
- FDL 导出的 `system.bin` 是裸 UBIFS 镜像。原厂 DTB 指定 `root=ubi0:system rootfstype=ubifs`。
  `mkfs.ubifs` 生成的是卷内容，打包暂以原厂备份的 285 LEB 为保守上限。FDL 写入 `system` 的行为和实机回滚仍待验证。
- 引导链：`BootROM → splloader → sml → uboot → boot(ANDROID! 头) → ubi?/system(UBIFS)`。
- 已通过 Windows `SPRD U2S Diag` 验证 BootROM 握手和 FDL1/FDL2 RAM 加载。FDL2 识别 NAND，但 `p` 未返回完整分区表。

## 分区备份状态

已备份：`splloader / uboot / boot / misc / miscdata / system / userdata / prodnv / recovery`。
Release `backup-20261113` 缺 `sml`。实机已按原厂 U-Boot 的分区定义读出 768 KiB，镜像以 `DHTB` 开头。
实机读回的 `system` 前 256 KiB 与该 Release 的备份逐字节一致。

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

`.github/workflows/build.yml` 可在 Actions 页手动触发。两种打包入口均从 `rootfs/` 加入 X03 配置。

本地测试镜像可通过 `ZLTX03_SSH_PUBLIC_KEY=/path/to/key.pub bash scripts/pack.sh` 写入 SSH 公钥。
Dropbear 使用公钥认证并绑定 USB 接口。Windows 的 RNDIS 网卡可设为 `192.168.10.2/24`，设备地址为 `192.168.10.1`。
初次启动默认关闭 uHTTPd 自启动，等 SSH 登录和管理凭据配置完成后再启用 Web 管理。

## 路线图

- [x] 引导链逆向与分区备份
- [x] 确认 system 为裸 UBIFS、确定替换格式
- [x] OpenWrt 用户态构建（71 包，4.6MB 镜像）
- [x] 接入 configfs RNDIS 初始化、`usb0=192.168.10.1` 和可选 SSH 公钥注入
- [x] 通过 FDL2 写入 system 分区（落盘已 SHA 验证；启动受验签门限制，见下午章节）
- [x] secure boot 状态判定：SPL 强制验签 uboot 签名；引导块（splloader）擦/写被
      mtd 层拦截；BootROM 下载模式始终可用（详见 2026-11-13 下午章节）
- [ ] 写入补丁 SPL（候选：三补丁精简 fdl2 走 `sprd_nand_write_spl` / ResearchDownload）
- [ ] 实机验证 OpenWrt 启动、Windows RNDIS 枚举及 SSH 登录
- [ ] 第二版：接入 LuCI / feeds，恢复完整 Web 管理

## 2026-11-13 首次实机刷写

- `system.ubifs` 为 7,364,608 字节。通过 Windows FDL2 写入 `system` 后，全量读回的 SHA-256 与原文件一致。
- FDL 复位和普通重新上电后，Windows 均未枚举 OpenWrt RNDIS。仅凭 USB 观察无法定位到 UBIFS 挂载、用户态启动或 USB gadget 初始化。
- 重新进入 BootROM 后刷回 Release 的原厂 `system.bin`。读回前 256 KiB 与备份一致，复位后 `1782:4056` 和原厂 RNDIS 恢复，`http://192.168.10.1/` 返回 HTTP 200。
- 有 TTL 时可采集原厂 DTB 指定的 `ttyS0` 启动日志（115200 8N1）。没有 TTL 时，可用 `bash diagnostics/pack-usb-trace.sh /build/out/rootdir system-usb-trace.ubifs` 打包独立的 USB 诊断镜像。
- 诊断镜像在 OpenWrt init 前尝试以 `1782:000b` 枚举 USB 串口。Windows 的原厂驱动可按 `MI_00` 匹配 `SPRD AT`，脚本尝试经该串口发送启动信息。看到该 USB 标识即可确认内核已挂载根文件系统并执行到用户态。如果 USB 仍无枚举，故障仍可能发生在挂载根卷或 USB 初始化阶段。
- 实机诊断镜像写入后全量读回一致。复位后未观测到 `1782:000b`，未取得启动日志。已再次刷回原厂 `system`，抽查前 256 KiB 与备份一致，原厂管理页恢复 HTTP 200。
- 离线比较显示，两份镜像都使用 UBIFS 格式版本 4 和 `2048/126976` 几何。原厂镜像默认压缩为 LZO、开启 space-fixup，超级块最大 LEB 数为 516。OpenWrt 镜像使用 zlib，未开启 space-fixup，最大 LEB 数为 285。这些差异的实机影响待验证。

## 原厂 `system` 验签

- `uboot.bin` 文件偏移 `0x5df30` 调用 `orca_cpe_system_verify`，失败后进入循环。常规启动中，校验代码用 UBIFS 超级块的 `leb_size × leb_cnt` 计算数据长度，在其后 `+0x294` 处检查 DHTB 魔数，并比对 DHTB 的长度字段。
- 原厂 `system.bin` 的 UBIFS 数据长 `0x2283000`，DHTB 位于 `0x2283294`。证书中的数据摘要与前 `0x2283000` 字节的 SHA-256 一致，证书 RSA-PSS 签名已用其中公钥离线验过。两份已试刷的 OpenWrt 镜像均缺少签名尾部。
- IDA Hex-Rays 以 `0x9f000000` 装载原厂 U-Boot 的 ARM64 负载（文件偏移 `0x200`）。`0x9f05d80c` 从 UBIFS 超级块取得长度并读取尾部；`0x9f05e7f4` 按描述符对负载计算 SHA-256；`0x9f05e4b4` 比对负载摘要和证书公钥摘要，再验 RSA-PSS 并调用版本检查。外层缺头或长度错误时在 `0x9f05dd38` 停留，密码学校验失败时在 `0x9f05eb7c` 停留。
- `sprd_secure_check` 从内存 `0x9efffe00` 处的原厂 U-Boot 镜像读取证书里的下一级公钥摘要。离线确认原厂 U-Boot 证书（文件偏移 `0x80780`）的下一级摘要字段等于原厂 `system` 证书内 264 字节公钥结构的 SHA-256。原厂 SPL 证书的下一级摘要也匹配原厂 U-Boot 和 SML 的签名公钥。SPL、U-Boot、SML 和 `system` 的证书签名及原始负载摘要均用备份离线核对通过。
- 原厂 U-Boot 在 `bootmode=recovery` 路径跳过 `system` 检查，随后对独立的 `recovery` 镜像执行自己的签名校验。正常启动缺少有效 `system` 签名时，所见错误路径是停留，未见自动转入 Recovery。
- 按原厂 LZO、space-fixup 和 `max_leb_cnt=516` 重打包的对照镜像已离线解包验证。它仍是无签名 UBIFS，只用于本地比较。
- 原厂 Web 资源有 ADB 开关，API 命令为 `237`，原厂启动脚本读取 `SYS_ADB_SWITCH`。实机用 level 2 管理员登录成功，ADB、Telnet 和 Modem Log 开关的只读查询均返回 `LIMITED_ACCESS`。已准备 RAM 用户态归档，实机测试需要可用的原厂 shell。
- 原厂升级脚本使用支持签名镜像的 SWUpdate，向 `ota.swu` 传入 `/etc/swupdate_key/public.pem` 的副本及板型参数 `udx710-module:1.0`。该 RSA-2048 公钥与原厂 `system` 证书公钥不同，已离线比较两者的模数和指数。厂商签名的 SWU 维护包可作为待核对的交付格式。网页另有配置导入命令 `184`，尚未发现其提供 shell 或绕过 `usr` 的 ADB 启动策略。旧会话在本轮只读查询中返回 `NO_AUTH`，未取得设备在线升级配置。
- 离线解包原厂 `userdata` 和 `prodnv` 备份。默认配置的 `USR_FOTA_SWITCH` 为 `0`，FOTA URL 字段为空或占位值，`prodnv/main_config` 未见 FOTA 字段，`SYSUPGRADE.log` 未见下载 URL 或 SWU 包名。两卷内未找到 `.swu` 或 `.pac`。备份中两份 `mifi` 日志均记录 `usr` 分支停止 ADB。`prodnv` 有 `disable_macwriter` 标志，`userdata` 日志有工厂服务被跳过的记录。这些结果来自备份，尚未确认实时 FOTA 配置。
- 当前设备为 `version_type:usr`。原厂 `adbd_restart.sh` 对 X03 的 `usr` 分支停用 `adbd`，原厂 Telnet 脚本在 `main_config` 存在时提前退出。因此只改 `userdata` 中的开关值不足以打开这两个入口。原厂 Recovery 的启动项未配置 ADB。
- 原厂 `1.8.17 usr` 根文件系统未找到 `sshd` 或 Dropbear 服务端，实机 TCP 22、23 和 5555 均未连通。`/etc/inittab` 在运行级别 1–5 为 `ttyS0` 配置了 115200 波特的登录控制台。`/bin/start_getty` 在该串口存在且驱动报告启用时调用 `getty`。焊盘、电平和登录权限仍需实机验证。`/etc/fstab` 显示 `/home`、`/mnt/data` 和 `/var` 来自独立的 `userdata` 卷。
- 2026-11-13 正常断电重接的 Windows USBHUB3 跟踪中，记录了 `1782:4D00` 下载接口和原厂 `1782:4056` 复合设备。设备级事件未显示其他展锐 VID/PID。该跟踪未验证瞬时的 ADB 接口或握手，开机完成后的 `adb devices` 列表为空，原厂管理页返回 HTTP 200。上一次独立的 105 秒 TCP 探测未观察到 5555 开放。
- 后续正常冷启动用 Windows Configuration Manager 轮询 USB 设备及子接口，同时运行 `adb track-devices`。观察到 `1782:4D00` 和两次 `1782:4056` 枚举，未观察到 ADB transport。原厂脚本的 RNDIS + ADB 模式使用 `1782:4038`，本机已有 INF 匹配其 `MI_06`，本次未观察到该 PID。轮询结果仅覆盖本次实测和 Windows 可见的设备。
- 使用 `python diagnostics/check-system-signature.py <候选镜像> --stock <已知可启动的原厂system.bin>` 离线检查签名尾部。脚本依赖 Python `cryptography`。已验证原厂备份通过，三个无签名镜像失败，原厂数据区或签名被改动时均失败。
- R106 有通过保留卷头绕过局部 CRC 的社区案例。该做法无法保留 X03 原厂证书覆盖的完整数据摘要。SY108 的独立 Recovery 可用于参考，其首次安装需要机型配套 U-Boot。[R106 实测](https://blog.dann.top/how-to-crack-udx710-mifi-1/#4.新设备) · [SY108 项目](https://github.com/jason-liu-4980/sy108-mainline)
- ZLT S50 的网络诊断入口有经 `tcpdump` 运行临时命令的实测。X03 的固件没有预装 `tcpdump`，现有 X03 实测记录也未能通过该入口执行命令。[ZLT S50 项目](https://github.com/InkAssists/zlt-s50-unlock)

## USB RAM 加载验证

- 原厂 U-Boot 的 Fastboot `boot` 和 `continue` 共享同一个处理函数。该函数退出 USB 后启动 NAND 上的 `boot`。当前版 `spd_dump reboot-fastboot` 会写 `misc` 请求进入 Recovery 的 Fastboot，未用于只读探测。
- X03 的 FDL1 在 `EXEC_DATA` 处理中校验 RAM 中的第二阶段，并跳转到加载地址加 `0x200`。原始 `fdl1.bin` 的文件偏移 `0x8694` 调用校验函数。本次仅在 RAM 加载副本中改为返回 0。
- FDL2 测试副本把入口跳过的 `0x204` 处 NOP 改为零，保留原证书，因而改变了签名覆盖的数据。经 BootROM、修改后的 FDL1 加载并执行此副本后，读取 `system` 前 16 KiB 与原厂备份逐字节一致。FDL2 副本及 FDL1 副本均通过 USB 载入 RAM，随后复位，原厂管理页返回 HTTP 200。
- 该试验验证了 X03 可从 DDR 执行修改后的第二阶段。Linux 仍需单独验证 ARM64 入口状态、DTB 与 initramfs 地址、SML/PSCI 依赖，以及 USB 或其他可观察的启动标记。原厂 DTB 声明 DDR 为 `0x80000000` 起的 512 MiB，SML 保留区从 `0x85300000` 起，`0x9f000000` 起为 U-Boot/sysdump 保留区。

### 最小 initramfs 离线验证

- 原厂 `boot` 与 `recovery` 均包含未压缩的 ARM64 Image。两者的内核二进制不同，但 Image 头均声明 `text_offset=0x80000`、`image_size=0xb63000`。备份中的 `board.dtb` 与 `boot` 镜像内的 DTB 逐字节相同。Recovery 有独立 DTB 和带 `/init` 的 gzip newc 归档，正常 boot 的 52 字节 gzip ramdisk 解压后是 22 字节文本。正常 boot 的 DTB 指定 UBIFS 根卷，Recovery 的 DTB 则指定 `root=/dev/ram0`。
- 在具有 `mknod` 权限的 Linux 环境中运行 `bash diagnostics/pack-minimal-initramfs.sh /build/out/rootdir x03-minimal-initramfs.cpio.gz` 可打包诊断归档。归档包含项目的 ARM64 BusyBox、musl、libgcc 和最小 `/init`。该 init 向控制台打印 PID、架构、内核版本及 sysfs 挂载状态。
- 用 QEMU `virt`、Cortex-A55 和 Alpine `6.18.60-0-virt` 验证归档。串口输出确认 `/init` 作为 PID 1 运行，`proc` 和 `sysfs` 挂载成功。X03 原厂 4.14 内核的实机交接和 USB 观测仍待验证。
- 同一归档也通过 Alpine `4.14.167-0-vanilla` 的 ARM64 QEMU 验证。以未修改的 X03 原厂 `4.14.98` 在同一虚拟板启动时，从来宾 RAM 取出的内核日志显示，内核进入 EL1 初始化，随后执行 `smc #0`（调用号 `0x82000100`）时触发未定义指令异常。将虚拟板改为 `secure=on` 后，QMP 在该调用的 EL3 异常入口 `0x200` 采到停留状态。两次原厂内核测试均未观察到 initramfs 解包。
- 两份原厂 DTB 均声明 `arm,psci-0.2` 且使用 `smc`，UART 和 DWC3 节点相同。只有 Recovery DTB 的 `/chosen` 带静态 initrd 范围 `0x85500000–0x855a3212`，跨度与镜像里的 5,762,230 字节归档不同。实际交接时需要用加载后的范围验证设备树属性。

### 原厂 4.14.98 的 QEMU 启动

- 用 Trusted Firmware-A v2.14.0 的 QEMU 平台提供 EL3 和 PSCI。虚拟板使用 `virt,secure=on`、Cortex-A57 和 1024 MiB RAM，TF-A 以 `ARM_LINUX_KERNEL_AS_BL33=1` 构建，BL33 地址为 `0x60080000`，按内核 Image 的 `text_offset=0x80000` 放置。原厂内核 Image 未改动。
- 通过 QEMU loader 将 initramfs 放在 `0x44000000`，在虚拟板设备树的 `/chosen` 中按归档实际长度写入 `linux,initrd-start` 和 `linux,initrd-end`。虚拟板 DTB 禁用 PL011 控制台之外的 PrimeCell 外设，避免旧内核探测这些外设时触发同步外部中止。以上地址和外设调整均针对 QEMU。
- 从来宾内存读取的内核日志确认原厂内核解包归档并释放 initrd，`/init` 输出 `reached PID 1`、`aarch64 4.14.98` 和 `sysfs mounted`。最小 init 同时向控制台与 `/dev/kmsg` 输出。实机的原厂 SML、UDX710 外设和 USB 枚举仍需验证。

### 最小 initramfs 的 USB 串口标记

- 给内核命令行加 `x03_usb_trace=1` 可开启。归档中的 `/bin/x03-usb-trace` 最多等待 `29100000.dwc3` 15 秒，使用 configfs 创建 `1782:000b`，按原厂 `usbenum.sh` 的校准模式顺序绑定 `gser.gs2`、`vser.gs0`、`gser.gs3`、`gser.gs1`。Windows 的 UNISOC INF 将该 VID/PID 的 `MI_00` 识别为 SPRD AT。
- Windows 枚举到 `1782:000b` 是 gadget 已绑定的信号。串口接收到 `ZLT X03 initramfs: reached PID 1, USB serial ready` 可确认日志已从最小 initramfs 传到主机。等待或配置失败时，脚本把原因写入内核日志，PID 1 继续运行。
- QEMU `virt` 上验证了开启参数后能到达 PID 1，并在缺少该 UDC 时按时记录超时。真实 USB 枚举、串口驱动绑定和日志传输仍需 X03 实机验证。
- 在 Windows PowerShell 中运行 `diagnostics/watch-initramfs-usb.ps1 -TimeoutSeconds 90` 可观察本次测试。脚本只打开 `1782:000b` 的 `MI_00` 串口。退出码 `0` 表示已收到 PID 1 标记，`2` 表示已枚举但未收到标记，`3` 表示等待期间未枚举。

### 实机 DDR 布局离线检查

- 使用 `python3 diagnostics/check-initramfs-layout.py stock-kernel.bin board.dtb x03-minimal-initramfs.cpio.gz` 检查候选布局，需安装 `fdtget`。脚本核对 ARM64 Image 对齐和内存占用、DTB 大小和对齐，以及载荷之间和原厂保留区的重叠。
- 用正常启动的原厂 DTB 验证当前归档。候选范围为 Image `0x80080000–0x80be3000`、DTB `0x85000000–0x850182c8`、最小 initramfs `0x86000000–0x8608e9da`，结束地址均不含在范围内。脚本检查原厂 DTB 声明的八个保留区，并额外避开原厂内核的默认 sysdump 地址 `0x85500000`。该地址由内核在缺少 `sysdump_magic` 和 `magic-addr` 时采用，已从原厂 4.14.98 的代码和 QEMU 日志确认。若 DTB 或归档重新生成，应按实际文件重新检查。
- 该检查只覆盖静态布局。实机的引导程序临时缓冲区、SML 和 PSCI 初始化、CPU 入口状态及 USB 观测均需单独验证。

### 诊断设备树与原厂交接

- `diagnostics/prepare-initramfs-dtb.sh` 生成诊断 DTB，按归档实际长度更新 `/chosen` 的 initrd 起止地址，并加上 `rdinit=/init x03_usb_trace=1`。逐属性比较确认其余节点和属性与原厂 boot DTB 相同。当前诊断 DTB 的候选范围为 `0x85000000–0x850182ec`。
- 原厂 U-Boot 在文件偏移 `0x1a5f8` 使用内核地址 `0x80080000`，在 `0x1a714` 使用 ramdisk 地址 `0x85500000`。原厂 SPL 在 `0x77e8` 调用 `0x85300000`。备份的 SML 是含 BL31、PSCI 和展锐 SiP 服务的镜像。FDL1 的 `EXEC_DATA` 路径在 `0x86a4` 直接调用 RAM 里的第二阶段入口。已有 FDL 实测覆盖 DDR 读取，尚无 Linux 入口的安全状态或厂商 SiP 服务实测。
- 原厂 U-Boot 含串口加载命令字符串，默认环境为 `bootdelay=0`。备份 `misc` 的前 1 MiB 通过环境 CRC 检查，其中没有 `bootdelay` 覆盖项。自动启动处理函数在延时为 0 时跳过按键轮询。板载 UART 可先用于抓取 `ttyS0` 的完整启动日志，交互入口仍需验证。原厂 Linux Recovery 的启动脚本包含升级及清空用户数据分支，进入原厂 Recovery 与最小 RAM 诊断是两种不同操作。
- X03 原厂 SML 的负载从文件偏移 `0x200` 开始，头部声明长度为 `0xcf50`。加载到 `0x85300000` 后，`0x85305ea4` 返回非安全世界入口 `0x9f000000`，`0x8530305c` 调用它并将地址写入入口描述符。SML 在 `0x85306b54` 至 `0x85306b5c` 设置 `SCR_EL3`、`SPSR_EL3`、`ELR_EL3`，恢复寄存器后在 `0x85306b3c` 执行 `eret`。入口描述符依据 U-Boot 入口指令与 CPU 特性选择返回状态。X03 的原厂 U-Boot 入口读取 `CurrentEL`，分别初始化 EL1、EL2 或 EL3 向量。这些是原厂镜像的离线结果，USB 下载状态下的 CPU 异常级仍待实机观测。

### 原厂模式的 USB 和 Web 日志

- 原厂正常 USB 模式为 `1782:4056`。Windows 的 SPRD AT（MI_02）响应 `AT`，`AT+CGMR` 返回 `Orca_NR_modem` 和 `udx710_modem`。三个 SPRD Common AT 接口也返回了基带版本。MI_02 的 `AT+CLAC` 返回 `+CME ERROR: 4`。
- SPRD LOG（MI_04）在正常开机后两轮被动读取均无数据，第二轮启用了 DTR 和 RTS。原厂 `S04usbenumfirst` 在 Linux 用户态调用 `usbenum.sh` 建立 gadget，因此这些接口无法实时观察枚举之前的启动阶段。
- level 2 会话可读取 Web 系统事件日志（命令 17）。本机读取的事件日志没有 U-Boot、内核版本、UBIFS 或 PSCI 启动标记。Yocto 日志配置的只读查询返回 `LIMITED_ACCESS`，包导出请求超时，未取得归档。

### 同平台参考与备用引导分区

- [SY108 U-Boot / SPL](https://github.com/jason-liu-4980/sy108-uboot-spl) 记录了在保留原厂 SPL、SML 和 `ubootbak` 的情况下，启动 OpenWrt 主系统和独立 Recovery 的实机结果。X03 可参考其原厂 SML 交接和恢复流程，需按 X03 的板级配置验证。
- 将 SY108 内核提交 `14658d97220a` 的 Main 与 Recovery DTS 用 `cpp` 和 `dtc` 编译，再与 SXL-D01 原厂备份的 DTB 比对。三份 DTB 均声明从 `0x80000000` 起的 512 MiB DDR，八个保留节点的名称和 `reg` 范围一致。USB DWC3 同在 `0x29100000`。SY108 源码明确配置 peripheral 角色，主系统使用 PAMU3 硬件卸载，Recovery 使用软件路径。SXL-D01 原厂 4.14.98 的 USB 封装节点使用 `extcon`，需按所用内核核对角色、PHY 和 PAMU3。 [SY108 设备树文档](https://github.com/jason-liu-4980/sy108-mainline/blob/main/docs/devicetree.md)
- SXL-D01 原厂 U-Boot 的 NAND 分区定义与 SY108 编译后的 DTB 都将 `uboot` 和 `sml` 放在 `0x40000` 和 `0x180000`。SXL-D01 的 `ubootbak`、`smlbak`、`ubipac` 分别从 `0x340000`、`0x480000`、`0x640000` 开始，SY108 对应为 `0x260000`、`0x3a0000`、`0x480000`。SXL-D01 原厂 Linux 从 `ubi0:system` 挂载 UBIFS，SY108 主系统从 `rootfs` UBI 卷挂载 SquashFS。移植需使用 SXL-D01 的布局核对读取、恢复和挂载目标。 [SY108 启动流程](https://github.com/jason-liu-4980/sy108-uboot-spl/blob/main/docs/platform.md)
- 用 SXL-D01 原厂 Image、原厂 DTB 和完整 OpenWrt 归档复测静态布局。X03 候选地址 `0x80080000`、`0x85000000`、`0x86000000` 通过检查。将 initramfs 放到 SY108 启动器采用的 `0x85500000` 时，检查因与 X03 原厂内核的 sysdump 页冲突而拒绝。该检查仅验证静态地址，实机交接仍未验证。
- [Quectel UDX710 日志指南](https://quectel.com/content/uploads/2024/02/Quectel_RGx00URM500U_Series_Log_Capture_Guide_V1.0.pdf) 区分 AP 与 CP 日志，并记录了用厂商调试模式通过 USB 虚拟端口抓 AP 日志的流程。X03 的 SPRD AT 对其中两条只读状态查询均返回 `+CME ERROR: 4`。
- [ZTE F50 / MU300 Linux](https://github.com/dikeckaan/mu300-linux) 使用 T760/UMS9620 设备的备用 Android 启动槽和试启动计数实现回退。X03 的 NAND/UBI 布局和启动选择逻辑需要独立验证。
- 实机通过现有 USB 线完整读出 `ubootbak`（1,310,720 字节）和 `smlbak`（786,432 字节），分别与主分区的已有备份逐字节一致，已保存 SHA-256。读出后复位，原厂 USB 接口恢复，管理页返回 HTTP 200。备用分区的实际回退行为仍未验证。
- 原厂 SPL 的 NAND 启动函数（文件偏移 `0x7634`）先读 `sml`（NAND `0x180000`）和 `uboot`（`0x40000`）。SML 的第一次验证返回非零时，读取 `smlbak`（`0x480000`）并再次验证。U-Boot 的第一次验证返回非零时，读取 `ubootbak`（`0x340000`）并再次验证。该分支位于 SML 交接之前，覆盖的是引导镜像校验失败。当前没有证据表明通过校验的 U-Boot 在随后运行失败时也会由 SPL 回退。以上分支已从本机 SPL 离线确认，尚未用故障镜像在实机触发。
- 完整 OpenWrt 用户态作为 initramfs，在 QEMU 使用未改动的原厂 4.14.98 测到 `preinit`、`procd` 和 `ubusd` 启动。用 QEMU 测试归档注入熵后，仍未观测到 `procd` 进入 `init complete`。服务就绪和实机板级外设仍待验证。

### Linux 4.14 的 ubus 兼容性

- 当前锁定的 ubus 源码用 `getrandom(..., GRND_INSECURE)` 为 ubus 对象生成 ID。原厂 4.14.98 早于该标志的 Linux 5.6 引入版本。构建补丁在内核返回 `EINVAL` 或 `ENOSYS` 时使用 `/dev/urandom`。本地构建和 CI 都通过 OpenWrt 的包补丁目录应用该补丁。
- 在相同的原厂 4.14.98 QEMU 环境中，原版与修正版 `ubusd` 都能创建 socket，但只有修正版的 `ubus list` 返回 0。完整 OpenWrt 测试归档替换修正版后，`procd` 成功连接 ubus 并开始执行 `/etc/rc.d/S* boot`。测试归档在虚拟机内额外初始化了熵池。
- 延长测试后已执行到 `rc.local`。`procd`、`ubusd`、`logd`、`rpcd`、`netifd` 均在运行，`ubus -t 2 list system` 返回 0。用正常 OpenWrt 包安装流程重新组装了 rootfs，并从新打包的 `system-linux414.ubifs` 解包比对 `ubusd`。该 UBIFS 仍缺少原厂签名，实机 RAM 交接与 USB 网络仍待验证。

### 完整 OpenWrt RAM 测试归档

- 运行 `bash diagnostics/pack-openwrt-initramfs.sh <root-sprd> x03-openwrt-initramfs.cpio.gz`。脚本复用正常根文件系统的配置和 USB 服务，使用 `INITRAMFS=1` 进入 OpenWrt 的 RAM 启动路径。可通过 `ZLTX03_SSH_PUBLIC_KEY` 注入 SSH 公钥。
- 配套 DTB 由 `bash diagnostics/prepare-initramfs-dtb.sh <Image> <board.dtb> <archive> x03-openwrt-initramfs.dtb 0x86000000 0` 生成，最后一个参数关闭最小 initramfs 的 USB 串口标记。当前归档范围为 `0x86000000–0x86444dac`。
- 使用未改动的原厂 4.14.98 和 QEMU 虚拟板验证实际打包归档，未注入额外熵。日志确认 `/sbin/init` 启动、`procd` 连接 ubus 并进入启动服务阶段，内核随后完成 CRNG 初始化。配套 X03 DTB 通过离线检查，实机板级交接和 USB SSH 仍待验证。
- 在原归档末尾追加仅供 QEMU 使用的 `rc.local` 观测脚本，并确认原归档字节完整保留。未注入额外熵。虚拟机到达 `rc.local`，`procd`、`ubusd`、`logd`、`rpcd` 和 `netifd` 均在运行，`ubus -t 3 call system board` 返回成功。虚拟板没有 X03 的 DWC3 控制器和 `usb0`，Dropbear 未运行。记录为 `firmware/dist/x03-openwrt-initramfs-services-qemu.log`。
- 在另一次 QEMU 测试中，临时将 Dropbear 绑定到回环接口。`pidof dropbear` 和 `/proc/net/tcp` 确认进程启动并监听 `127.0.0.1:22`。探测未捕获到 SSH 握手标识，公钥登录和实机 USB SSH 仍待验证。记录为 `firmware/dist/x03-openwrt-initramfs-ssh-qemu.log`。

## 2026-11-13 下午：写入机制全案逆向 + SPL 强制验签判定 + 设备恢复

### 首刷失败根因闭环
- 首刷 OpenWrt `system` 不启动的根因已闭环：U-Boot 对 `system` 做 DHTB+RSA-PSS 验签，
  无签名镜像在 `orca_cpe_system_verify` 失败后停留，内核未获执行——OpenWrt rootfs 本身无需怀疑。
- BSL 命令码：`START_DATA=0x01 / MIDST_DATA=0x02 / END_DATA=0x03 / ERASE_FLASH=0x0A`；
  END_DATA 即擦写提交触发点。`sub_9F05BE7C` 为标准 strcmp（0=相等）。

### 写入机制全案（逆向 + 实测矩阵，全部已确认）
- **安全分区表**：`dl_download_start`（`sub_9F015A80`）按名字表
  `@0x9F0604B0 = [spl, uboot, boot, recovery, splloader, sml, nr_agdsp, nr_modem,
  nr_v3phy, nr_nrphy, nr_nrdsp1, nr_nrdsp2]` 标记安全分区（`0x9F0C3DC4=1`）：
  MIDST 只累积不落盘，写入延迟到 END_DATA 之后。
- **dl 验签门**：`dl_download_end`（`sub_9F015EEC`）对安全分区先调用
  `sub_9F05DA48`（= `orca_cpe_dl_verify`）验签整个下载镜像，失败 → 错误路径 →
  设备复位（主机端表现为 `usb_send failed (0/8)` 于 END_DATA）。通过后才
  mtd 擦除 + 写入循环（`sub_9F01530C`，最多重试 3 次）。
- **splloader 专属写路径**：`_dl_nand_write`（`0x9F01530C`）按分区名 strcmp 分派，
  splloader 走 `sprd_nand_write_spl`（`0x9F02C238`，模式 8 引导块写、双副本布局、
  先写 block 0）；其余分区走通用 MTD 写 `sub_9F02D9E4`（标准实现：对齐/越界/
  坏块处理，无内容检查）。**注：由于验签门在前面，`sprd_nand_write_spl` 从未被
  真正执行过**——所有"专属路径崩溃"实为 dl 验签失败。
- **引导块保护**：splloader（NAND 0x0 起 256KB）的 mtd 擦除/写入被静默拦截
  （擦除失败 → `dl_download_end` 提前返回，写入循环不执行）——这是 STEP A/B 的
  "Write Part Done 但回读=原厂"的原因；`Write Part Done` 仅代表数据传输 ACK，
  对安全/受保护分区不可信，一切以回读 SHA 为准。

### 实测矩阵（落盘与否以回读 SHA 为准）

| 实验 | 第二阶段 | 目标分区 | 结果 |
|---|---|---|---|
| 上午 ×2 | mini fdl2 | system（非安全） | **真实落盘**（全量 SHA 验证） |
| attempt 1-3 | mini fdl2 / uboot-FDL2 | splloader（安全+补丁内容） | dl 验签失败 → 复位 |
| STEP A | 补丁 uboot-FDL2 | splloader（安全+原厂内容） | 验签通过 → 写入被引导块保护静默拦截（回读=原厂） |
| STEP B v2 ×2 | dl2noverify uboot-FDL2 | splloader（安全+补丁内容） | 验签 NOP 后无复位，但擦/写仍被静默拦截（回读=原厂） |
| uboot test v2 | dl2noverify mini fdl2 | uboot（安全+补丁内容） | **真实落盘**（回读=补丁，diff 恰为 8 字节补丁 @0x5DD90）→ 设备起不来 |
| P1 | mini fdl2 | system（非安全+OpenWrt） | 真实落盘 → 不启动（见下） |
| 恢复 ×2 | mini fdl2 | ubootbak / system+uboot（原厂内容） | 真实落盘 → 设备完全恢复 |

### SPL 强制验签判定（P1 实验结论）
- P1 后 NAND 终态：splloader=原厂 / **uboot=补丁（system 验签已绕过，真实落盘）** /
  ubootbak=原厂 / sml=原厂 / system=OpenWrt UBIFS（已写入）。
- 启动现象：正常上电即显示 `SPRD U2S Diag`（挂死 uboot 的下载 USB，非 BootROM）。
- 判定：**SPL 强制验签 uboot 签名**——补丁 uboot 验签失败 → 回退 ubootbak（原厂）→
  原厂 uboot 严格验签 system → 无签名 OpenWrt UBIFS 验签失败 → uboot 停留错误循环。
  （若 SPL 放行补丁 uboot，system 验签已被补丁绕过，OpenWrt 应能启动。）
- 推论：持久化 OpenWrt 必须让 SPL 放行，即必须写 splloader——而引导块的擦/写被
  mtd 层静默拦截。中途 ubootbak 曾被 uboot 写入的双写机制损坏（读至 55% 设备掉线
  = NAND 读错误特征），导致 SPL 回退也失败 → 死循环；已恢复。

### 事故与恢复（全部可逆，已验证）
- uboot test 后设备起不来：SPL 拒补丁 uboot → 回退 ubootbak → 当时 ubootbak 已损坏
  → SPL 死循环（`0x2800777C` B self）。
- 恢复一：`run-recover-ubootbak.cmd` 写回原厂 ubootbak（回读逐字节一致）→ 可启动。
- 恢复二：`run-recover-full.cmd` 写回原厂 system+uboot → **设备完全恢复原厂**
  （sml/ubootbak 与基准逐字节一致，`sml-768k.bin`、`ubootbak-first-read.bin` 为基准）。
- 运维教训：上电即见 U2S Diag ≠ BootROM（可能是挂死 uboot 的 USB），必须彻底断电后
  走 RESET 流程；`.cmd` 注释必须 REM 开头且纯 ASCII；`%~dp0` 相对脚本目录而非 cwd。

### 剩余可行路线（按风险排序）
1. **精简 fdl2 三补丁**：在 `x03-fdl2-dl2noverify.bin`（验签 NOP @0x16E30 已就绪）
   基础上再 NOP `dl_download_end` 的通用 mtd 擦除调用、保持分派不补丁（splloader 走
   专属路径）→ 让从未真正执行的 `sprd_nand_write_spl`（模式 8 专用引导块写入器，
   自带擦除）接管。风险：模式 8 写入器未经验证，失败可能损坏 SPL；
   兜底：ResearchDownload + 自制 pac（全部分区备份在手，RD 可恢复任何状态）。
2. **ResearchDownload 官方升级平台** + 自制 pac（用本机备份组包）直接刷补丁 SPL——
   RD 的 FDL2 为 SPD 官方构建，具备引导块写入能力。工作量中等，成功率较高。
3. **RAM-boot**（`ram-boot/` 包，零刷写）：每次开机经 BootROM 载入 OpenWrt，
   不持久但完全可用作实验/救援环境。

### 傍晚复核：FDL 协议层的新旁路（纯离线，未刷写）

复核 `_ref/spreadtrum_flash` 源码与本机 `spd_dump.exe`（`sha1 d24c21a0…`）后，有两点证据修正。

**1）写入通道不止 `w <分区名>` 一条（【已确认】）。** `common.c` 中两条路径的
`BSL_CMD_START_DATA` 载荷格式不同：

| 命令 | 实现 | START_DATA 载荷 |
|---|---|---|
| `w splloader file` | `load_partition` → `select_partition@984` | 72 字节 UTF-16 分区名 + 4 字节长度 |
| `write_flash file 0` | `send_file` → `send_buf@824` | **仅 8 字节**（BE 地址 + 长度），不含分区名 |

`dl_download_start`（`sub_9F015A80`）按名字 `strcmp` 查安全分区表；按地址通道不携带名字，
理论上不会命中该表，因而可绕开 dl 验签门。现有全部 `.cmd` 只用 `w`，该通道从未实机验证。
`spd_cmd.h:82` 另有 `BSL_CMD_ENABLE_WRITE_FLASH = 0x1B`（注释 `disable write protect`）及
响应码 `0xAC NOT_ENABLE_WRITE_FLASH`，与「引导块擦/写静默拦截」现象吻合【高概率】，
但**本机 exe 未编译 `sendcmd`/`sendcmdv`**，暂时无法下发该命令码（已用二进制字符串表核实）。
`write_flash`、`erase_flash`、`write_word`、`end_data`、`w_force` 则确实编译进了 exe，
只是 `-h` 帮助文本未列出。

**2）P0 判据顺序需要调整【高概率】。** `exec_addr 0x3f28` 的定义是「绕过 BootROM 对
splloader/fdl1 的签名验证」；P1 又已证 SPL 无条件验签 uboot。两者共同指向 secure boot
可能已启用 —— 若 BootROM 同样校签 NAND SPL，则补丁 SPL 写入成功也启动不了，
路线 1/2 全部失去意义。原 P0 把这个前提放在「写入之后」才验证，应先做零写入判定。
**严禁下发 `BSL_CMD_ENABLE_SECUREBOOT = 0x1C`**，该命令可能烧写熔丝。

此外，源码 `:812` / `:974` 显示 `fdl` 与 `exec` 在 `fdl2_executed > 0` 时被直接跳过，
因此「把 RAM-boot 大载荷迁到 FDL2 快路径」的方案不成立；替代方案是在 FDL1 阶段
用 `blk_size 63488` 放大 MIDST 包（见 `ram-boot/README-ramboot.md` 傍晚章节）。

**新增实验包（均未执行，需先手动进入下载模式：彻底断电 → 按住 RESET → 插 USB）：**

| 脚本 | 作用 | 风险 / 状态 |
|---|---|---|
| `patched-boot/run-probe-bootrom-verify.cmd` | 用 payload 被改的 `fdl1-ram-probe.bin`、不带 `exec_addr` 观察 BootROM；v2 去掉尾部 `reset` | 零写入，**已实测通过** |
| `patched-boot/run-probe-addrpath.cmd` | 原 PROBE B（带 `exec_addr`），`read_flash` 比对 | 零写入，**已实测失败，废弃** |
| `patched-boot/run-probe-addrpath-clean.cmd` | PROBE C v2：干净链 + `read_part splloader` 回读基准（原 `read_flash` 已证返回 `0xFE`） | 零写入，**干净链已实测跑通，v2 待跑** |
| `patched-boot/run-probe-execaddr-isolation.cmd` | PROBE D：隔离 `exec_addr` 注入是否导致掉线 | 零写入，可选（C 已跑通，主线不再依赖） |
| `patched-boot/run-probe-efuse.cmd` | PROBE E：读 eFuse block 0..15，判定 secure boot 熔丝 | 零写入，待跑 |
| `patched-boot/run-write-spl-addrpath.cmd` | v3 干净链 + `write_flash` + 同会话 `read_part splloader` 回读 | 写 NAND block 0，有回滚脚本 |
| `ram-boot/run-fdl1-blksize-probe.cmd` | 验证 FDL1 是否接受 62 KiB MIDST 包 | 仅写 RAM |

前置顺序固定为：bootrom 判定 → 地址映射判定 → 写入 PoC。任何写入实验都必须用
**补丁内容**做对照并同会话回读，不得再用原厂内容（第 14 轮已证无法区分「写入成功」与「跳过」）。

### 第 21 轮：PROBE A / B 实机结果（零写入，设备仍为原厂）

**PROBE A 通过，且推翻了「必须 `exec_addr 0x3f28`」的前提。**

```
SEND fdl1-ram-probe.bin to 0x28007000
EXEC FDL1
CHECK_BAUD FAIL
CHECK_BAUD FDL1
BSL_REP_VER: "Spreadtrum Boot Block version 1.1"
CMD_CONNECT FDL1
KEEP_CHARGE FDL1
timeout reached        <- 尾部 reset 在仅 FDL1 时无人应答，无害，v2 已删除
```

日志中**没有** `bypassing BROM verification with CVE-2022-38691`，也没有 `exec_addr` /
`custom_exec_no_verify_3f28.bin` 注入。离线核实 `fdl1.bin` 结构：DHTB 头 `0x200`，
payload `0x200..0xB960`，`sprdsignedimageheader @0xB960`（`cert_size 0x254`、
`cert_offset 0xB9C0`）；`0x8694` 落在 payload 内，故内容哈希已与证书不符；
`mPayloadHash` 全 0、证书字节未改，`key_size @0xB9C4 = 0x800` 是 `0x800` 的整数倍，
因此 `spd_dump.c:869-884` 的自动 CVE 绕过**不会**触发。结论是：BootROM 接受了
payload 被改动的 FDL1，且主机端没有任何绕过动作。

- 【已确认】`exec_addr 0x3f28` 对这台设备的这个 FDL1 **不是必需**的。
- 【判定边界】这**不能**判定 secure boot 熔丝状态：若 BootROM 只校证书、不校 payload
  哈希（CVE-2022-38694 类），无论熔丝是否烧掉表现都一样。NAND SPL 的验签策略仍须靠
  P0（补丁 SPL 落盘后断电重启观察）判定。上文「P0 判据顺序倒置」的担忧依然成立，
  只是最坏情况的概率下降了。
- 【术语修正】`0x8694` 的 4 字节是 `BL verify_call (86010094)` → `MOV W0,#0 (00008052)`，
  作用是禁用 **FDL1 自己对第二阶段**的验签，不是「破坏自身签名」的专用探针；
  其客观副作用才是 payload 哈希失配。

**PROBE B 失败：掉线发生在 FDL1 之前，`read_flash` 根本没执行。**

```
current exec_addr is 0x3f28
SEND fdl1.bin to 0x28007000
SEND custom_exec_no_verify_3f28.bin to 0x3f28
EXEC FDL1
CHECK_BAUD FAIL
device removed, exiting...
NO OUTPUT: read_flash produced no file.
```

与 A 的唯一结构差异是 `exec_addr 0x3f28` 注入链（以及后续的 FDL2 上传）。
注意该链在第 6 轮备份时**成功过**，所以也可能是单次 USB / 断电时序问题，
不能单凭一次失败定论。据此新增两个零写入脚本、并把写入 PoC 切到同一条干净链：

- `run-probe-addrpath-clean.cmd`（PROBE C）：不带 `exec_addr`，
  `fdl fdl1.bin` → 自动 EXEC FDL1 → `fdl fdl2.bin` → `exec` → `read_flash 0 0 262144`
  → 与 `stock-backups/splloader.bin` 逐字节比对。得 `MATCH` 才可做写入。
- `run-probe-execaddr-isolation.cmd`（PROBE D）：只发
  `exec_addr 0x3f28 fdl fdl1.bin 0x28007000`，用于区分「注入链必崩」与「偶发掉线」。
- `run-write-spl-addrpath.cmd` v2：去掉 `exec_addr`，回读从 `read_part splloader`
  改为 `read_flash 0 0 262144`，使整笔事务都不经过分区名查表。

两次实验之间必须**彻底断电 ≥10 秒**并等 `SPRD U2S Diag` 重新枚举。
本轮未执行任何写入，设备仍为原厂状态。

### 第 22 轮：PROBE C 实机结果（干净链跑通，但按地址读不存在）

**干净链完整跑通，FDL2 已连上。** 日志：`SEND fdl1.bin → EXEC FDL1 →
CHECK_BAUD FDL1 → "Spreadtrum Boot Block version 1.1" → CMD_CONNECT FDL1 →
KEEP_CHARGE FDL1 → SEND fdl2.bin → FDL2: incompatible partition（正常 DA info）→
EXEC FDL2 → DISABLE_TRANSCODE → Storage is nand`。至此【已确认】
`exec_addr 0x3f28` 不是必需条件，B 的掉线属于偶发或注入链时序问题；PROBE D 已不必再跑。

**但按地址读命令在这台 FDL2 上根本不存在。**

```
unexpected response (0x00fe)
Read Flash Done: 0x00000000+0x0, target: 0x40000, read: 0x0
FDL2 >
```

`0xFE = BSL_REP_UNSUPPORTED_COMMAND`（`spd_cmd.h:233`）；`dump_flash`
（`common.c:897-930`）下发的是 `BSL_CMD_READ_FLASH`（12 字节 addr/len/offset），
设备端未实现该命令，因此读了 0 字节。**结论：地址 0 是否映射到 splloader 无法在写入前
用读命令验证**，PROBE C 原本的 `MATCH` 判据作废。

- 【重要区分】这不否定「按地址**写**」：`write_flash` 走
  `BSL_CMD_START_DATA + MIDST/END_DATA`（上传 FDL2 用的就是这条基础下载通道），
  与 `READ_FLASH` 是不同命令族，仍可能可用。
- 【判据代价】由于无法预先验证地址映射，写入 PoC 的 `NOT LANDED` 结果变成**二义**：
  「写入被静默拦截」与「addr 0 不是 splloader 起点」无法区分，不能当作最终否定结论。

**两个意外收获：**

1. `FDL2 >` 是 `spd_dump` 的交互模式（`spd_dump.c:546-575`）：参数消费完后用
   `scanf` 读一行、按空格拆词，走**同一套命令处理器**。所有命令（`p` / `r` /
   `read_part` / `w` / `write_flash` / `e_efuse_read` / …）都能直接输入，
   **不必重新断电、不必重进下载模式**。脚本末尾看到该提示符不是卡死。
2. `e_efuse_read block_id` 可用（`spd_cmd.h:225/231`、`spd_dump.c:712`、
   `common.c:3856`），输出 `eFuse[0xN] = 0xXXXXXXXX`。这是判定 secure boot
   熔丝状态的直接手段，补上了第 21 轮「A 无法判定熔丝」的缺口。只读，
   严禁在任何提示符下发 `0x1C` 或其他熔丝写入命令。

**脚本修正：**

| 脚本 | 变化 |
|---|---|
| `run-probe-addrpath-clean.cmd` | v2：`read_flash` → `p` + `read_part splloader 0 262144`，判据改为 `READPART-OK`（复用第 6 轮已验证的分区名读通道，为写入 PoC 提供可靠回读基准） |
| `run-write-spl-addrpath.cmd` | v3：回读从 `read_flash` 改回 `read_part splloader`；前置条件改为 `READPART-OK`；`NOT LANDED` 标注为 inconclusive |
| `run-probe-efuse.cmd` | 新增：干净链读 eFuse block 0..15（纯只读） |
| `run-probe-execaddr-isolation.cmd` | 降级为可选：C 已证明干净链可用，注入链是否为元凶已不影响主线 |

本轮仍为零写入，设备处于 FDL2 下载会话中。

### 第 23 轮：交互提示符掉线复盘与一次性探针

用户在 `FDL2 >` 输入 `p` 后得到 `device removed, exiting...`，随后重跑的 PROBE C v2
停在 `Waiting for dl_diag connection`。三点澄清：

1. **`p` 不是元凶，也完全不必输入。** `spd_dump.c:1189-1198` 的 `p`/`print`
   只打印主机端缓存的 `io->part_count` / `io->ptable`，**不向设备发送任何数据**。
   `device removed` 是主循环末尾 `:1804-1806` 检查 `m_bOpened == -1` 时打印的，
   说明设备在 `read_flash` 返回 `0xFE` 之后、用户操作之前就已经掉线；输入 `p`
   只是让循环走到那个检查点。
2. **`read_part splloader` 不需要 `p` 前置。** `get_partition_info`
   （`common.c:1978-1983`）对 `splloader` 有硬编码分支，直接返回 `g_spl_size`，
   不查分区表。v2/v3 里加的 `p` 是多余的。
3. **修正上一轮的说法：参数消费完 `spd_dump` 不会退出。** `spd_dump.c:525` 是
   `while (1)`，`:546-575` 用 `scanf` 读一行进入交互提示符；只有设备掉线或
   tool mode 的 `exit` 才会 break。此前 `run-probe-bootrom-verify.cmd` v2 注释里
   「工具会自行退出」是错的，已改正。

**结论：不要依赖交互式 `FDL2 >`。** 人读日志、思考、再敲命令的空隙足以让设备
掉线。把所有命令写进参数列表一次跑完。新增 **`run-probe-fdl2-all.cmd`（PROBE F）**：
干净链 → `read_part splloader 0 262144` → `e_efuse_read 0..7`，
无 `p`、无 `exec_addr`、无 `read_flash`。`read_part` 排在最前，即使某个
`e_efuse_read` 超时触发 `ERR_EXIT`，基准文件也已落盘。

`run-write-spl-addrpath.cmd` 同步为 v4（去掉 `p`）。**正在运行的
`run-probe-addrpath-clean.cmd` 未被改写**——cmd.exe 逐行读取批处理文件，运行中改文件
会导致执行错乱；其 `p` 无害，跑完直接用 PROBE F 替代即可。

设备 PnP 只读检查结果：`SPRD U2S Diag (COM10)` Status = **OK**、VID_1782&PID_4D00，
即已枚举为下载模式，无需再断电重插；等待窗口会自动连接。

**随后 PROBE C v2 完整跑通，并第三次证明交互模式不可用：**

```
[========================================] 100.0% Speed:  3.97Mb/s
Read Part Done: splloader+0x0, target: 0x40000, read: 0x40000
FDL2 >read_part splloader 0 262144 spl-live.bin
device removed, exiting...
READPART-OK: readback equals stock splloader. Readback path is usable.
```

- 【已确认】**按分区名读 `splloader` 完全可用**：3.97 Mb/s 读满 256 KiB。
  离线独立校验 `readpart-baseline.bin` 262144 字节与
  `stock-backups/splloader.bin` **0 字节差异** → 设备 SPL 仍是原厂，
  前面所有实验确实零写入。这就是写入 PoC 所需的可靠回读基准。
- 【已确认】交互提示符下输入的第二条命令同样掉线，且 `spl-live.bin` 未生成。
  两次（先是 `p`、后是 `read_part`）都如此，与具体命令无关：
  命令流结束后设备端 FDL2 就会掉链，`FDL2 >` **不能用于任何命令**。
- 该轮的 `READPART-OK` 来自脚本开头参数列表里的 `read_part`（`fc /b` 比对），
  不是用户在提示符里补输的那条，两者不要混淆。

**收尾修正：** 为了让脚本不停在交互提示符，曾考虑 `-t` + `exit`，但
`spd_dump.c:270-282` 显示 `-t` 会**跳过 `libusb_init(NULL)`**，Windows/libusb
构建下有打不开设备的风险，故弃用。改为在参数列表末尾加 `reset`：
`spd_dump.c:1764-1772` 下发 `NORMAL_RESET` 后设备先复位，尾随的
`timeout reached` 是预期且无害。`run-probe-fdl2-all.cmd` 已采用；
已结束运行的 `run-probe-addrpath-clean.cmd` 也升为 v3（去掉 `p`）。

最后一轮设备 PnP 状态：`SPRD U2S Diag (COM10)` Status 由 **OK 变为 Unknown**，
即端口记录残留、设备已不在下载模式。**跑 PROBE F 前必须重新断电 → 按住 RESET → 插 USB。**

### 今日产物索引（fdl-verification/）
- 补丁镜像：`x03-spl-noverify.bin`（SPL 验签恒真，双副本 0x8CAC/0x28CAC）、
  `x03-uboot-noverify.bin`（system 验签 wrapper 恒真 @0x5DD90，**已实测落盘**）、
  `x03-uboot-genericwrite.bin`（分派恒通用 @0x15564）、
  `x03-uboot-dl2noverify.bin`（+dl 验签 NOP @0x16148）、
  `x03-fdl2-dl2noverify.bin`（mini fdl2 + dl 验签 NOP @0x16E30，sha `a6db5ec1`）
- 诊断/恢复脚本：`patched-boot/` 共 14 个（run-diag-read、run-recover-ubootbak、
  run-recover-full、run-restore-stocksystem、run-p1-system、run-uboot-test、
  read-spl-verify、run-rollback-stock 等）
- 基准备份：`stock-backups/{splloader,uboot,ubootbak,system}.bin`、
  `sml-768k.bin`、`ubootbak-first-read.bin`
- 诊断读回：`diag-*.bin`、`spl-readback*.bin`、`uboot-readback*.bin`、
  `system-openwrt-verify.bin`
- RAM-boot 零刷写路线：`ram-boot/`（booter stub + no-psci DTB + 一键脚本）



仅供该设备所有者用于自有设备的系统研究，备份镜像与固件请勿用于商业用途。
刷写操作有变砖风险，请先完成全部分区备份。
