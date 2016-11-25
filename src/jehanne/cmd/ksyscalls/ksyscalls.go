/*
 * This file is part of Jehanne.
 *
 * Copyright (C) 2016 Giacomo Tesio <giacomo@tesio.it>
 *
 * Jehanne is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License.
 *
 * Jehanne is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Jehanne.  If not, see <http://www.gnu.org/licenses/>.
 */
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"text/template"
)

type SyscallConf struct {
	Ret     []string
	Args    []string
	Name    string
	Id      uint32
}

type Sysconf struct {
	Syscalls  []SyscallConf
}

func usage(msg string) {
	fmt.Fprint(os.Stderr, msg)
	fmt.Fprint(os.Stderr, "Usage: ksyscalls path/to/sysconf.json\n")
	flag.PrintDefaults()
	os.Exit(1)
}

type SyscallWrapper struct {
	Id			uint32
	Name    	string
	Vars		[]string
	CommonCode	string
	ExecCode	string
	EntryPrint	string
	ExitPrint	string
	SysRetField	string
	DefaultRet	string
}

type KernelCode struct {
	Externs			[]string
	Wrappers		[]SyscallWrapper
}

func uregArg(index int) string{
	switch(index){
		case 0:
			return "di";
		case 1:
			return "si";
		case 2:
			return "dx";
		case 3:
			return "r10";
		case 4:
			return "r8";
		case 5:
			return "r9";
	}
	return ""
}

func sysret(t string) string {
	switch(t){
	case "int", "int32_t":
		return "i"
	case "long", "int64_t":
		return "vl"
	case "uintptr_t", "void":
		return "p"
	case "void*", "char*", "char**", "uint8_t*", "int32_t*", "uint64_t*", "int64_t*":
		return "v"
	}
	return " [?? " + t + "]"
}

func formatArg(i int, t string) string{
	switch(t){
	case "int", "int32_t":
		return fmt.Sprintf("\tfmtprint(fmt, \" %%d\", a%d);\n", i)
	case "unsigned int", "uint32_t":
		/* unsigned int is reserved for flags */
		return fmt.Sprintf("\tfmtprint(fmt, \" %%#ux\", a%d);\n", i)
	case "long", "int64_t":
		return fmt.Sprintf("\tfmtprint(fmt, \" %%lld\", a%d);\n", i)
	case "unsigned long", "uint64_t":
		return fmt.Sprintf("\tfmtprint(fmt, \" %%#lud\", a%d);\n", i)
	case "void*", "uint8_t*", "const void*", "const uint8_t*":
		return fmt.Sprintf("\tfmtprint(fmt, \" %%#p\", a%d);\n", i)
	case "int32_t*", "int*", "const int32_t*", "const int*":
		return fmt.Sprintf("\tfmtprint(fmt, \" %%#p(%%d)\", a%d, a%d);\n", i, i)
	case "const char*", "char*":
		return fmt.Sprintf("\tfmtuserstring(fmt, a%d);\n", i)
	case "const char**", "char**":
		return fmt.Sprintf("\tfmtuserstringlist(fmt, a%d);\n", i);
	}
	return " [?? " + t + "]"
}

func formatRet(t string) string{
	switch(t){
	case "int", "int32_t":
		return fmt.Sprintf("\tfmtprint(fmt, \" %%d\", ret->%s);\n", sysret(t))
	case "unsigned int", "uint32_t":
		/* unsigned int is reserved for flags */
		return fmt.Sprintf("\tfmtprint(fmt, \" %%#ux\", ret->%s);\n", sysret(t))
	case "long", "int64_t":
		return fmt.Sprintf("\tfmtprint(fmt, \" %%lld\", ret->%s);\n", sysret(t))
	case "unsigned long", "uint64_t", "void":
		return fmt.Sprintf("\tfmtprint(fmt, \" %%#llud\", ret->%s);\n", sysret(t))
	case "void*", "uintptr_t", "const void*", "const uintptr_t":
		return fmt.Sprintf("\tfmtprint(fmt, \" %%#p\", ret->%s);\n", sysret(t))
	case "int32_t*", "int*",  "const int32_t*", "const int*":
		return fmt.Sprintf("\tfmtprint(fmt, \" %%#p(%%d)\", ret->%s, *ret->%s);\n", sysret(t), sysret(t))
	}
	return " [?? " + t + "]"
}

func generateKernelCode(calls []SyscallConf){
	code := new(KernelCode)
	
	for _, call := range(calls) {
		/* extern definitions */
		ext := "extern " + call.Ret[0] + " sys" + call.Name + "("
		if len(call.Args) == 0 {
			ext += "void";
		} else {
			for i, a := range(call.Args){
				if i > 0 {
					ext += ", "
				}
				ext += fmt.Sprintf("%s", a)
			}
		}
		ext += ");\n"

		wcall := new(SyscallWrapper)
		wcall.Id = call.Id
		wcall.Name = call.Name
		wcall.SysRetField = sysret(call.Ret[0])
		wcall.DefaultRet = fmt.Sprintf("ret.%s = (%s)-1;", wcall.SysRetField, call.Ret[0])

		for i, a := range(call.Args){
			wcall.Vars = append(wcall.Vars, fmt.Sprintf("%s a%v;",  a, i))
			wcall.CommonCode += fmt.Sprintf("\ta%v = (%s)ureg->%s;\n", i,  a, uregArg(i))
		}
		wcall.ExecCode += "\tret->" + wcall.SysRetField + " = sys" + call.Name + "("
		for i, _ := range(call.Args){
			if i > 0 {
				wcall.ExecCode += ", "
			}
			wcall.ExecCode += fmt.Sprintf("a%v", i)
		}
		wcall.ExecCode += ");"
		
		if call.Name == "pwrite"{
			wcall.EntryPrint += formatArg(0, call.Args[0])
			wcall.EntryPrint += "\tfmtrwdata(fmt, (char*)a1, MIN(a2, 64));\n"
			wcall.EntryPrint += formatArg(2, call.Args[2])
			wcall.EntryPrint += formatArg(3, call.Args[3])
		} else {
			for i, a := range(call.Args){
				wcall.EntryPrint += formatArg(i, a)
			}
		}

		wcall.ExitPrint += formatRet(call.Ret[0])
		if call.Name == "pread"{
			wcall.ExitPrint += fmt.Sprintf("\tfmtrwdata(fmt, (char*)ureg->%s, MIN(ureg->%s, 64));\n", uregArg(1), uregArg(2))
		}

		code.Wrappers = append(code.Wrappers, *wcall)
		code.Externs = append(code.Externs, ext)
	}
	
	tmpl, err := template.New("systab.c").Parse(`/*
 * This file is part of Jehanne.
 *
 * Copyright (C) 2016 Giacomo Tesio <giacomo@tesio.it>
 *
 * Jehanne is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License.
 *
 * Jehanne is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Jehanne.  If not, see <http://www.gnu.org/licenses/>.
 */
/* automatically generated by ksyscalls */
#include "u.h"
#include "../port/lib.h"
#include "mem.h"
#include "dat.h"
#include "fns.h"
#include "../port/error.h"
#include "ureg.h"

extern void fmtrwdata(Fmt* f, char* a, int n);
extern void fmtuserstring(Fmt* f, const char* a);
extern void fmtuserstringlist(Fmt* f, const char** argv);

{{ range .Externs }}{{.}}{{ end }}
{{ range .Wrappers }}
static void
wrap_{{ .Name }}(ScRet* ret, Ureg* ureg)
{
	{{ range .Vars }}{{.}}
	{{ end }}
{{ .CommonCode }}
{{ .ExecCode }}
}
{{ end }}
int nsyscall = {{len .Wrappers}};

ScRet
default_syscall_ret(int syscall)
{
	static ScRet zero;
	ScRet ret = zero;
	switch(syscall){
	{{ range .Wrappers }}case {{ .Id }}:
		{{ .DefaultRet }}
		break;
	{{ end }}
	default:
		ret.vl = -1;
		break;
	}
	return ret;
}

char*
syscall_name(int syscall)
{
	switch(syscall){
	{{ range .Wrappers }}case {{ .Id }}:
		return "{{ .Name }}";
	{{ end }}
	default:
		return nil;
	}
}

void
dispatch_syscall(int syscall, Ureg* ureg, ScRet* ret)
{
	switch(syscall){
	{{ range .Wrappers }}case {{ .Id }}:
		wrap_{{ .Name }}(ret, ureg);
		break;
	{{ end }}
	default:
		panic("dispatch_syscall: bad sys call number %d pc %#p\n", syscall, ureg->ip);
	}
}

{{ range .Wrappers }}
static void
enter_{{ .Name }}(Fmt* fmt, Ureg* ureg)
{
	{{ range .Vars }}{{.}}
	{{ end }}
{{ .CommonCode }}
	fmtprint(fmt, "{{ .Name }} %#p > ", ureg->ip);
{{ .EntryPrint }}
}
{{ end }}

char*
syscallfmt(int syscall, Ureg* ureg)
{
	Fmt fmt;
	fmtstrinit(&fmt);
	fmtprint(&fmt, "%d %s ", up->pid, up->text);

	switch(syscall){
	{{ range .Wrappers }}case {{ .Id }}:
		enter_{{ .Name }}(&fmt, ureg);
		break;
	{{ end }}
	default:
		panic("syscallfmt: bad sys call number %d pc %#p\n", syscall, ureg->ip);
	}

	return fmtstrflush(&fmt);
}

{{ range .Wrappers }}
static void
exit_{{ .Name }}(Fmt* fmt, Ureg* ureg, ScRet* ret)
{
	fmtprint(fmt, "{{ .Name }} %#p < ", ureg->ip);
{{ .ExitPrint }}
}
{{ end }}

char*
sysretfmt(int syscall, Ureg* ureg, ScRet* ret, uint64_t start, uint64_t stop)
{
	Fmt fmt;
	fmtstrinit(&fmt);
	fmtprint(&fmt, "%d %s ", up->pid, up->text);

	switch(syscall){
	{{ range .Wrappers }}case {{ .Id }}:
		exit_{{ .Name }}(&fmt, ureg, ret);
		break;
	{{ end }}
	default:
		panic("sysretfmt: bad sys call number %d pc %#p\n", syscall, ureg->ip);
	}

	if(0 > ret->vl){
		fmtprint(&fmt, " %s %#llud %#llud\n", up->syserrstr, start, stop-start);
	} else {
		fmtprint(&fmt, " \"\" %#llud %#llud\n", start, stop-start);
	}

	return fmtstrflush(&fmt);
}

`)
	err = tmpl.Execute(os.Stdout, code)
	if err != nil {
		log.Fatal(err)
	}
}

func main() {

	flag.Parse()

	if flag.NArg() != 1 {
		usage("no path to sysconf.json")
	}
	
	buf, err := ioutil.ReadFile(flag.Arg(0))
	if err != nil {
		log.Fatal(err)
	}

	var sysconf Sysconf
	err = json.Unmarshal(buf, &sysconf)
	if err != nil {
		log.Fatal(err)
	}

	generateKernelCode(sysconf.Syscalls)

}