{ lib, ... }:
{
  zramSwap = {
    enable = true;
    algorithm = lib.mkDefault "zstd";
    memoryPercent = lib.mkDefault 100;
  };

  # Deliberate low-latency tuning: zstd-compressed zram makes swapping cheap,
  # so evict cold anonymous pages early (swappiness=80) instead of holding
  # them in DRAM. watermark_boost_factor=15000 (default 150) kicks the
  # kworker reclaimers ahead of direct reclaim, watermark_scale_factor=10 is
  # the kernel default (explicit for clarity), page-cluster=0 disables
  # swap readahead; a large tmpfs (200%) avoids /tmp pressure while the
  # zram-based swap absorbs the rest.
  boot = {
    tmp.tmpfsSize = "200%";
    kernel.sysctl = {
      "vm.swappiness" = 80;
      "vm.watermark_boost_factor" = 15000;
      "vm.watermark_scale_factor" = 10;
      "vm.page-cluster" = 0;
    };
  };
}
