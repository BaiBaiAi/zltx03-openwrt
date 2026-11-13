# X03 RAM 启动实验包（零刷写）

目的：不写任何分区，直接经 BootROM/FDL1 把「原厂内核 + no-psci DTB + OpenWrt initramfs」送进 DDR 并跳转，实机验证 OpenWrt 用户态、USB RNDIS 与 SSH。成功后，持久化路径只剩 SPL/uboot 补丁链一个问题。

## 原理（全部基于已实测机制）

1. BootROM 下载模式接受未签名 FDL1（CVE-2022-38694 行为，`exec_addr 0x3f28` 绕过）。
2. `fdl1-ram-probe.bin` 是把 EXEC_DATA 内部校验改为恒 0 的 FDL1 副本，已实测可执行未签名第二阶段。
3. FDL1 的 EXEC_DATA 跳转到「最后载入文件的加载地址 + 0x200」。stub 放在 0x9efffe00（与原 fdl2 槽位一致），因此「最后载入」与「固定槽位」两种假设下都跳到 0x9f000000 执行 stub。
4. stub 置 x0=DTB(0x85000000)，dsb→ic iallu→dsb→isb，`br` 到内核 0x80080000。内核要求 MMU 关闭——FDL1 环境即如此，故不做 SCTLR 操作。

## 文件

| 文件 | 说明 |
|---|---|
| `make-booter-stub.py` | 生成 stub（含编码自检）；产物 `booter-stub.bin`（0x200 垫 + 7 条指令） |
| `make-nopsci-dtb.sh` | 克隆已准备的 DTB 并删除 /psci，重跑布局检查（WSL 内运行） |
| `x03-minimal-nopsci.dtb` | 最小 initramfs 用（USB trace=1，initrd 0x86000000–0x8608e9da） |
| `x03-openwrt-nopsci.dtb` | OpenWrt initramfs 用（trace 关，initrd 0x86000000–0x86444dac） |
| `run-ramboot-minimal.cmd` | 实验 A 一键脚本 |
| `run-ramboot-openwrt.cmd` | 实验 B 一键脚本 |

布局检查结果（`check-initramfs-layout.py`，均通过）：
- Image `0x80080000–0x80be3000`、DTB `0x85000000–0x850182b0`、initramfs `0x86000000…`，避开 9 个保留区（含 SML 0x85300000、sysdump 0x85500000、uboot/sysdump 0x9f000000）。stub 在 0x9efffe00+0x200=0x9f000000，位于 uboot 保留区起点，不与任何载荷冲突。

## 操作步骤

1. 完全断电 → 按住 RESET → 插 USB，等 Windows 枚举 "SPRD U2S Diag"。
2. 先跑实验 A（`run-ramboot-minimal.cmd`）：文件小、有 USB 串口观测点。
   - 成功标志：USB 枚举 `1782:000b`（MI_00 = SPRD AT），串口 115200 8N1 收到
     `ZLT X03 initramfs: reached PID 1, USB serial ready`。
   - 可同时运行 `..\diagnostics\watch-initramfs-usb.ps1 -TimeoutSeconds 90`。
3. 实验 A 通过后跑实验 B（`run-ramboot-openwrt.cmd`）：RNDIS 枚举后把适配器设为
   192.168.10.2/24，`ssh root@192.168.10.1`（Dropbear 公钥来自打包时注入）。
4. 任何失败：直接 RESET/重新上电，设备回到原厂启动，**分区一个字节都没动**。

## 已知限制与失败模式

- **单核**：无 SML → 无 PSCI。DTB 已删 /psci，4.14 内核只在 CPU0 启动并告警其余核无法上线，属预期。
- **无调制解调器**：本路径不加载 SML/trustos，5G 上行不可用；本实验只验证用户态/USB/SSH。
- 若 spd_dump 在 `fdl stock-kernel.bin 0x80080000` 处报 `timeout reached` → 首刷实测确实发生
  （FDL1 连接成功、下载内核超时）。两个原因：默认单命令超时太短（下载走虚拟串口，慢），
  或 FDL1 有单次下载大小上限。按下面「FDL1 download probe」流程定位。

## FDL1 download probe（交互式，2026-11-13 实测修正版）

**关键机制（源码 spd_dump.c 确认）**：`fdl fdl1.bin 0x28007000` 在 brom 阶段会自动 EXEC
FDL1 并连上它（`fdl1_loaded=1`），**不需要、也不能在中间插独立 exec**——没有第二阶段
就发 exec 会让 FDL1 挂起并在 15 秒后超时退出（首刷失败日志的正因）。FDL1 阶段的
`fdl` 上传用固定 528 字节/包 + 每包 ACK，11.5MB 内核约 2.2 万包，需数分钟，勿中断。

1. 双击 `run-fdl1-interactive.cmd`（结尾**无 exec**），等出现 `FDL1 >` 提示符。
2. 按顺序输入（**stub 必须最后**，exec 只在最后发一次）：
   ```
   fdl stock-kernel.bin 0x80080000
   fdl x03-minimal-nopsci.dtb 0x85000000
   fdl x03-minimal-initramfs.cpio.gz 0x86000000
   fdl booter-stub.bin 0x9efffe00
   exec
   ```
3. 最终 `exec` 后 spd_dump 会打印 EXEC FDL2 并随超时报错退出——**属预期**（它等待的
   "FDL2" 已经是我们的内核），忽略它，看观测窗口。
4. 一键版 `run-ramboot-minimal.cmd`（v3）已按正确顺序重写，可直接代替手输。
5. 在另一窗口先跑 `diagnostics\watch-initramfs-usb.ps1 -TimeoutSeconds 120`，exit 0 = 成功。

- 若 stub 跳转后串口/USB 均无反应 → 内核早期挂死，优先怀疑：
  1. SMC 触及无 PSCI 的 EL3（已通过删 /psci 规避，若 DTB 里还有其他 smc 调用者需再排查）；
  2. 异常级不是内核预期的 EL1/EL2（需在 stub 前加打印或经 UART 观测）；
  3. DDR 初始化仅由 BootROM/FDL1 保证，主内存区域可用性已由 FDL2 实测覆盖。
- UART（ttyS0, 115200 8N1，`earlycon` 已在 bootargs）接上可直接看到内核日志，强烈建议先行焊接。

## 常见问题

- `p` 分区表缺失不影响本实验（不读写 NAND）。
- 实验 A 的 DTB 含 `x03_usb_trace=1`；实验 B 的 DTB 已关闭 trace（避免占用 UDC 与 RNDIS 冲突）。

## 傍晚复核：脚本修正与 FDL1 加速探针（纯离线）

**修正 1：`run-ramboot-openwrt.cmd` 的中间 `exec` 已删除（v2）。** 该文件此前在
`fdl fdl1-ram-probe.bin` 之后紧接一个独立 `exec`，与第 9 轮实测结论及本文件
「FDL1 download probe」一节矛盾：brom 阶段的 `fdl` 会自动 EXEC 并连接 FDL1，
此时再发一次 `exec` 且无第二阶段载荷，会让 FDL1 挂起并在 15 秒后
`recv_msg_timeout` 退出。现与 `run-ramboot-minimal.cmd` v3 一致，只在 stub 之后保留一次 `exec`。

**修正 2：「把大载荷搬到 FDL2 阶段」不成立。** 复核 `_ref/spreadtrum_flash/spd_dump.c:812`
与 `:974`：`fdl` 和 `exec` 在 `fdl2_executed > 0` 时都打印
`FDL2 ALREADY EXECUTED, SKIP` 并**直接跳过**。FDL2 阶段没有干净的大载荷上传通道，
`write_flash` / `send` 的 `send_file` 还会固定使用 528 字节包。RAM-boot 只能留在 FDL1 阶段。

**新方案：`blk_size` 加速 FDL1 上传（待实机验证）。** 源码依据：
- `:822` — `fdl` 在 `fdl1_loaded > 0` 时使用 `blk_size ? blk_size : 528`，包大小可配；
- `:1497` — `blk_size` 命令在主机端**没有阶段检查**（帮助文本的「fdl2 stage only」只是文档口径）；
- `:1502` — 值被限制到 `0xf800`（63488）并按 `0x800` 对齐。

若设备端 FDL1 接受 62 KiB 的 MIDST 包，11.5 MiB 内核的包数可从约 21800 降到约 190，
直击第 10 轮「528B 小包洪流 6000+ 包后 USB 断链」的失败根因。先用
`run-fdl1-blksize-probe.cmd` 以 100 KiB 小文件验证，再决定是否生成分块批量脚本；
该探针只写 RAM，失败按 RESET 即可恢复。

## 第 21 轮实机修正：`exec_addr 0x3f28` 并非必需

本文件开头第 1 条「BootROM 下载模式接受未签名 FDL1（CVE-2022-38694 行为，
`exec_addr 0x3f28` 绕过）」需要按实测收敛。PROBE A 在同一台设备上**不带** `exec_addr`、
不带 custom exec stub、也没有主机端 CVE 自动绕过，就把 payload 被改的
`fdl1-ram-probe.bin` 送进 RAM 并让 FDL1 回报了
`Spreadtrum Boot Block version 1.1`；而带 `exec_addr 0x3f28` 的 PROBE B 反而在
`EXEC FDL1` 后 `CHECK_BAUD FAIL → device removed`。因此：

- 该注入链不是启动 FDL1 的必要条件，且可能是 USB 掉线的一个诱因（第 6 轮它成功过，
  故也可能是单次时序问题，用 `run-probe-execaddr-isolation.cmd` 隔离）。
- **这不等于 secure boot 未启用**：BootROM 只校证书不校 payload 哈希时，熔丝开或关
  表现一致。NAND SPL 的验签仍须由 P0 实机判定。
- 本包脚本暂不改动（历史上这条链能工作）；若 `blk_size` 探针仍出现小包洪流断链，
  优先做「去掉 `exec_addr`」的 A/B 对照，而不是继续加大载荷。
