# Partition table - ZTE Blade V40 Vita (P606F02), UMS9230 / UFS

Exactly as the device reported it through `spd_dump` while sitting in BROM.

* Storage: **UFS**.
* `splloader` is index 0 - a fixed 256 KB region holding the SPL, the chip's first-stage
  bootloader. `spd_dump` prints it in the list but handles it specially, and it's the
  partition the unlock flow deliberately erases in step 1.
* The tool reports `Total number of partitions: 67` even though it enumerates 0..67; don't
  read too much into the count, the list below is what's actually there.
* Active slot at unlock time: **`_b`**.
* There is **no `recovery` partition** - this is a VAB device, recovery is the
  recovery ramdisk inside the `boot` image.
* `super` is the dynamic-partition container; system / vendor / product live inside
  it as logical partitions.
* `userdata` is the rest of the flash, ~110 GiB.
* `miscdata` holds the bootloader unlock token at offset **8192** (32 B string +
  16 B hash + 16 B hash == unlocked; all zeros == locked).
* `metadata` holds the FBE key blobs - erasing it is what fixes the post-unlock
  boot hang (see the README).

| # | partition | size |
|---:|:---|---:|
| 0 | `splloader` | 256KB |
| 1 | `prodnv` | 10MB |
| 2 | `miscdata` | 1MB |
| 3 | `misc` | 1MB |
| 4 | `trustos_a` | 6MB |
| 5 | `trustos_b` | 6MB |
| 6 | `sml_a` | 1MB |
| 7 | `sml_b` | 1MB |
| 8 | `uboot_a` | 3MB |
| 9 | `uboot_b` | 3MB |
| 10 | `uboot_log` | 4MB |
| 11 | `logo_a` | 20MB |
| 12 | `logo_b` | 20MB |
| 13 | `fbootlogo` | 8MB |
| 14 | `l_fixnv1_a` | 2MB |
| 15 | `l_fixnv2_a` | 2MB |
| 16 | `l_fixnv1_b` | 2MB |
| 17 | `l_fixnv2_b` | 2MB |
| 18 | `l_runtimenv1` | 2MB |
| 19 | `l_runtimenv2` | 2MB |
| 20 | `gnssmodem_a` | 1MB |
| 21 | `gnssmodem_b` | 1MB |
| 22 | `wcnmodem_a` | 10MB |
| 23 | `wcnmodem_b` | 10MB |
| 24 | `persist` | 2MB |
| 25 | `ztecfg` | 8MB |
| 26 | `ztepersist` | 32MB |
| 27 | `l_modem_a` | 25MB |
| 28 | `l_modem_b` | 25MB |
| 29 | `l_deltanv_a` | 1MB |
| 30 | `l_deltanv_b` | 1MB |
| 31 | `l_gdsp_a` | 10MB |
| 32 | `l_gdsp_b` | 10MB |
| 33 | `l_ldsp_a` | 20MB |
| 34 | `l_ldsp_b` | 20MB |
| 35 | `l_agdsp_a` | 6MB |
| 36 | `l_agdsp_b` | 6MB |
| 37 | `pm_sys_a` | 1MB |
| 38 | `pm_sys_b` | 1MB |
| 39 | `teecfg_a` | 1MB |
| 40 | `teecfg_b` | 1MB |
| 41 | `boot_a` | 64MB |
| 42 | `boot_b` | 64MB |
| 43 | `vendor_boot_a` | 100MB |
| 44 | `vendor_boot_b` | 100MB |
| 45 | `dtb_a` | 8MB |
| 46 | `dtb_b` | 8MB |
| 47 | `dtbo_a` | 8MB |
| 48 | `dtbo_b` | 8MB |
| 49 | `super` | 5900MB |
| 50 | `cache` | 100MB |
| 51 | `socko_a` | 75MB |
| 52 | `socko_b` | 75MB |
| 53 | `odmko_a` | 25MB |
| 54 | `odmko_b` | 25MB |
| 55 | `vbmeta_a` | 1MB |
| 56 | `vbmeta_b` | 1MB |
| 57 | `metadata` | 16MB |
| 58 | `sysdumpdb` | 10MB |
| 59 | `vbmeta_system_a` | 1MB |
| 60 | `vbmeta_system_b` | 1MB |
| 61 | `vbmeta_vendor_a` | 1MB |
| 62 | `vbmeta_vendor_b` | 1MB |
| 63 | `vbmeta_system_ext_a` | 1MB |
| 64 | `vbmeta_system_ext_b` | 1MB |
| 65 | `vbmeta_product_a` | 1MB |
| 66 | `vbmeta_product_b` | 1MB |
| 67 | `userdata` | 112351MB |
