// +build !jehanne

package main

import (
	"log"
	"os"
	"os/exec"
	"strings"
)

func init() {
	jehanne = os.Getenv("JEHANNE")
	if jehanne != "" {
		return
	}
	// git is purely optional, for lazy people.
	out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err == nil {
		jehanne = strings.TrimSpace(string(out))
		hackingAt := strings.LastIndex("/hacking", jehanne)
		if(hackingAt >= 0){
			jehanne = jehanne[0:hackingAt]
		}
	}
	if jehanne == "" {
		log.Fatal("Set the JEHANNE environment variable or run from a git checkout.")
	}

	os.Setenv("PATH", strings.Join([]string{fromRoot("/hacking"), os.Getenv("PATH")}, string(os.PathListSeparator)))
}
