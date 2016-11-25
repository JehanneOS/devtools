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
	b ../port/sysproc.c:682
	commands
	printf "sys->ticks %lld ms %lld \n", sys->ticks, ms
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
	b ../port/sysproc.c:702
	commands
	if status != 0
		printf "status: %s", status
	else
		printf "status: (nil)"
	end
	log_syscall
	end

	# sysnoted
	b ../port/sysproc.c:840
	commands
	log_syscall
	end

	# sysrendezvous
	b ../port/sysproc.c:861
	commands
	printf "tag %llu rendval %llu\n", tag, rendval
	printf "sys->ticks %lld lastWakeup %lld pendingWakeup %lld \n", sys->ticks, up->lastWakeup, up->pendingWakeup
	log_syscall
	end

	# sysnotify
	b ../port/sysproc.c:820
	commands
	log_syscall
	end

	# sysnsec
	b ../port/sysproc.c:1233
	commands
	log_syscall
	end

	# syssemacquire
	b ../port/sysproc.c:1167
	commands
	log_syscall
	end

	# syssemrelease
	b ../port/sysproc.c:1222
	commands
	log_syscall
	end

	# syssleep
	b ../port/sysproc.c:640
	commands
	printf "ms %lld\n", ms
	log_syscall
	end

	# systsemacquire
	b ../port/sysproc.c:1193
	commands
	log_syscall
	end

end

define debug_awake
	# awakekproc
	b ../port/awake.c:139
	commands
		printf "%s %d ", p->text, p->pid
		printf "p->state %d p->lastWakeup %lld toAwake->time %d \n", p->state, p->lastWakeup, toAwake->time
		c
	end

	# sysawake
	b ../port/sysproc.c:682
	commands
	printf "sys->ticks %lld ms %lld \n", sys->ticks, ms
	log_syscall
	end

	# sysrendezvous
	b ../port/sysproc.c:861
	commands
	printf "ENTER: \n tag %llu rendval %llu\n", tag, rendval
	printf "sys->ticks %lld lastWakeup %lld pendingWakeup %lld \n", sys->ticks, up->lastWakeup, up->pendingWakeup
	log_syscall
	end

	# sysrendezvous
	b ../port/sysproc.c:879
	commands
	printf "EXIT on match: \n tag %llu rendval %llu\n", tag, rendval
	printf "sys->ticks %lld lastWakeup %lld pendingWakeup %lld \n", sys->ticks, up->lastWakeup, up->pendingWakeup
	log_syscall
	end

	# sysrendezvous
	b ../port/sysproc.c:886
	commands
	printf "EXIT on awaken: \n tag %llu rendval %llu\n", tag, rendval
	printf "sys->ticks %lld lastWakeup %lld pendingWakeup %lld \n", sys->ticks, up->lastWakeup, up->pendingWakeup
	log_syscall
	end

	# sysrendezvous
	b ../port/sysproc.c:902
	commands
	printf "EXIT after wait: \n tag %llu rendval %llu\n", tag, rendval
	printf "sys->ticks %lld lastWakeup %lld pendingWakeup %lld \n", sys->ticks, up->lastWakeup, up->pendingWakeup
	log_syscall
	end

end

#log_syscalls


