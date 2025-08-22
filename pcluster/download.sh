#!/bin/bash

mkdir -p /shared/hpl
cd /shared/hpl
echo ">> wget -q http://www.netlib.org/benchmark/hpl/hpl-${HPL_VER}.tar.gz" \
 && wget -qO- http://www.netlib.org/benchmark/hpl/hpl-${HPL_VER}.tar.gz |tar xfz - --strip-components=1

curl -Lo /shared/hpl/Make.Linux_INTEL_MKL https://raw.githubusercontent.com/qnib/plain-linpack/master/docker/make/Make.Linux_INTEL_MKL

sed -i 's|/usr/local/src|/shared|' /shared/hpl/Make.Linux_INTEL_MKL
