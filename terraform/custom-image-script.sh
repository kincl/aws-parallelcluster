#!/bin/bash

# AWS ParallelCluster Custom Image Builder Script
# This script installs additional software and configurations for HPC workloads

set -e  # Exit on any error

echo "Starting custom image build for AWS ParallelCluster"
echo "Build started at: $(date)"

# Update system packages
echo "Updating system packages..."
sudo dnf update -y

# Install additional development tools
echo "Installing Development Tools group..."
sudo dnf groupinstall -y "Development Tools"

# Install commonly used HPC packages
echo "Installing additional system packages..."
sudo dnf install -y \
    htop \
    iotop \
    git \
    wget \
    curl \
    vim \
    tmux \
    screen \
    tree \
    unzip \
    bzip2 \
    lsof \
    strace \
    tcpdump \
    nc \
    rsync \
    podman

# Install Python development packages
echo "Installing Python development packages..."
sudo dnf install -y \
    python3-pip \
    python3-devel \
    python3-wheel

# Install pip packages commonly used in HPC
# echo "Installing Python packages via pip..."
# pip3 install --user --upgrade pip
# pip3 install --user \
#     numpy \
#     scipy \
#     matplotlib \
#     pandas \
#     jupyter \
#     ipython \
#     seaborn \
#     plotly \
#     scikit-learn

# Install additional scientific computing libraries
echo "Installing additional scientific packages..."
sudo dnf install -y \
    openmpi-devel \
    lapack-devel \
    blas-devel \
    fftw-devel \
    hdf5-devel


# Install and configure NVIDIA Container Device Interface (CDI)
# echo "Installing NVIDIA CDI for lightweight GPU container support..."
# sudo dnf install -y nvidia-container-toolkit-base

# Ensure CDI directory exists
sudo mkdir -p /etc/cdi

# Configure CDI for Podman
echo "Configuring CDI for Podman..."
sudo mkdir -p /etc/containers
sudo tee -a /etc/containers/containers.conf > /dev/null <<EOF

# NVIDIA CDI configuration
[containers]
# Enable CDI device support
enable_cdi = true

[engine]
# CDI spec directories
cdi_spec_dirs = ["/etc/cdi", "/var/run/cdi"]
EOF

# Create a CDI validation script
# Create NVIDIA scripts directory
echo "Creating NVIDIA scripts directory..."
sudo mkdir -p /opt/nvidia

# Create a CDI initialization script for runtime
echo "Creating CDI runtime initialization script..."
sudo tee /opt/nvidia/init-cdi.sh > /dev/null <<'EOF'
#!/bin/bash
# Initialize NVIDIA CDI at runtime
echo "Initializing NVIDIA CDI for runtime GPU access..."

# Generate CDI spec if it doesn't exist or if GPUs are now available
if [[ ! -f /etc/cdi/nvidia.yaml ]] || [[ $(nvidia-smi -L 2>/dev/null | wc -l) -gt 0 ]]; then
    echo "Generating NVIDIA CDI specification..."
    nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml || echo "Failed to generate CDI spec"
fi

# Restart podman service to pick up CDI changes
systemctl restart podman 2>/dev/null || true

echo "NVIDIA CDI initialization complete"
EOF
sudo chmod +x /opt/nvidia/init-cdi.sh

echo "Creating CDI validation script..."
sudo tee /opt/nvidia/validate-cdi.sh > /dev/null <<'EOF'
#!/bin/bash
echo "Validating NVIDIA CDI setup..."

# Initialize CDI first
/opt/nvidia/init-cdi.sh

echo "CDI spec files:"
ls -la /etc/cdi/ 2>/dev/null || echo "No CDI specs found"
echo "Available CDI devices:"
nvidia-ctk cdi list 2>/dev/null || echo "CDI list not available"
echo "CDI validation complete"
EOF
sudo chmod +x /opt/nvidia/validate-cdi.sh

# Create systemd service for automatic CDI initialization
echo "Creating systemd service for automatic CDI initialization..."
sudo tee /etc/systemd/system/nvidia-cdi-init.service > /dev/null <<'EOF'
[Unit]
Description=Initialize NVIDIA CDI for GPU containers
After=multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=/opt/nvidia/init-cdi.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable the service to run at boot
# echo "Enabling NVIDIA CDI initialization service..."
# sudo systemctl enable nvidia-cdi-init.service

# Create a GPU test script
echo "Creating GPU test script..."
sudo tee /opt/nvidia/test-gpu.sh > /dev/null <<'EOF'
#!/bin/bash
echo "Testing GPU availability..."
nvidia-smi || echo "nvidia-smi not available"
echo "Testing CUDA availability..."
nvcc --version || echo "CUDA compiler not available"
echo "Testing container GPU access with CDI..."
podman run --rm --device nvidia.com/gpu=all nvidia/cuda:11.8-runtime-ubi9 nvidia-smi || echo "CDI GPU access not available"
echo "Validating CDI configuration..."
/opt/nvidia/validate-cdi.sh || echo "CDI validation not available"
EOF
sudo chmod +x /opt/nvidia/test-gpu.sh

# # Create shared directories with proper permissions
# echo "Creating shared directories..."
# sudo mkdir -p /shared/apps
# sudo mkdir -p /shared/data
# sudo mkdir -p /shared/scripts
# sudo mkdir -p /shared/modules
# sudo chmod 755 /shared/apps /shared/data /shared/scripts /shared/modules

# # Set up environment modules if available
# if command -v module &> /dev/null; then
#     echo "Environment modules already available"
# else
#     echo "Installing Environment Modules..."
#     sudo dnf install -y environment-modules
# fi

# # Create a simple module for custom installations
# sudo mkdir -p /shared/modules/modulefiles
# cat << 'EOF' | sudo tee /shared/modules/modulefiles/custom-tools > /dev/null
# #%Module1.0
# ##
# ## Custom tools module
# ##
# proc ModulesHelp { } {
#     puts stderr "Custom tools and utilities for HPC workloads"
# }

# module-whatis "Custom tools and utilities"

# prepend-path PATH /shared/apps/bin
# prepend-path LD_LIBRARY_PATH /shared/apps/lib
# prepend-path MANPATH /shared/apps/man
# EOF

# # Set up useful aliases and environment
# echo "Setting up global environment..."
# cat << 'EOF' | sudo tee /etc/profile.d/pcluster-custom.sh > /dev/null
# # Custom ParallelCluster environment setup

# # Useful aliases
# alias ll='ls -alF'
# alias la='ls -A'
# alias l='ls -CF'
# alias h='history'
# alias grep='grep --color=auto'

# # Environment variables for HPC
# export OMP_NUM_THREADS=1
# export MKL_NUM_THREADS=1

# # Add shared apps to PATH
# if [ -d "/shared/apps/bin" ]; then
#     export PATH="/shared/apps/bin:$PATH"
# fi

# # Add shared libraries to LD_LIBRARY_PATH
# if [ -d "/shared/apps/lib" ]; then
#     export LD_LIBRARY_PATH="/shared/apps/lib:${LD_LIBRARY_PATH}"
# fi

# # Module setup
# if [ -f "/usr/share/Modules/init/bash" ]; then
#     source /usr/share/Modules/init/bash
#     module use /shared/modules/modulefiles
# fi
# EOF

# # Set up vim configuration for all users
# echo "Setting up vim configuration..."
# cat << 'EOF' | sudo tee /etc/vimrc.local > /dev/null
# " Custom vim configuration for HPC environment
# syntax on
# set number
# set tabstop=4
# set shiftwidth=4
# set expandtab
# set hlsearch
# set incsearch
# set showmatch
# set ruler
# set wildmenu
# EOF

# Install Intel oneAPI if needed (commented out by default)
# echo "Installing Intel oneAPI Base Toolkit..."
# wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
# echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
# sudo apt update
# sudo apt install -y intel-basekit

# Install Conda for user package management (optional)
# echo "Installing Miniconda..."
# wget -O /tmp/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
# bash /tmp/miniconda.sh -b -p /shared/apps/miniconda3
# rm /tmp/miniconda.sh

# Set up a sample job submission script template
echo "Creating job template..."
sudo mkdir -p /opt/templates
cat << 'EOF' | sudo tee /opt/templates/sample-job.sh > /dev/null
#!/bin/bash
#SBATCH --job-name=sample_job
#SBATCH --output=sample_job_%j.out
#SBATCH --error=sample_job_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=01:00:00
#SBATCH --partition=debug

echo "Job started at: $(date)"
echo "Running on node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"

# Your job commands here
echo "Hello from ParallelCluster!"

echo "Job completed at: $(date)"
EOF
sudo chmod +x /opt/templates/sample-job.sh


# Create GPU job template
echo "Creating GPU job template..."
cat << 'EOF' | sudo tee /opt/templates/gpu-job.sh > /dev/null
#!/bin/bash
#SBATCH --job-name=gpu_job
#SBATCH --output=gpu_job_%j.out
#SBATCH --error=gpu_job_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --time=01:00:00
#SBATCH --partition=gpu

echo "Job started at: $(date)"
echo "Running on node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo "GPU allocation: $CUDA_VISIBLE_DEVICES"

# Test GPU availability
nvidia-smi

# Your GPU job commands here
echo "Hello from GPU ParallelCluster!"

echo "Job completed at: $(date)"
EOF
sudo chmod +x /opt/templates/gpu-job.sh

# Clean up package cache to reduce image size
echo "Cleaning up package cache..."
sudo dnf clean all

# Create a build info file
echo "Creating build information file..."
cat << EOF | sudo tee /opt/build-info.txt > /dev/null
Custom ParallelCluster Image Build Information
==============================================
Build Date: $(date)
Built by: AWS ParallelCluster Image Builder
Base OS: RHEL 9

Installed Packages:
- Development Tools
- Python 3 with pip
- OpenMPI, LAPACK, BLAS, FFTW, HDF5
- Container runtime: Podman
- Monitoring tools: htop, iotop, glances, nvtop (if GPU)
- Additional utilities: git, vim, tmux, screen, tree, etc.

Available Templates:
- /opt/templates/sample-job.sh (Basic SLURM job)
- /opt/templates/gpu-job.sh (GPU SLURM job)
- /opt/nvidia/pytorch-container.sh (PyTorch container wrapper with CDI)
- /opt/nvidia/tensorflow-container.sh (TensorFlow container wrapper with CDI)
- /opt/nvidia/test-gpu.sh (GPU testing script)
- /opt/nvidia/validate-cdi.sh (CDI configuration validation)
- /opt/nvidia/init-cdi.sh (CDI runtime initialization)
- /opt/nvidia/nvidia-utils.sh (NVIDIA utility management)

Available NVIDIA Commands (via aliases):
- nvidia-test    - Run GPU tests
- nvidia-validate - Validate CDI setup
- nvidia-init    - Initialize CDI
- nvidia-utils   - NVIDIA utility manager
EOF

echo "Custom image build completed successfully at: $(date)"
echo "Build log available in CloudWatch Logs"
