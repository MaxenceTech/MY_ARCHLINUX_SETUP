# Hardware Acceleration & OpenCL Configuration Guide

## Overview

This guide focuses specifically on enabling and optimizing hardware acceleration features for your Intel i7-14650HX + RTX 4080 system. Your existing setup already includes excellent Vulkan support - this extends it with compute acceleration and advanced media features.

## Current Hardware Acceleration Status ✅

Your scripts already include:
- ✅ Intel media driver for hardware video decoding
- ✅ Vulkan support for both Intel and NVIDIA
- ✅ NVIDIA open drivers with optimal configuration
- ✅ Mesa drivers with lib32 support

## OpenCL Setup and Configuration

### 1. Install OpenCL Runtime Components

```bash
# Core OpenCL support
sudo pacman -S intel-compute-runtime opencl-nvidia ocl-icd

# Intel Level Zero for modern compute workloads
sudo pacman -S level-zero-loader intel-level-zero-gpu

# Development headers (optional, for building OpenCL applications)
sudo pacman -S opencl-headers

# Verification tools
sudo pacman -S clinfo
```

### 2. Verify OpenCL Installation

```bash
# List all OpenCL platforms and devices
clinfo

# Expected output should show:
# - Intel(R) OpenCL HD Graphics (integrated GPU)
# - NVIDIA CUDA (RTX 4080)

# Test basic OpenCL functionality
clinfo --list

# Quick benchmark (if available)
yay -S clpeak
clpeak
```

### 3. Configure OpenCL Device Priority

Create an OpenCL configuration to prioritize the RTX 4080 for compute tasks:

```bash
# Create OpenCL vendor configuration
sudo mkdir -p /etc/OpenCL/vendors

# Configure NVIDIA as primary compute device
echo "libnvidia-opencl.so.1" | sudo tee /etc/OpenCL/vendors/nvidia.icd

# Ensure Intel is available as secondary
echo "libintelocl.so" | sudo tee /etc/OpenCL/vendors/intel.icd

# Set environment variable for default device (optional)
echo 'export OPENCL_VENDOR_PATH=/etc/OpenCL/vendors' | sudo tee -a /etc/environment
```

## Advanced Video Acceleration

### 1. Enhanced Video Codec Support

```bash
# AV1 hardware acceleration (supported by RTX 4080)
sudo pacman -S svt-av1 dav1d libaom

# Enhanced H.264/H.265 support
sudo pacman -S x264 x265 libde265

# Intel QuickSync additional support
sudo pacman -S intel-media-sdk onevpl-intel-gpu

# VA-API to VDPAU bridge for older applications
sudo pacman -S libva-vdpau-driver vdpauinfo
```

### 2. Configure Hardware Video Acceleration

```bash
# Test VA-API (Intel integrated graphics)
vainfo

# Test VDPAU (NVIDIA)
vdpauinfo

# For browsers - enable hardware acceleration
# Add to your browser configuration:
echo "
# For Firefox hardware acceleration
MOZ_X11_EGL=1
MOZ_DISABLE_RDD_SANDBOX=1

# For Chromium-based browsers
CHROME_FLAGS='--enable-gpu-rasterization --enable-zero-copy --enable-hardware-overlays --use-gl=desktop'
" | sudo tee -a /etc/environment
```

### 3. Video Encoding Optimization

```bash
# Install video encoding tools
sudo pacman -S ffmpeg obs-studio

# Install NVIDIA-specific encoding tools
yay -S nvidia-video-codec-sdk

# Test NVENC encoding capability
ffmpeg -hide_banner -encoders | grep nvenc

# Test QuickSync encoding capability  
ffmpeg -hide_banner -encoders | grep qsv
```

## GPU Compute Optimization

### 1. CUDA Setup for Compute Workloads

```bash
# Install CUDA toolkit
sudo pacman -S cuda cuda-tools

# Install cuDNN for deep learning (if needed)
yay -S cudnn

# Add CUDA to PATH
echo 'export PATH="/opt/cuda/bin:$PATH"
export CUDA_HOME="/opt/cuda"
export LD_LIBRARY_PATH="/opt/cuda/lib64:$LD_LIBRARY_PATH"' >> ~/.bashrc

# Verify CUDA installation
nvidia-smi
nvcc --version
```

### 2. Intel GPU Compute Configuration

```bash
# Intel GPU tools for monitoring and control
sudo pacman -S intel-gpu-tools

# Enable Intel GPU performance monitoring
echo 'dev.i915.perf_stream_paranoid = 0' | sudo tee /etc/sysctl.d/99-intel-gpu.conf

# Intel GPU compute metrics
intel_gpu_top

# Intel GPU frequency information
cat /sys/class/drm/card0/gt_cur_freq_mhz
cat /sys/class/drm/card0/gt_max_freq_mhz
```

### 3. GPU Memory Optimization

```bash
# Optimize GPU memory management
echo "
# GPU memory optimizations
vm.zone_reclaim_mode = 0
vm.page_lock_unfairness = 1

# NVIDIA GPU memory settings
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/tmp
" | sudo tee /etc/sysctl.d/99-gpu-memory.conf

# Update module configuration
sudo tee -a /etc/modprobe.d/nvidia.conf << 'EOF'
# Memory preservation and performance
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_EnableStreamMemOPs=1
EOF
```

## Application-Specific Acceleration

### 1. Blender GPU Rendering

```bash
# Install Blender with CUDA/OpenCL support
sudo pacman -S blender

# Configure Blender for GPU rendering
mkdir -p ~/.config/blender/
echo "
# Blender GPU preferences
import bpy
bpy.context.preferences.addons['cycles'].preferences.compute_device_type = 'CUDA'
bpy.context.preferences.addons['cycles'].preferences.devices[0].use = True
" > ~/.config/blender/enable_gpu.py
```

### 2. Machine Learning Frameworks

```bash
# PyTorch with CUDA support
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# TensorFlow with GPU support
pip install tensorflow[and-cuda]

# Verify GPU support in Python
python3 -c "
import torch
print(f'PyTorch CUDA available: {torch.cuda.is_available()}')
print(f'CUDA device count: {torch.cuda.device_count()}')
if torch.cuda.is_available():
    print(f'Current CUDA device: {torch.cuda.get_device_name(0)}')
"
```

### 3. Gaming and Graphics Applications

```bash
# GPU-accelerated image/video editors
sudo pacman -S krita darktable
yay -S davinci-resolve

# GPU-accelerated emulators
sudo pacman -S yuzu-mainline-git dolphin-emu
yay -S rpcs3-git pcsx2-git

# Configure emulators for Vulkan/OpenGL acceleration
# Most modern emulators will auto-detect your GPU capabilities
```

## Performance Monitoring and Tuning

### 1. GPU Monitoring Tools

```bash
# Install comprehensive GPU monitoring
sudo pacman -S nvtop radeontop intel-gpu-tools
yay -S gpu-viewer

# Create GPU monitoring script
echo '#!/bin/bash
echo "=== GPU Status ==="
nvidia-smi -q -d TEMPERATURE,POWER,CLOCK,UTILIZATION | grep -E "(Temperature|Power|Graphics|Memory|Gpu)"
echo ""
echo "=== Intel GPU Status ==="
intel_gpu_top -s 1000 -o - | head -20
' | sudo tee /usr/local/bin/gpu-status.sh
sudo chmod +x /usr/local/bin/gpu-status.sh
```

### 2. Automated Performance Profiles

```bash
# Create GPU performance profiles
echo '#!/bin/bash
case "$1" in
    compute)
        # Optimize for compute workloads
        nvidia-smi -pm 1  # Enable persistence mode
        nvidia-smi -acp UNRESTRICTED  # Remove power limits
        echo performance | sudo tee /sys/class/drm/card0/gt_rps_control_act_freq_mhz
        ;;
    gaming)
        # Optimize for gaming (already handled by your scripts)
        nvidia-smi -pm 1
        echo performance | sudo tee /sys/class/drm/card0/gt_rps_control_act_freq_mhz
        ;;
    power-save)
        # Power saving mode
        nvidia-smi -pm 0
        echo powersave | sudo tee /sys/class/drm/card0/gt_rps_control_act_freq_mhz
        ;;
esac
' | sudo tee /usr/local/bin/gpu-profile.sh
sudo chmod +x /usr/local/bin/gpu-profile.sh
```

## Troubleshooting Common Issues

### 1. OpenCL Device Not Detected

```bash
# Check OpenCL installation
ls -la /etc/OpenCL/vendors/
clinfo --list

# Reinstall OpenCL components if needed
sudo pacman -Rs intel-compute-runtime opencl-nvidia
sudo pacman -S intel-compute-runtime opencl-nvidia

# Check for conflicting drivers
lsmod | grep -E "(nvidia|i915)"
```

### 2. Hardware Video Acceleration Not Working

```bash
# Check VA-API support
vainfo

# Check VDPAU support
vdpauinfo

# Verify browser hardware acceleration
# In Firefox: about:support -> Graphics section
# In Chrome: chrome://gpu/
```

### 3. Performance Issues

```bash
# Check GPU memory usage
nvidia-smi

# Check thermal throttling
nvidia-smi -q -d TEMPERATURE
sensors

# Monitor GPU utilization during workloads
watch -n 1 nvidia-smi
```

## Integration with Existing Setup

### 1. Enhance Your GameMode Configuration

Add GPU compute optimization to your existing GameMode config:

```ini
# Add to /etc/gamemode.ini under [custom] section
start=notify-send "GameMode started"
    sudo /usr/local/bin/power-detect -f
    sudo /usr/local/bin/gpu-profile.sh gaming

end=notify-send "GameMode ended"
    sudo /usr/local/bin/power-detect
    sudo /usr/local/bin/gpu-profile.sh power-save
```

### 2. Enhance Power Management Scripts

Add GPU power management to your existing ACPI scripts:

```bash
# Add to /etc/acpi/SCRIPT/a-plug.sh
/usr/local/bin/gpu-profile.sh gaming

# Add to /etc/acpi/SCRIPT/a-unplug.sh  
/usr/local/bin/gpu-profile.sh power-save
```

## Testing and Validation

### 1. OpenCL Benchmark

```bash
# Install and run OpenCL benchmarks
yay -S luxmark clpeak

# Test compute performance
clpeak
luxmark
```

### 2. Video Acceleration Test

```bash
# Test hardware video decoding
ffmpeg -hwaccel vaapi -i input.mp4 -c:v h264_vaapi output.mp4  # Intel
ffmpeg -hwaccel nvdec -i input.mp4 -c:v h264_nvenc output.mp4  # NVIDIA

# Benchmark encoding performance
time ffmpeg -i input.mkv -c:v h264_nvenc -preset fast output_nvenc.mp4
time ffmpeg -i input.mkv -c:v h264_qsv -preset fast output_qsv.mp4
```

### 3. Gaming Acceleration Verification

```bash
# Verify Vulkan support
vulkaninfo | grep -i device

# Test OpenGL performance
glxinfo | grep -i render
glxgears

# Monitor GPU usage during gaming
nvidia-smi dmon -s pucvmet
```

## Maintenance and Updates

### 1. Keep Drivers Updated

```bash
# Regular driver updates
sudo pacman -Syu nvidia-open nvidia-utils intel-compute-runtime

# Update CUDA if using
sudo pacman -Syu cuda
```

### 2. Monitor Hardware Health

```bash
# Create monitoring cron job
echo '#!/bin/bash
# GPU health check
nvidia-smi --query-gpu=temperature.gpu,power.draw,utilization.gpu --format=csv >> /var/log/gpu-health.log
' | sudo tee /usr/local/bin/gpu-health-check.sh
sudo chmod +x /usr/local/bin/gpu-health-check.sh

# Add to crontab to run every hour
echo "0 * * * * /usr/local/bin/gpu-health-check.sh" | sudo crontab -
```

This configuration will give you comprehensive hardware acceleration support for gaming, content creation, machine learning, and general compute workloads while building upon your already excellent foundation.