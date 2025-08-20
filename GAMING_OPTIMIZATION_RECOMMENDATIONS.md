# Arch Linux Gaming & Performance Optimization Recommendations

## Analysis Summary

Your Arch Linux installation script already includes an excellent foundation for gaming and performance optimization. This document provides additional recommendations to further enhance system performance, gaming experience, and hardware acceleration capabilities.

## Current Excellent Features (Already Implemented)

✅ **GameMode with custom configuration**  
✅ **NVIDIA open drivers with runtime power management**  
✅ **Custom NVIDIA overclocking on boot**  
✅ **Vulkan support for Intel and NVIDIA**  
✅ **ZSWAP with LZ4 compression**  
✅ **PCI latency timer optimization**  
✅ **MSI-EC integration for performance profiles**  
✅ **Power-aware display refresh rate switching (240Hz/60Hz)**  
✅ **CPU governor switching based on power state**  
✅ **VM optimizations for gaming**  
✅ **SSD TRIM enabled**  

---

## Additional Optimization Recommendations

### 1. Hardware Acceleration Enhancements

#### OpenCL Setup (GPU Compute)
```bash
# Install OpenCL support for both Intel and NVIDIA
sudo pacman -S intel-compute-runtime opencl-nvidia ocl-icd clinfo

# Verify OpenCL installation
clinfo

# For machine learning and compute workloads
sudo pacman -S level-zero-loader intel-level-zero-gpu
```

#### Additional Video Codec Support
```bash
# Enhanced video acceleration
sudo pacman -S intel-media-sdk libva-intel-driver libva-mesa-driver
sudo pacman -S libva-vdpau-driver vdpauinfo libvdpau-va-gl

# AV1 hardware acceleration (modern Intel/NVIDIA)
sudo pacman -S svt-av1 dav1d

# Verify hardware acceleration
vainfo
vdpauinfo
```

### 2. Gaming Performance Enhancements

#### Additional Gaming Packages
```bash
# Proton/Wine optimizations
sudo pacman -S wine-staging winetricks lutris bottles
yay -S protonup-qt

# Windows compatibility layers
sudo pacman -S lib32-gnutls lib32-ldconfig lib32-sqlite lib32-openal
sudo pacman -S lib32-mpg123 lib32-giflib lib32-libpng lib32-gnutls

# Gaming utilities
yay -S mangohud goverlay replay-sorcery obs-studio-git
yay -S corectrl gpu-screen-recorder-git

# Anticheat compatibility (when available)
yay -S game-devices-udev
```

#### Advanced Memory/CPU Tuning
```bash
# Create /etc/sysctl.d/99-gaming.conf
echo "
# Gaming-specific optimizations
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2
vm.dirty_expire_centisecs = 1000
vm.dirty_writeback_centisecs = 1000

# Network stack for gaming
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000

# Reduce swapping
vm.page-cluster = 0
vm.vfs_cache_pressure = 50

# Memory defragmentation
vm.compaction_proactiveness = 0
" | sudo tee /etc/sysctl.d/99-gaming.conf

# I/O scheduler optimization for NVMe SSDs
echo 'ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="none"' | sudo tee /etc/udev/rules.d/99-nvme-scheduler.rules
```

#### Audio Latency Optimization (Beyond Current Setup)
```bash
# Additional PipeWire optimizations
echo "
[context.modules]
context.modules = [
    {   name = libpipewire-module-rtkit
        args = {
            nice.level   = -11
            rt.prio      = 20
            rt.time.soft = 200000
            rt.time.hard = 200000
        }
        flags = [ ifexists nofail ]
    }
]
" | sudo tee /etc/pipewire/pipewire.conf.d/99-lowlatency.conf

# Real-time audio group setup (if not already done)
sudo usermod -aG realtime $USER
```

### 3. Display and Graphics Optimizations

#### FreeSync/G-Sync Setup
```bash
# Enable adaptive sync for compatible displays
# Add to your display configuration or create a script:
echo '#!/bin/bash
# Enable adaptive sync on compatible displays
for output in $(xrandr --listmonitors | grep -o "eDP-[0-9]*\|DP-[0-9]*\|HDMI-[0-9]*"); do
    xrandr --output $output --set "adaptive-sync" 1 2>/dev/null || true
done' | sudo tee /usr/local/bin/enable-adaptive-sync.sh
sudo chmod +x /usr/local/bin/enable-adaptive-sync.sh
```

#### HDR Support (Experimental)
```bash
# HDR support packages (experimental)
yay -S hdr-layer gamescope-git

# Test HDR capabilities
sudo pacman -S libdisplay-info
```

### 4. CPU Performance Tuning

#### CPU Frequency Scaling Enhancements
```bash
# Install CPU frequency utilities
sudo pacman -S cpupower thermald

# Create custom CPU performance script
echo '#!/bin/bash
# Enhanced CPU performance script
case "$1" in
    performance)
        # Maximum performance
        sudo cpupower frequency-set -g performance
        echo 0 | sudo tee /sys/devices/system/cpu/cpu*/power/energy_perf_bias
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
        echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
        ;;
    balanced)
        # Balanced performance
        sudo cpupower frequency-set -g schedutil
        echo 6 | sudo tee /sys/devices/system/cpu/cpu*/power/energy_perf_bias
        echo balance_performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
        echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
        ;;
    powersave)
        # Power saving (already implemented in your a-unplug.sh)
        sudo cpupower frequency-set -g powersave
        echo 15 | sudo tee /sys/devices/system/cpu/cpu*/power/energy_perf_bias
        echo power | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
        ;;
esac' | sudo tee /usr/local/bin/cpu-performance.sh
sudo chmod +x /usr/local/bin/cpu-performance.sh
```

### 5. Monitoring and Diagnostics Tools

#### Performance Monitoring
```bash
# System monitoring for gaming
sudo pacman -S htop btop nvtop iotop
yay -S auto-cpufreq mission-center

# GPU monitoring and overclocking
yay -S nvidia-system-monitor-qt
sudo pacman -S radeontop # For AMD users

# Gaming-specific monitoring overlay
# MangoHud configuration already recommended above
echo "
cpu_temp
gpu_temp
cpu_power
gpu_power
cpu_mhz
gpu_core_clock
gpu_mem_clock
fps
frametime
frame_timing
position=top-left
toggle_hud=Shift_R+F12
" > ~/.config/MangoHud/MangoHud.conf
```

### 6. Network Optimization for Gaming

#### Gaming Network Tweaks
```bash
# Network optimizations for gaming
echo "
# Gaming network optimizations
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_mtu_probing = 1

# Reduce network latency
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
" | sudo tee /etc/sysctl.d/98-network-gaming.conf

# Gaming DNS optimization (low latency DNS)
echo "
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
nameserver 8.8.4.4
" | sudo tee /etc/resolv.conf.gaming

# Script to switch to gaming DNS
echo '#!/bin/bash
if [ "$1" == "gaming" ]; then
    sudo cp /etc/resolv.conf.gaming /etc/resolv.conf
    echo "Switched to gaming DNS"
else
    sudo systemctl restart systemd-resolved
    echo "Restored default DNS"
fi' | sudo tee /usr/local/bin/gaming-dns.sh
sudo chmod +x /usr/local/bin/gaming-dns.sh
```

### 7. Storage Performance

#### Additional SSD Optimizations
```bash
# Enhanced SSD mount options in /etc/fstab
# Add these options to your SSD partitions:
# defaults,noatime,discard=async,space_cache=v2,compress=zstd:1

# SSD optimization service
echo '#!/bin/bash
# SSD optimization script
echo mq-deadline | tee /sys/block/nvme*/queue/scheduler 2>/dev/null || true
echo 0 | tee /sys/block/nvme*/queue/add_random 2>/dev/null || true
echo 1 | tee /sys/block/nvme*/queue/nomerges 2>/dev/null || true

# Optimize readahead for gaming
echo 256 | tee /sys/block/nvme*/queue/read_ahead_kb 2>/dev/null || true
' | sudo tee /usr/local/bin/ssd-optimize.sh
sudo chmod +x /usr/local/bin/ssd-optimize.sh

# Create systemd service for SSD optimization
echo '[Unit]
Description=SSD Gaming Optimizations
After=sysinit.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ssd-optimize.sh

[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/ssd-optimize.service

sudo systemctl enable ssd-optimize.service
```

### 8. Gaming-Specific Tweaks

#### Enhance Your Existing GameMode Configuration
Add these sections to your existing `/etc/gamemode.ini`:

```ini
[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
nv_powermizer_mode=1
nv_core_clock_mhz_offset=100
nv_mem_clock_mhz_offset=500

[custom]
start=notify-send "GameMode started"
    sudo /usr/local/bin/power-detect -f
    sudo /usr/local/bin/gaming-dns.sh gaming
    sudo /usr/local/bin/cpu-performance.sh performance

end=notify-send "GameMode ended"
    sudo /usr/local/bin/power-detect
    sudo /usr/local/bin/gaming-dns.sh default
    sudo /usr/local/bin/cpu-performance.sh balanced
```

#### Windows Game Compatibility
```bash
# Enhanced Wine/Proton setup
yay -S wine-tkg-staging-fsync-git wine-gecko wine-mono

# Install vcredist and other Windows dependencies
winetricks -q vcrun2022 vcrun2019 vcrun2017 vcrun2015 vcrun2013 vcrun2012 vcrun2010 vcrun2008 vcrun2005
winetricks -q dotnet48 dotnetfx4 corefonts

# DirectX and gaming libraries
winetricks -q d3dx9 d3dx10 d3dx11_43 dxvk
```

### 9. Security Optimizations for Gaming

#### Kernel Security vs Performance Balance
```bash
# Create a gaming-specific kernel command line
# Add this to your existing boot entries in /boot/loader/entries/
# For maximum gaming performance, you can add:
# spectre_v2=off spec_store_bypass_disable=off l1tf=off nospec_store_bypass_disable mds=off tsx_async_abort=off mitigations=off

# Note: Only use these security disable flags on gaming systems that are not mission-critical
```

### 10. Virtualization Gaming Enhancements

#### Enhance Your Existing QEMU/KVM Setup
```bash
# Additional virtualization gaming packages
yay -S virt-manager-git looking-glass-obs-plugin

# CPU pinning script for gaming VMs
echo '#!/bin/bash
# CPU pinning for gaming VM
# Isolate cores for VM (adjust based on your CPU)
echo "1-7,9-15" | sudo tee /sys/fs/cgroup/cpuset/machine.slice/cpuset.cpus
echo "0,8" | sudo tee /sys/fs/cgroup/cpuset/system.slice/cpuset.cpus
' | sudo tee /usr/local/bin/vm-cpu-pin.sh
sudo chmod +x /usr/local/bin/vm-cpu-pin.sh

# Hugepages optimization for gaming VMs
echo "vm.nr_hugepages = 8192" | sudo tee /etc/sysctl.d/99-hugepages.conf
```

## Implementation Priority

### High Priority (Immediate Impact)
1. OpenCL setup for GPU compute
2. MangoHud overlay for performance monitoring
3. Additional gaming package installation
4. Network optimization for gaming

### Medium Priority (Noticeable Improvements)
1. Audio latency optimizations
2. Enhanced CPU frequency scaling
3. Storage optimization enhancements
4. Wine/Proton compatibility packages

### Low Priority (Marginal Gains)
1. Security vs performance trade-offs
2. Advanced virtualization tweaks
3. Experimental HDR support
4. Custom kernel compilation

## Testing and Validation

After implementing these optimizations:

1. **Benchmark your system** with tools like:
   - `unigine-heaven` or `unigine-superposition`
   - `glxgears` and `vkmark`
   - Steam's built-in FPS counter
   - MangoHud overlay

2. **Monitor temperatures** during gaming:
   - Use `sensors` command
   - Monitor with `nvtop` for GPU temps
   - Check thermal throttling

3. **Test gaming performance**:
   - Frame time consistency
   - Input latency
   - Load times

## Maintenance Scripts

Create a maintenance script to keep optimizations active:

```bash
echo '#!/bin/bash
# Gaming system maintenance script

# Update gaming-related packages
yay -Syu --noconfirm

# Refresh GPU optimizations
sudo systemctl restart nvidia-oc.service 2>/dev/null || true

# Clear gaming caches
rm -rf ~/.cache/nvidia/
rm -rf ~/.nv/

# Defrag gaming directories if on ext4
find ~/Games ~/.steam ~/.local/share/Steam -type f -name "*.db" -exec sqlite3 {} "VACUUM;" \; 2>/dev/null || true

echo "Gaming optimizations refreshed!"
' | sudo tee /usr/local/bin/gaming-maintenance.sh
sudo chmod +x /usr/local/bin/gaming-maintenance.sh
```

## Conclusion

Your current setup already provides an excellent foundation for gaming on Arch Linux. These additional optimizations can provide incremental improvements in performance, compatibility, and user experience. Implement them gradually and test the impact of each change to ensure stability while maximizing gaming performance.