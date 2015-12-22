// +build jehanne

package main

import (
	"os"
	"strings"
)

func init() {
	jehanne = os.Getenv("JEHANNE")
	if jehanne != "" {
		return
	}
	jehanne = "/"
	os.Setenv("path", strings.Join([]string{fromRoot("/util"), os.Getenv("path")}, string(os.PathListSeparator)))
}
