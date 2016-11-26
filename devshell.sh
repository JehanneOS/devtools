#!/bin/bash
export JEHANNE=`git rev-parse --show-toplevel`
export PATH="$JEHANNE/hacking/bin:$PATH"
export PATH="$JEHANNE/hacking/cross/toolchain/bin:$PATH"
export ARCH=amd64

export TOOLPREFIX=x86_64-jehanne-

bash --rcfile <(cat ~/.bashrc; echo 'PS1="JehanneDEV $PS1"')
