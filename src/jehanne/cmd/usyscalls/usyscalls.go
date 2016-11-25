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
	"strings"
	"text/template"
)

const gplHeader string = `/*
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
/* automatically generated by usyscalls */
`

type SyscallConf struct {
	Ret     []string
	Args    []string
	Name    string
	Id      uint32
}

type Sysconf struct {
	Syscalls  []SyscallConf
}

type SyscallWrapper struct {
	Id			uint32
	Name    	string
	FuncArgs	string
	MacroArgs	string
	VarValues	[]string
	Vars		[]string
	AsmArgs		string
	AsmClobbers	string
	RetType		string
}

type HeaderCode struct {
	Wrappers		[]SyscallWrapper
}


func usage(msg string) {
	fmt.Fprint(os.Stderr, msg)
	fmt.Fprint(os.Stderr, "Usage: usyscalls header|code path/to/sysconf.json\n")
	flag.PrintDefaults()
	os.Exit(1)
}

func argTypeName(t string) string{
	switch(t){
	case "int", "int32_t":
		return "i"
	case "unsigned int", "uint32_t":
		/* unsigned int is reserved for flags */
		return "ui"
	case "long", "int64_t":
		return "l"
	case "unsigned long", "uint64_t":
		return "ul"
	case "void*", "uint8_t*", "const void*", "const uint8_t*":
		return "p"
	case "int32_t*", "int*", "const int32_t*", "const int*":
		return "p"
	case "const char*", "char*":
		return "p"
	case "const char**", "char**":
		return "p"
	}
	return " [?? " + t + "]"

}

func argRegister(index int, t string) string{
	prefix := ""
	switch(t){
		case "int", "unsigned int", "uint32_t", "int32_t":
			prefix = "e"
		default:
			prefix = "r"
	}
	switch(index){
		case 0:
			return prefix + "di";
		case 1:
			return prefix + "si";
		case 2:
			return prefix + "dx";
		case 3:
			return "r10";
		case 4:
			return "r8";
		case 5:
			return "r9";
	}
	return ""
}

func getHeaderData(calls []SyscallConf) *HeaderCode {
	code := new(HeaderCode)
	for _, call := range(calls) {
		wcall := new(SyscallWrapper)
		wcall.Id = call.Id
		wcall.Name = call.Name
		wcall.RetType = call.Ret[0]

		clobberMemory := false
		wcall.AsmClobbers = "\"cc\", \"rcx\", \"r11\""
		wcall.AsmArgs = fmt.Sprintf("\"0\"(%d)", wcall.Id)
		for i, a := range(call.Args){
			if i > 0 {
				wcall.FuncArgs += ", "
				wcall.MacroArgs += ", "
			}
			if strings.HasSuffix(a, "*") && !strings.HasPrefix(a, "const"){
				clobberMemory = true
			}
			wcall.FuncArgs += fmt.Sprintf("%s a%d", a, i) 
			wcall.MacroArgs += fmt.Sprintf("/* %s */ a%d", a, i)
			wcall.VarValues = append(wcall.VarValues, fmt.Sprintf("_sysargs[%d].%s = (a%d); \\\n\t", i, argTypeName(a), i))
			wcall.Vars = append(wcall.Vars, fmt.Sprintf("register %s __r%d asm(\"%s\") = _sysargs[%d].%s; \\\n\t", a, i, argRegister(i, a), i, argTypeName(a)))
			wcall.AsmArgs += fmt.Sprintf(", \"r\"(__r%d)", i)
		}
		if clobberMemory {
			wcall.AsmClobbers += ", \"memory\""
		}
		code.Wrappers = append(code.Wrappers, *wcall)
	}

	return code	
}

func generateSyscallTable(calls []SyscallConf){
	code := getHeaderData(calls)
	tmpl, err := template.New("tab.c").Parse(`
{{ range .Wrappers }}"{{ .Name }}", (int(*)()) {{ .Name }},
{{ end }}
`)
	err = tmpl.Execute(os.Stdout, code)
	if err != nil {
		log.Fatal(err)
	}
}

func generateLibcCode(calls []SyscallConf){
	code := getHeaderData(calls)
	tmpl, err := template.New("syscalls.c").Parse(gplHeader + `
#define PORTABLE_SYSCALLS
#include <u.h>

{{ range .Wrappers }}
{{ .RetType }}
{{ .Name }}({{ .FuncArgs }})
{
	register {{ .RetType }} __ret asm ("rax");
	__asm__ __volatile__ (
		"movq %%rcx, %%r10" "\n\t"
		"movq ${{ .Id }}, %%rax" "\n\t"
		"syscall"
		: "=r" (__ret)
		: /* args are ready */
		: {{ .AsmClobbers }}
	);
	return __ret;
}
{{ end }}
`)
	err = tmpl.Execute(os.Stdout, code)
	if err != nil {
		log.Fatal(err)
	}
}

func generateSyscallHeader(calls []SyscallConf){
	funcMap := template.FuncMap{
        "title": strings.Title,
    }
	code := getHeaderData(calls)
	tmpl, err := template.New("syscall.h").Funcs(funcMap).Parse(gplHeader + `
typedef enum Syscalls
{
{{ range .Wrappers }}	Sys{{ .Name|title }} = {{ .Id }},
{{ end }}} Syscalls;

#ifndef KERNEL
{{ range .Wrappers }}
#define sys_{{ .Name }}({{ .MacroArgs }}) ({ \
	{{ range .VarValues }}{{.}}{{end}}{{ range .Vars }}{{.}}{{end}}register {{ .RetType }} __ret asm ("rax"); \
	__asm__ __volatile__ ( \
		"syscall" \
		: "=&r" (__ret) \
		: {{ .AsmArgs }} \
		: {{ .AsmClobbers }} \
	); \
	__ret; })
{{ end }}

#ifdef PORTABLE_SYSCALLS

{{ range .Wrappers }}extern {{ .RetType }} {{ .Name }}({{ .FuncArgs }});
{{ end }}
extern int32_t read(int, void*, int32_t);
extern int32_t write(int, const void*, int32_t);

#else

{{ range .Wrappers }}# define {{ .Name }}(...) sys_{{ .Name }}(__VA_ARGS__)
{{ end }}
#define read(fd, buf, size) pread(fd, buf, size, -1)
#define write(fd, buf, size) pwrite(fd, buf, size, -1)

#endif

#endif
`)
	err = tmpl.Execute(os.Stdout, code)
	if err != nil {
		log.Fatal(err)
	}
}

func main() {

	flag.Parse()

	if flag.NArg() != 2 {
		usage("no path to sysconf.json")
	}
	
	buf, err := ioutil.ReadFile(flag.Arg(1))
	if err != nil {
		log.Fatal(err)
	}

	var sysconf Sysconf
	err = json.Unmarshal(buf, &sysconf)
	if err != nil {
		log.Fatal(err)
	}
	mode := flag.Arg(0)
	switch(mode){
		case "header":
			generateSyscallHeader(sysconf.Syscalls)
			break
		case "code":
			generateLibcCode(sysconf.Syscalls)
			break
		case "tab":
			generateSyscallTable(sysconf.Syscalls)
			break
	}
	
	

}