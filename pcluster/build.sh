#!/bin/bash
cd /shared/hpl
export NUM_THREADS=2
export CFLAGS="-O3 -march=native" 
export HPL_VER=2.3
export LD_LIBRARY_PATH=/opt/intel/compilers_and_libraries_2019.4.243/linux/mpi/intel64/lib/release/
make arch=Linux_INTEL_MKL
