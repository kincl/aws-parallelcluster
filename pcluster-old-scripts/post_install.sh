#!/bin/bash
yum update -y
yum groupinstall -y 'Development Tools'
yum install -y https://github.com/sylabs/singularity/releases/download/v3.10.2/singularity-ce-3.10.2-1.el7.x86_64.rpm
