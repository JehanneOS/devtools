set pagination off
set logging file ../qemu-gdb.log
set logging overwrite on
set logging on

define log_mach_proc
	if up != 0 
		printf "%s %d ", up->text, up->pid
	end
	if m != 0
		printf "(mach %d) ", m->machno
	end
end

define log_syscall
	log_mach_proc
	printf "\n"
	c
end

define log_syscalls

	# sysbind
	b ../port/sysfile.c:1167
	commands
	log_syscall
	end

	# syschdir
	b ../port/sysfile.c:1027
	commands
	log_syscall
	end

	# sysclose
	b ../port/sysfile.c:375
	commands
	log_syscall
	end

	# syscreate
	b ../port/sysfile.c:1263
	commands
	log_syscall
	end

	# sysdup
	b ../port/sysfile.c:263
	commands
	log_syscall
	end

	# sysfd2path
	b ../port/sysfile.c:191
	commands
	log_syscall
	end

	# sysfstat
	b ../port/sysfile.c:999
	commands
	log_syscall
	end

	# sysfwstat
	b ../port/sysfile.c:1371
	commands
	log_syscall
	end

	# sysmount
	b ../port/sysfile.c:1192
	commands
	log_syscall
	end

	# sysopen
	b ../port/sysfile.c:311
	commands
	log_syscall
	end

	# syspipe
	b ../port/sysfile.c:214
	commands
	log_syscall
	end

	# syspread
	b ../port/sysfile.c:787
	commands
	log_syscall
	end

	# syspwrite
	b ../port/sysfile.c:857
	commands
	log_syscall
	end

	# sysremove
	b ../port/sysfile.c:1293
	commands
	log_syscall
	end

	# sysseek
	b ../port/sysfile.c:929
	commands
	log_syscall
	end

	# sysunmount
	b ../port/sysfile.c:1210
	commands
	log_syscall
	end

	# sysfversion
	b ../port/sysauth.c:50
	commands
	log_syscall
	end

	# sysfauth
	b ../port/sysauth.c:83
	commands
	log_syscall
	end

	# sysrfork
	b ../port/sysproc.c:36
	commands
	log_syscall
	end

	# sysalarm
	b ../port/sysproc.c:656
	commands
	log_syscall
	end

	# sysawake
	b ../port/sysproc.c:673
	commands
	log_syscall
	end

	# sysawait
	b ../port/sysproc.c:729
	commands
	log_syscall
	end

	# syserrstr
	b ../port/sysproc.c:791
	commands
	log_syscall
	end

	# sysnotify
	b ../port/sysproc.c:809
	commands
	log_syscall
	end

	# sysexec
	b ../port/sysproc.c:284
	commands
	log_syscall
	end

	# sysexits
	b ../port/sysproc.c:691
	commands
	log_syscall
	end

	# sysnoted
	b ../port/sysproc.c:829
	commands
	log_syscall
	end

	# sysrendezvous
	b ../port/sysproc.c:851
	commands
	log_syscall
	end

	# sysnotify
	b ../port/sysproc.c:809
	commands
	log_syscall
	end

	# sysnsec
	b ../port/sysproc.c:1215
	commands
	log_syscall
	end

	# syssemacquire
	b ../port/sysproc.c:1150
	commands
	log_syscall
	end

	# syssemrelease
	b ../port/sysproc.c:1204
	commands
	log_syscall
	end

	# syssleep
	b ../port/sysproc.c:629
	commands
	log_syscall
	end

	# systsemacquire
	b ../port/sysproc.c:1177
	commands
	log_syscall
	end

end

#log_syscalls


