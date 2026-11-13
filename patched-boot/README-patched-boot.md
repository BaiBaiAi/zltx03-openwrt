# 持久化补丁链实验包（P0/P1）

目的：绕过引导链上的两级验签，让无签名的 OpenWrt `system` 分区可以持久启动。所有补丁文件均由本项目脚本从原厂备份生成，可复现。

## 逆向证据（2026-11-13，idalib ARM64 无头分析）

### SPL（NAND 启动函数 @ 运行时 0x28007634，运行基址 0x28000000，256KB 双副本）

| 步骤 | 行为 |
|---|---|
| 1 | 读 `sml`(NAND 0x180000, 0x10000) → 0x852FFE00；读 `uboot`(0x40000, 0xC0000) → 0x9EFFFE00 |
| 2 | `sub_28008CAC`(0x852FFE00) 验 sml → 失败读 `smlbak`(0x480000) 再验 → 再失败 **B 自跳死循环 0x28007718** |
| 3 | 验 uboot(0x9EFFFE00) → 失败读 `ubootbak`(0x340000) 再验 → 再失败 **死循环 0x2800777C** |
| 4 | 通过后 `BLR 0x85300000` 进 SML |

- 验签实现 `sub_2800AB7C` 的**唯一**调用者是 thunk `0x28008CAC`（原指令 `B sub_2800AB7C`），全部 6 处验签调用都经过它。
- **结论：只补 uboot 不够**（SPL 对补丁 uboot 验签失败 → 死循环），必须同时补 SPL。

### U-Boot（文件 0x200 = 运行时 0x9F000000）

- system 验签 wrapper `sub_9F05DB90` **仅有一个调用点** 0x9F05DD30（即 README 已记录的文件偏移 0x5df30 处）：
  `BL sub_9F05DB90; CBZ W0,成功; B 自跳死循环 0x9F05DD38`，成功 = 返回 0。
- 补丁后 `W0=0` → 走成功路径并置已验标志 → 继续正常启动。
- `boot` / `recovery` 镜像的验签走**另外的函数**，本次不动——这两个分区保持原厂，验签自然通过。

## 补丁内容（均为 8 字节 `MOV W0,#0; RET` = `00 00 80 52 C0 03 5F D6`）

| 文件 | 补丁点 | 说明 |
|---|---|---|
| `fdl-verification/x03-spl-noverify.bin` | 文件 0x8CAC 和 0x28CAC（两份副本的验签 thunk） | SPL 的 sml/uboot 验签全部跳过 |
| `fdl-verification/x03-uboot-noverify.bin` | 文件 0x5DD90（system 验签 wrapper 入口） | U-Boot 对 `system` 的 DHTB+RSA-PSS 验签跳过 |

生成脚本：`fdl-verification/spl_make_patch.py`、`fdl-verification/uboot_make_patch.py`（依赖 idalib 做调用点核验）。SHA-256 在同名 `.sha256` 文件。

## 实验阶梯

**P0（最小决定性实验）**：只写补丁版 `splloader`，其余全原厂。
- 若 BootROM **不**校验 NAND 上的 SPL → 设备正常启动原厂系统（1782:4056、web 200）→ BootROM 放行，进入 P1。
- 若 BootROM **强制**校验 → 不启动 → 下载模式写回原厂 splloader（恢复链路已验证）。唯一未知项就此定案。

**P1（方案 B 完整刷写）**：`uboot`+`ubootbak` 补丁版 + `system` = OpenWrt UBIFS（`firmware/dist/system-linux414.ubifs`，无签名）+ `splloader` 补丁版，其余原厂。
- 预期：BootROM → 补丁 SPL → 原厂 SML → 补丁 U-Boot（跳过 system 验签）→ OpenWrt rootfs → RNDIS → `ssh root@192.168.10.1`（Windows 适配器设 192.168.10.2/24）。
- 若失败但不启动：**只需写回原厂 system**——补丁 SPL/uboot 启动原厂 system 无需签名，回滚粒度小。

**回滚**：`run-rollback-stock.cmd` 恢复 splloader/uboot/ubootbak/system 四个分区（需先从 `ZLT-X03-backups-20261113.zip` 解出 `full\splloader.bin`、`full\uboot.bin`、`win\system.bin` 到 `fdl-verification\stock-backups\`；`ubootbak` 不在 zip 里，缺时先用 spd_dump `r ubootbak` 重读）。

## 风险与边界

- P0 是唯一未验证环节（BootROM 对 SPL 的策略）；进入下载模式的硬件通路（断电+RESET+USB）与分区恢复流程已多次实测，即使 P0 失败也可完全恢复。
- 若 P0 通过而 P1 卡在内核挂载/USB 初始化，可用 `ram-boot/` 包的 RAM 启动实验 A/B 定位（零刷写）。
- 补丁版 SPL/uboot 同时使 `boot` 分区未来可换内核（boot 验签在 uboot 内另行处理，暂未触碰）。
- 强烈建议在实验前焊好 UART（ttyS0 115200）以便观测 P0/P1 的启动日志。
