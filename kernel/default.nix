{ pkgs
, applyPatches
, lib
, fetchFromGitHub
, fetchpatch
, fetchurl
, fetchgit
, l4t-xusb-firmware
, realtime ? false
, kernelPatches ? [ ]
, structuredExtraConfig ? { }
, argsOverride ? { }
, buildLinux
, ...
}@args:

let
  isNative = pkgs.stdenv.isAarch64;
  pkgsAarch64 = if isNative then pkgs else pkgs.pkgsCross.aarch64-multiplatform;
in
buildLinux (args // {
  version = "6.6.29" + lib.optionalString realtime "-rt96";
  extraMeta.branch = "6.6";

  # defconfig = "defconfig";

  # Using applyPatches here since it's not obvious how to append an extra
  # postPatch. This is not very efficient.
  src = applyPatches {
    src = fetchgit {
      url = "https://github.com/Kamarjam/kernel-nvidia-jetson.git";
      hash = "sha256-jbw82X+EGiPHN+ZXNgkjV/KhmyXnzC8vg3iRIrC7Pvg=";
      rev = "5c75380440988ca3864bb8bd30f2794e44d05d4e";
    };

    patches = [

      (fetchpatch {
        name = "memory: tegra: Add Tegra234 clients for RCE and VI";
        url = "https://github.com/torvalds/linux/commit/9def28f3b8634e4f1fa92a77ccb65fbd2d03af34.patch";
        hash = "sha256-WZwKGL0kPZ3SxwdW3oi7Z3Tc0BMuuOuL9/HlLzg73q8=";
      })

      (fetchpatch {
        name = "hwmon: (ina3221) Add support for channel summation disable";
        url = "https://github.com/torvalds/linux/commit/7b64906c98fe503338066b97d3ff2dad65debf2b.patch";
        hash = "sha256-SB2zipFoJQsOjuKUFV8W1PBi8J8qTgdZcuPI3lNvGuA=";
      })

      (fetchpatch {
        name = "cpufreq: tegra194: save CPU data to avoid repeated SMP calls";
        url = "https://github.com/torvalds/linux/commit/6b121b4cf7e1f598beecf592d6184126b46eca46.patch";
        hash = "sha256-/v73qEkT3nrdzMDQZCbSMeacLSgj5aZTwnhvM1lFd+w=";
      })

      (fetchpatch {
        name = "cpufreq: tegra194: use refclk delta based loop instead of udelay";
        url = "https://github.com/torvalds/linux/commit/a60a556788752a5696960ed11409a552b79e68e8.patch";
        hash = "sha256-ZvogH5F3dUGHVXcpqhxbDah1Llc13J7SOYVVbJpstTw=";
      })

      (fetchpatch {
        name = "cpufreq: tegra194: remove redundant AND with cpu_online_mask";
        url = "https://github.com/torvalds/linux/commit/c12f0d0ffade589599a43b0d0f0965579ca80f76.patch";
        hash = "sha256-iiW20hwMQS/B6F1I3O5KwMdIVYrdOwSPzKrB5juaxMY=";
      })

      (fetchpatch {
        name = "fbdev/simplefb: Support memory-region property";
        url = "https://github.com/torvalds/linux/commit/8ddfc01ace51c85a2333fb9a9cbea34d9f87885d.patch";
        hash = "sha256-rMk0BIjOsc21HFF6Wx4pngnldp/LB0ODbUFGRDjtsUw=";
      })

      (fetchpatch {
        name = "fbdev/simplefb: Add support for generic power-domains";
        url = "https://github.com/torvalds/linux/commit/92a511a568e44cf11681a2223cae4d576a1a515d.patch";
        hash = "sha256-GOo7OLQObixVEKguiEzp1xLMlqE0QMQVhx8ygwkNb9M=";
      })

    ];
    # Remove device tree overlays with some incorrect "remote-endpoint" nodes.
    # They are strings, but should be phandles. Otherwise, it fails to compile
    # postPatch = ''
    #   rm \
    #     nvidia/platform/t19x/galen/kernel-dts/tegra194-p2822-camera-imx185-overlay.dts \
    #     nvidia/platform/t19x/galen/kernel-dts/tegra194-p2822-camera-dual-imx274-overlay.dts \
    #     nvidia/platform/t23x/concord/kernel-dts/tegra234-p3737-camera-imx185-overlay.dts \
    #     nvidia/platform/t23x/concord/kernel-dts/tegra234-p3737-camera-dual-imx274-overlay.dts
    #
    #   sed -i -e '/imx185-overlay/d' -e '/imx274-overlay/d' \
    #     nvidia/platform/t19x/galen/kernel-dts/Makefile \
    #     nvidia/platform/t23x/concord/kernel-dts/Makefile
    #
    # '' + lib.optionalString realtime ''
    #   for p in $(find $PWD/rt-patches -name \*.patch -type f | sort); do
    #     echo "Applying $p"
    #     patch -s -p1 < $p
    #   done
    # '';
  };
  autoModules = false;
  features = { }; # TODO: Why is this needed in nixpkgs master (but not NixOS 22.05)?

  # As of 22.11, only kernel configs supplied through kernelPatches
  # can override configs specified in the platforms
  kernelPatches = [
    # if USB_XHCI_TEGRA is built as module, the kernel won't build
   # {
   #   name = "make-USB_XHCI_TEGRA-builtins";
   #   patch = null;
   #   extraConfig = ''
   #     USB_XHCI_TEGRA y
   #   '';
   # }


    # Fix Ethernet "downshifting" (e.g.1000Base-T -> 100Base-T) with realtek
    # PHY used on Xavier NX
    # { patch = ./0007-net-phy-realtek-read-actual-speed-on-rtl8211f-to-det.patch; }

    # Lower priority of tegra-se crypto modules since they're slow and flaky
    # { patch = ./0008-Lower-priority-of-tegra-se-crypto.patch; }

    # Include patch from linux-stable that (for some reason) appears to fix
    # random crashes very early in boot process on Xavier NX specifically
    # Remove when updating to 35.5.0
    # { patch = ./0009-Revert-random-use-static-branch-for-crng_ready.patch; }

    # Fix an issue building with gcc13
    # { patch = ./0010-bonding-gcc13-synchronize-bond_-a-t-lb_xmit-types.patch; }

] ++ kernelPatches;

  structuredExtraConfig = with lib.kernel; {
    #  MODPOST modules-only.symvers
    #ERROR: modpost: "xhci_hc_died" [drivers/usb/host/xhci-tegra.ko] undefined!
    #ERROR: modpost: "xhci_hub_status_data" [drivers/usb/host/xhci-tegra.ko] undefined!
    #ERROR: modpost: "xhci_enable_usb3_lpm_timeout" [drivers/usb/host/xhci-tegra.ko] undefined!
    #ERROR: modpost: "xhci_hub_control" [drivers/usb/host/xhci-tegra.ko] undefined!
    #ERROR: modpost: "xhci_get_rhub" [drivers/usb/host/xhci-tegra.ko] undefined!
    #ERROR: modpost: "xhci_urb_enqueue" [drivers/usb/host/xhci-tegra.ko] undefined!
    #ERROR: modpost: "xhci_irq" [drivers/usb/host/xhci-tegra.ko] undefined!
    #USB_XHCI_TEGRA = module;
    #USB_XHCI_TEGRA = yes;

    # stage-1 links /lib/firmware to the /nix/store path in the initramfs.
    # However, since it's builtin and not a module, that's too late, since
    # the kernel will have already tried loading!
    EXTRA_FIRMWARE_DIR = freeform "${l4t-xusb-firmware}/lib/firmware";
    # EXTRA_FIRMWARE = freeform "nvidia/tegra194/xusb.bin";

    # Override the default CMA_SIZE_MBYTES=32M setting in common-config.nix with the default from tegra_defconfig
    # Otherwise, nvidia's driver craps out
    CMA_SIZE_MBYTES = lib.mkForce (freeform "64");

    # Platform-dependent options for mainline kernel
    ARM64_PMEM = yes;
    PCIE_TEGRA194 = yes;
    PCIE_TEGRA194_HOST = yes;
    BLK_DEV_NVME = yes;
    NVME_CORE = yes;
    FB_SIMPLE = yes;

    ### So nat.service and firewall work ###
    NF_TABLES = module; # This one should probably be in common-config.nix
    NFT_NAT = module;
    NFT_MASQ = module;
    NFT_REJECT = module;
    NFT_COMPAT = module;
    NFT_LOG = module;
    NFT_COUNTER = module;
    # IPv6 is enabled by default and without some of these `firewall.service` will explode.
    IP6_NF_MATCH_AH = module;
    IP6_NF_MATCH_EUI64 = module;
    IP6_NF_MATCH_FRAG = module;
    IP6_NF_MATCH_OPTS = module;
    IP6_NF_MATCH_HL = module;
    IP6_NF_MATCH_IPV6HEADER = module;
    IP6_NF_MATCH_MH = module;
    IP6_NF_MATCH_RPFILTER = module;
    IP6_NF_MATCH_RT = module;
    IP6_NF_MATCH_SRH = module;

    # Needed since mdadm stuff is currently unconditionally included in the initrd
    # This will hopefully get changed, see: https://github.com/NixOS/nixpkgs/pull/183314
    MD = yes;
    BLK_DEV_MD = module;
    MD_LINEAR = module;
    MD_RAID0 = module;
    MD_RAID1 = module;
    MD_RAID10 = module;
    MD_RAID456 = module;
    # Re-enable DMI (revert https://github.com/OE4T/linux-tegra-5.10/commit/bc94634fcddd594735aa9c5ca5f68b4df1cb5f8b)
    DMI = yes;
    # Additional dependences as modules
    ISO9660 = module;
    USB_UAS = module;
  } // (lib.optionalAttrs realtime {
    PREEMPT_VOLUNTARY = lib.mkForce no; # Disable the one set in common-config.nix
    # These are the options enabled/disabled by scripts/rt-patch.sh
    PREEMPT_RT = yes;
    DEBUG_PREEMPT = no;
    KVM = no;
    CPU_IDLE_TEGRA18X = no;
    CPU_FREQ_GOV_INTERACTIVE = no;
    CPU_FREQ_TIMES = no;
    FAIR_GROUP_SCHED = no;
  }) // structuredExtraConfig;

} // argsOverride)
