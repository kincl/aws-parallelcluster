#!/bin/bash
# Enhanced post-install script for AWS ParallelCluster
# Installs development tools, Singularity, and sets up HPL benchmarking

set -e

# Log all output
exec > >(tee -a /var/log/post-install.log)
exec 2>&1

echo "Starting enhanced post-install script at $(date)"

# Update system packages
echo "Updating system packages..."
yum update -y

# Install development tools and dependencies
echo "Installing development tools..."
yum groupinstall -y 'Development Tools'
yum install -y \
    wget \
    curl \
    git \
    htop \
    tree \
    vim \
    tmux \
    environment-modules

# Install Singularity
echo "Installing Singularity..."
yum install -y https://github.com/sylabs/singularity/releases/download/v3.10.2/singularity-ce-3.10.2-1.el7.x86_64.rpm

# Set up HPL benchmarking environment
echo "Setting up HPL benchmarking environment..."
export HPL_VER=2.3

# Create shared HPL directory
mkdir -p /shared/hpl
cd /shared/hpl

# Download HPL source
echo "Downloading HPL ${HPL_VER}..."
if [ ! -f "hpl-${HPL_VER}.tar.gz" ]; then
    wget -q "http://www.netlib.org/benchmark/hpl/hpl-${HPL_VER}.tar.gz"
    tar xfz "hpl-${HPL_VER}.tar.gz" --strip-components=1
fi

# Download Intel MKL Makefile configuration
echo "Downloading Intel MKL Makefile configuration..."
curl -Lo /shared/hpl/Make.Linux_INTEL_MKL https://raw.githubusercontent.com/qnib/plain-linpack/master/docker/make/Make.Linux_INTEL_MKL

# Update paths in Makefile
sed -i 's|/usr/local/src|/shared|' /shared/hpl/Make.Linux_INTEL_MKL

# Create build script
cat > /shared/hpl/build.sh << 'EOF'
#!/bin/bash
cd /shared/hpl
export NUM_THREADS=2
export CFLAGS="-O3 -march=native"
export HPL_VER=2.3
export LD_LIBRARY_PATH=/opt/intel/compilers_and_libraries_2019.4.243/linux/mpi/intel64/lib/release/
make arch=Linux_INTEL_MKL
EOF

chmod +x /shared/hpl/build.sh

# Create a simple job submission script for HPL
cat > /shared/hpl/submit_hpl.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=hpl-benchmark
#SBATCH --partition=xlarge
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --time=01:00:00
#SBATCH --output=hpl_%j.out
#SBATCH --error=hpl_%j.err

# Load modules
module load intelmpi

# Set environment variables
export NUM_THREADS=1
export OMP_NUM_THREADS=1

# Run HPL
cd /shared/hpl
mpirun -np $SLURM_NTASKS ./xhpl
EOF

chmod +x /shared/hpl/submit_hpl.sh

# Set up example HPL.dat file
cat > /shared/hpl/HPL.dat << 'EOF'
HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
HPL.out      output file name (if any)
6            device out (6=stdout,7=stderr,file)
1            # of problems sizes (N)
1000         Ns
1            # of NBs
192          NBs
0            PMAP process mapping (0=Row-,1=Column-major)
1            # of process grids (P x Q)
2            Ps
2            Qs
16.0         threshold
1            # of panel fact
2            PFACTs (0=left, 1=Crout, 2=Right)
1            # of recursive stopping criterium
4            NBMINs (>= 1)
1            # of panels in recursion
2            NDIVs
1            # of recursive panel fact.
2            RFACTs (0=left, 1=Crout, 2=Right)
1            # of broadcast
1            BCASTs (0=1rg,1=1rM,2=2rg,3=2rM,4=Lng,5=LnM)
1            # of lookahead depth
1            DEPTHs (>=0)
2            SWAP (0=bin-exch,1=long,2=mix)
64           swapping threshold
0            L1 in (0=transposed,1=no-transposed) form
0            U  in (0=transposed,1=no-transposed) form
1            Equilibration (0=no,1=yes)
8            memory alignment in double (> 0)
EOF

# Create environment setup script
cat > /shared/setup_env.sh << 'EOF'
#!/bin/bash
# Environment setup for HPC workloads

# Add common environment variables
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1

# Add useful aliases
alias ll='ls -la'
alias la='ls -la'
alias l='ls -CF'
alias squeue='squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R"'
alias sinfo='sinfo -o "%.20P %.5a %.10l %.6D %.6t %N"'

echo "HPC environment configured"
echo "Available compute queues:"
sinfo

echo ""
echo "To build HPL benchmark:"
echo "  cd /shared/hpl && ./build.sh"
echo ""
echo "To run HPL benchmark:"
echo "  cd /shared/hpl && sbatch submit_hpl.sh"
EOF

chmod +x /shared/setup_env.sh

# Install additional scientific computing tools
echo "Installing additional scientific tools..."
yum install -y \
    openblas-devel \
    lapack-devel \
    fftw-devel \
    hdf5-devel \
    netcdf-devel

# Create a welcome message script
cat > /etc/motd << 'EOF'
================================================================================
AWS ParallelCluster - HPC Environment
================================================================================

This cluster includes:
- Slurm job scheduler
- Development tools and compilers
- Singularity container runtime
- HPL benchmark suite in /shared/hpl
- Shared EFS storage mounted at /shared

Quick start:
  source /shared/setup_env.sh    # Set up environment
  sinfo                          # View available compute nodes
  squeue                         # View job queue

HPL Benchmark:
  cd /shared/hpl                 # Navigate to HPL directory
  ./build.sh                     # Build HPL (if not already built)
  sbatch submit_hpl.sh           # Submit HPL job

For more information: https://docs.aws.amazon.com/parallelcluster/

================================================================================
EOF

# Set permissions for shared directory
chown -R nobody:nobody /shared/hpl
chmod -R 755 /shared/hpl

# Create symlinks for easy access
ln -sf /shared/setup_env.sh /home/centos/setup_env.sh 2>/dev/null || true
ln -sf /shared/setup_env.sh /home/ec2-user/setup_env.sh 2>/dev/null || true

echo "Enhanced post-install script completed at $(date)"
echo "Log file: /var/log/post-install.log"
