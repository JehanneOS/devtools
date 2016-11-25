/enable_execute_stack=enable-execute-stack-empty.c;/,/Configuration ${host} not supported/{
	/^case ${host} in$/r ../patch/gcc/libgcc/config.host
}
