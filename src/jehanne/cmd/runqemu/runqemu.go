// Run commands received from stdin in qemu
//
// -p prompt	=> prompt to expect (default "10.0.2.15#")
//
// ENVIRONMENT
// Needed: JEHANNE
package main

import (
	"bufio"
	"fmt"
	"flag"
	"os"
	"os/exec"
	"strings"
	"github.com/creack/pty"
	"golang.org/x/crypto/ssh/terminal"
)

func main() {
	var prompt string
	flag.StringVar(&prompt, "p", "10.0.2.15#", "the prompt to expect")
	flag.Parse()
	jehanne := os.Getenv("JEHANNE")
	if jehanne == "" {
		fmt.Printf("usage: cat cmds.rc | runqemu [-p prompt]\n")
		fmt.Printf("error: missing $JEHANNE\n");
		os.Exit(1)
	}
	if terminal.IsTerminal(0) {
		fmt.Printf("usage: cat cmds.rc | runqemu [-p prompt]\n")
		fmt.Printf("error: runqemu is intended for automation, pipe commands in.\n")
		os.Exit(1)
	}

	qemuCmd := "cd $JEHANNE/arch/amd64/kern && $JEHANNE/hacking/QA.sh\n"
	qemuCmd = os.ExpandEnv(qemuCmd)

	sh := exec.Command("/bin/sh")
	qemu, err := pty.Start(sh)
	if err != nil {
		fmt.Printf("REGRESS start (%s): %s", qemuCmd, err)
		os.Exit(2)
	}
	qemu.WriteString(qemuCmd)
	defer qemu.Close()

	exitStatus := 0

	qemuInput  := make(chan string)
	qemuOutputRaw := make(chan string)
	wait := make(chan int)

	scanner := bufio.NewScanner(os.Stdin)

	go func() {
		qemuOut := make([]byte, 256)
		for {
			r, err := qemu.Read(qemuOut)
			if err != nil {
				fmt.Fprintln(os.Stderr, "error:", err)
				wait <- 3
			}
			qemuOutputRaw <- string(qemuOut[0:r])
		}
	}()
	go func(){
		line := ""
		for {
			s := <- qemuOutputRaw
			line += s
			if strings.Contains(line, prompt) {
				if scanner.Scan() {
					cmd	:= scanner.Text()
					qemuInput <- fmt.Sprintf("%s\n", cmd)
				} else {
					if err := scanner.Err(); err != nil {
						fmt.Fprintln(os.Stderr, "error:", err)
						wait <- 4
				    } else {
						wait <- exitStatus
					}
					return
				}
				fmt.Printf("%s", line)
				line = ""
			} else if strings.ContainsAny(line, "\r\n") {
				if strings.Contains(line, "FAIL") {
					exitStatus = 5
				}
				fmt.Printf("%s", line)
				line = ""
			}
		}
	}()
	go func(){
		for {
			s := <- qemuInput
			i := 0;
			for {
				n, err := qemu.WriteString(s[i:])
				if err != nil {
					fmt.Fprintln(os.Stderr, "error:", err)
					wait <- 6
				}
				i += n
				if i == len(s) {
					break
				}
			}
		}
	}()

	e := <- wait
	if e == 0 {
		fmt.Printf("\nDone.\n")
	}
	os.Exit(e)
}
