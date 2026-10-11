# Hardware: `amateur` (NixOS 26.11 · x86_64)

Local core deployment workstation (gaming, streaming, dev, AI, libvirt).

## Platform / Motherboard

| Field | Value |
|---|---|
| System / Board | ASUS **X570S AERO G** (D5) |
| BIOS vendor | American Megatrends (AMI) |
| BIOS version | **F7g** |
| Chassis asset tag | `CF` |
| Chassis type | Desktop (tower) |
| Platform (DMI) | ASUS |

## Processor

- AMD **Ryzen 7 5800X** — 8 cores / 16 threads (SMT exposed), Zen 3 (Family 25, Model 33/2)
- Boost observed on load: ~4.85 GHz (per-core sample 4830–4850 MHz), idle ~1.75 GHz (c-state)
- L2 cache: 512 KiB (per-core), 512 KB/4K TLB; address sizes 48b phys / 48b virt
- ISA: AVX/AVX2, AVX-512 **absent**; flags incl. `avx`, `avx2`, `sha_ni`
- Microcode: `0xa201213`

## Memory (RAM)

- **31 Gi** system RAM (32,750,740 kB total; `free`: 10 Gi used, 20 Gi available at capture)
- No reserved / huge-page pool (HugePages_Total = 0)
- Swap: **zram0**, 31 G (LZ4, compressed), 2.7 Gi currently used

## Graphics / GPU

- AMD **Radeon RX 6950 XT** (Navi 21), PCI `0e:00.0`, PCIe slot 0e, rev c0
- VRAM: **16 Gi total, 16 Gi active** (mem_info_vram_used 16,571,723,776 / 17,163,091,968); DRAM vendor **SAMSUNG** (GDDR6)
- PCB form factor: CEM (`board_info: type : cem`)
- VBIOS: **113-D4124100-NP4**
- AIB/Board vendor (Sapphire): subsystem `1DA2:440d` (Sapphire Technology)
- GPU clocks (pp_dpm): sclk 500/2639*/2720 MHz; mem mclk 96/456*/1124 MHz (clocks above = active index)
- DRM card: `card1` (renderD128), 8 i2c buses (DDC), 6 I2C lines

### Video Outputs (display I/O)

| Connector | Status | Supported modes (top) |
|---|---|---|
| **DP-1** | disconnected | — |
| **DP-2** | disconnected | — |
| **DP-3** | **connected** | 3840x2160, 2560x1440, 1920x1080, 1680x1050, 1280x800, 640x480, … |
| **HDMI-A** (HDMI-A-1 connector present) | connector present (no active mode listed) | — |

- 3× DisplayPort + 1× HDMI outputs; primary active display on **DP-3** (4K-class capable; mode list 3840x2160 top)
- Writeback plane: `card1-Writeback-1` (amdgpu)

## Audio

- **Navi 21/23 HD Audio Controller** (PCI `0e:00.1`) — GPU HDMI/DP digital audio (monitor: `snd_hda_intel power_save=1`)
- **USB audio**: Kingston **HyperX 7.1** (`0951:16a4`, 100 mA), USB 2.0, `HyperX Virtual Surround Sound` (7.1) — discrete audio endpoint
- HDMI/DP digital out + USB 7.1 are the only audio endpoints (GPU HDA + USB DACless). No separate NIC/MBO on-board audio.

## Storage

### NVMe (PCIe)

| Dev | Model | Size | Serial / WWN | Slot | Partitions |
|---|---|---|---|---|---|
| nvme0n1 | Crucial **T500** | **2 TB** (1.8 T) | `25064E3A5824` / eui.`00a075254e3a5824` | `01:00.0` | p1 vfat `/boot` (1022 M), p2 LUKS→ext4 **`/`** (105.5 G) |
| nvme1n1 | Micron **P2** | **1 TB** | `2234E6591589` / eui.`00a075223abf9cb3` | `04:00.0` | p1 ntfs "Games" → `/mnt/NVME1` (309 G) |
| nvme2n1 | Micron **P5 Plus** | **1 TB** | `22343ABF9CB3` / eui.`00a075223abf9cb3` | `05:00.0` | p1 vfat, p2 LUKS, p3 ntfs, p4 ntfs |

- All three NVMe are Micron `c0a9` family (T500/P2/P5) — NVMe-TCP / PCIe NVMe (block:nvme:pci)
- Root FS: LUKS `483d78a4…` → ext4 (crypto root), `init=/nix/store/…/nixos-system-amateur-26.11…` initrd Linux 7.2.8; boot vfat `/boot` (label BAD7-EBB1)

### SATA (AHCI, AMD FCH)

| Dev | Model (Micron/C0A9) | Size | Serial | Mount |
|---|---|---|---|---|
| sda | CT1000MX500SSD1 | 1 TB | `2230E64E52ED` (WWN `0x500a0751e64e52ed`) | p2 ntfs "more_Games" → `/mnt/SSDA` (284.8 G) |
| sdb | CT1000MX500SSD1 | 1 TB | `2230E64E54B6` (WWN `0x500a0751e64e54b6`) | p2 ntfs "Daten" → `/mnt/SSDB` (317.8 G) |

- Both SATA on AMD FCH SATA controller (AHCI), slots `0b:00.0` (ata-1 / ata-2), `rev 51`

## USB I/O (ASM3241 USB 3.2 Gen 2 hub @ PCI 06:00.0)

| ID | Device | Notes |
|---|---|---|
| 2109:2817 | **VIA USB 2.0 Hub** | 0 mA |
| 1a40:0101 | **Terminus Technology Hub** (USB 2.0) | 100 mA |
| 05e3:0608 | **Genesys Logic Hub** | 100 mA |
| 214b:7250 | **Huasheng USB 2.0 Hub** | 100 mA |
| 048d:5702 | **ITE Express RGB LED Controller** (HID 1.12) | 100 mA |
| 1bcf:0005 | **Sunplus Optical Mouse** (HID 1.10) | 98 mA |
| 1532:0531 | **Razer Seiren Mini** mouse (HID 1.11) | 100 mA |
| 3434:0b30 | **Keychron Q3 HE** keyboard (2 HID reports) | 500 mA |
| 1532:0e05 | **Razer Kiyo Pro** microphone (Bus 5, AX200 BT radio) | 100 mA |
| 0951:16a4 | **Kingston HyperX 7.1 Audio** (USB DACless audio) | 100 mA |

- Root hubs: Bus 1/2/3 (Linux xHCI 2.0/3.0) — dual xHCI controllers (ASM3241 + Matisse USB 3.0 ×3)

## Networking / I/O

- **enp8s0** (Intel **I225-V** Ethernet controller, rev 01) — UP, MAC `d8:5e:d3:53:fc:6c`
- **wlp7s0** (Intel **Wi-Fi 6 AX200**, `8086:2723`, rev 1a) — MAC `44:af:28:36:7d:b0` (DOWN at capture)
- **Bluetooth** radio on same AX200 (USB `8087:0029`, Bus 5)
- Remote share: `//10.0.0.1/DATA` → `/mnt/DATA`, 699 G total (265 G used / 435 G free, 38 %) — LAN (CIFS/NFS)

## OS / Kernel

- **NixOS 26.11.624** (state 25.05), Linux **7.2.8**
- Kernel params: `acpi_enforce_resources=lax amd_pstate=active snd_hda_intel power_save=1 amdgu.ppfeaturemask=0xffffffff lsm=landlock,yama,bpf initrd… init=/nix/…/nixos-system-amateur-…`
- `stateVersion 25.05`; firmware `linux-firmware` + `alsa-firmware`; kernel modules `kvm-amd` `coretemp` `it87`

## Input / Output Overview

| Type | Available I/O |
|---|---|
| **Video out** | 3× DP (DP-3 active @4K), 1× HDMI (connector), 16 Gi GDDR6 (Samsung), CEM PCB, Sapphire AIB |
| **Audio out** | GPU HDMI/DP digital (Navi HDA `0e:00.1`) + HyperX 7.1 USB (`0951:16a4`) |
| **Audio in** | HyperX 7.1 USB mic (USB 2.0, 100 mA) |
| **K/V** | Razer Seiren Mini, Keychron Q3 HE (QMK/AVR), Sunplus optical mouse, ITE RGB |
| **NET** | Intel I225-V (ethernet), Intel AX200 (Wi-Fi 6) |
| **USB host** | VIA/Terminus/Genesys/Huasheng hubs, ASM3241 + Matisse 3.0×3 + CPU USB |
| **Storage** | 3× NVMe (2 TB + 2× 1 TB Micron) + 2× 1 TB SATA (Micron C0A9) + zram 31 G |

## Notable for agent reasoning (what this machine **is**)

- AMD APU-free platform: no iGPU (CPU iGPU disabled/absent — AMD HD Audio only on GPU via `0e:00.1`)
- GPU drives all display + digital audio; CPU has **no** on-board graphics I/O
- 16 Gi VRAM + AVX2 (no AVX-512/AVX512f), 32 Gi RAM (zram swap) → high-freq dev/AI/streaming, libvirt `kvm-amd`, `coretemp` sensors
- `it87` (ITE IT87) kernel module → ITE super I/O (fan/thermal monitoring) on board
- No on-board audio capture (no mic array) beyond HyperX USB 7.1 (USB mic + 7.1 headset)
- No iDRAC/iBMC (consumer tower), no BMC
- Root encrypted (LUKS on NVMe p2), boot partition FAT, root `ext4`
