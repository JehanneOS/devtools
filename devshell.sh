#!/bin/bash
export JEHANNE=`git rev-parse --show-toplevel`
export PATH="$JEHANNE/hacking/bin:$PATH"
export ARCH=amd64

bash --rcfile <(cat ~/.bashrc; echo 'PS1="JehanneDEV $PS1"')
