// Build builds code as directed by json files.
// We slurp in the JSON, and recursively process includes.
// At the end, we issue a single cc command for all the files.
// Compilers are fast.
//
// ENVIRONMENT
//
// Needed: JEHANNE, ARCH
//
// JEHANNE should point to a Jehanne root.
// Currently only "amd64" is a valid ARCH.
// A best-effort to autodetect the Jehanne root is made if not explicitly set.
//
// Optional: CC, AR, LD, RANLIB, STRIP, SH, TOOLPREFIX
//
// These all control how the needed tools are found.
//
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

type kernconfig struct {
	Code []string
	Dev  []string
	Ip   []string
	Link []string
	Sd   []string
	Uart []string
	VGA  []string
}

type kernel struct {
	CodeFile string
	Systab   string
	Config   kernconfig
	Ramfiles map[string]string
}

type build struct {
	// jsons is unexported so can not be set in a .json file
	jsons map[string]bool
	path  string
	name  string
	// Projects name a whole subproject which is built independently of
	// this one. We'll need to be able to use environment variables at some point.
	Projects    []string
	Pre         []string
	Post        []string
	Cflags      []string
	Oflags      []string
	Include     []string
	SourceFiles []string
	ObjectFiles []string
	Libs        []string
	Env         []string
	// cmd's
	SourceFilesCmd []string
	// Targets.
	Program string
	Library string
	Install string // where to place the resulting binary/lib
	Kernel  *kernel
}

type buildfile map[string]build

// UnmarshalJSON works like the stdlib unmarshal would, except it adjusts all
// paths.
func (bf *buildfile) UnmarshalJSON(s []byte) error {
	r := make(map[string]build)
	if err := json.Unmarshal(s, &r); err != nil {
		return err
	}
	for k, b := range r {
		// we're getting a copy of the struct, remember.
		b.jsons = make(map[string]bool)
		b.Projects = adjust(b.Projects)
		b.Libs = adjust(b.Libs)
		b.Cflags = adjust(b.Cflags)
		b.SourceFiles = b.SourceFiles
		b.SourceFilesCmd = b.SourceFilesCmd
		b.ObjectFiles = b.ObjectFiles
		b.Include = adjust(b.Include)
		b.Install = fromRoot(b.Install)
		for i, e := range b.Env {
			b.Env[i] = os.ExpandEnv(e)
		}
		r[k] = b
	}
	*bf = r
	return nil
}

var (
	cwd       string
	jehanne    string
	regexpAll = []*regexp.Regexp{regexp.MustCompile(".")}

	// findTools looks at all env vars and absolutizes these paths
	// also respects TOOLPREFIX
	tools = map[string]string{
		"cc":     "gcc",
		"ar":     "ar",
		"ld":     "ld",
		"ranlib": "ranlib",
		"strip":  "strip",
		"sh":     "sh",
	}
	arch = map[string]bool{
		"amd64": true,
	}
	debugPrint = flag.Bool("debug", false, "enable debug prints")
	shellhack  = flag.Bool("shellhack", false, "spawn every command in a shell (forced on if LD_PRELOAD is set)")
)

func debug(fmt string, s ...interface{}) {
	if *debugPrint {
		log.Printf(fmt, s...)
	}
}

// fail with message, if err is not nil
func failOn(err error) {
	if err != nil {
		log.Fatalf("%v\n", err)
	}
}

func isValueInList(value string, list []string) bool {
	for _, v := range list {
		if v == value {
			return true
		}
	}
	return false
}

func adjust(s []string) []string {
	for i, v := range s {
		s[i] = fromRoot(v)
	}
	return s
}

func buildEnv(b *build) func(string) string{
	return func(v string) string {
		search := v + "="
		for _, s := range b.Env {
			if strings.Index(s, search) == 0 {
				return strings.Replace(s, search, "", 1)
			}
		}
		return os.Getenv(v)
	}
}

// return the given absolute path as an absolute path rooted at the jehanne tree.
func fromRoot(p string) string {
	p = os.ExpandEnv(p)
	if path.IsAbs(p) {
		return path.Join(jehanne, p)
	}
	return p
}

// Sh sends cmd to a shell. It's needed to enable $LD_PRELOAD tricks,
// see https://github.com/Harvey-OS/jehanne/issues/8#issuecomment-131235178
func sh(cmd *exec.Cmd) {
	shell := exec.Command(tools["sh"])
	shell.Env = cmd.Env

	if cmd.Args[0] == tools["sh"] && cmd.Args[1] == "-c" {
		cmd.Args = cmd.Args[2:]
	}
	commandString := strings.Join(cmd.Args, " ")
	if shStdin, e := shell.StdinPipe(); e == nil {
		go func() {
			defer shStdin.Close()
			io.WriteString(shStdin, commandString)
		}()
	} else {
		log.Fatalf("cannot pipe [%v] to %s: %v", commandString, tools["sh"], e)
	}
	shell.Stderr = os.Stderr
	shell.Stdout = os.Stdout

	debug("%q | sh\n", commandString)
	failOn(shell.Run())
}

func mergeKernel(k *kernel, defaults *kernel) *kernel {
	if k == nil {
		return defaults
	}
	if defaults == nil {
		return k
	}

	// The custom kernel Code will be added after the default from includes
	// so that it has a chance to change de default behaviour.
	k.Config.Code = append(defaults.Config.Code, k.Config.Code...)

	k.Config.Dev = append(k.Config.Dev, defaults.Config.Dev...)
	k.Config.Ip = append(k.Config.Ip, defaults.Config.Ip...)
	k.Config.Link = append(k.Config.Link, defaults.Config.Link...)
	k.Config.Sd = append(k.Config.Sd, defaults.Config.Sd...)
	k.Config.Uart = append(k.Config.Uart, defaults.Config.Uart...)
	k.Config.VGA = append(k.Config.VGA, defaults.Config.VGA...)

	if k.CodeFile == "" {
		k.CodeFile = defaults.CodeFile
	}
	if k.Systab == "" {
		k.Systab = defaults.Systab
	}
	for name, path := range defaults.Ramfiles {
		if _, ok := k.Ramfiles[name]; ok == false {
			k.Ramfiles[name] = path
		}
	}

	return k
}

func include(f string, b *build) {
	if b.jsons[f] {
		return
	}
	b.jsons[f] = true
	log.Printf("Including %v", f)
	d, err := ioutil.ReadFile(f)
	failOn(err)
	var builds buildfile
	failOn(json.Unmarshal(d, &builds))

	for n, build := range builds {
		log.Printf("Merging %v", n)
		b.SourceFiles = append(b.SourceFiles, build.SourceFiles...)
		b.Cflags = append(b.Cflags, build.Cflags...)
		b.Oflags = append(b.Oflags, build.Oflags...)
		b.Pre = append(b.Pre, build.Pre...)
		b.Post = append(b.Post, build.Post...)
		b.Libs = append(b.Libs, build.Libs...)
		b.Projects = append(b.Projects, build.Projects...)
		b.Env = append(b.Env, build.Env...)
		b.SourceFilesCmd = append(b.SourceFilesCmd, build.SourceFilesCmd...)
		b.Program += build.Program
		b.Library += build.Library
		b.Kernel = mergeKernel(b.Kernel, build.Kernel)
		if build.Install != "" {
			if b.Install != "" {
				log.Fatalf("In file %s (target %s) included by %s (target %s): redefined Install.", f, n, build.path, build.name)
			}
			b.Install = build.Install
		}
		b.ObjectFiles = append(b.ObjectFiles, build.ObjectFiles...)
		// For each source file, assume we create an object file with the last char replaced
		// with 'o'. We can get smarter later.
		for _, v := range build.SourceFiles {
			f := path.Base(v)
			o := f[:len(f)-1] + "o"
			b.ObjectFiles = append(b.ObjectFiles, o)
		}

		for _, v := range build.Include {
			if !path.IsAbs(v) {
				wd := path.Dir(f)
				v = path.Join(wd, v)
			}
			include(v, b)
		}
	}
}

func appendIfMissing(s []string, v string) []string {
	for _, a := range s {
		if a == v {
			return s
		}
	}
	return append(s, v)
}

func process(f string, r []*regexp.Regexp) []build {
	log.Printf("Processing %v", f)
	var builds buildfile
	var results []build
	d, err := ioutil.ReadFile(f)
	failOn(err)
	failOn(json.Unmarshal(d, &builds))

	// Sort keys alphabetically (GoLang does not preserve the JSON order)
	var keys []string
	for n := range builds {
		keys = append(keys, n)
	}
	sort.Strings(keys)

	for _, n := range keys {
		build := builds[n]
		build.name = n
		build.jsons = make(map[string]bool)
		skip := true
		for _, re := range r {
			if re.MatchString(build.name) {
				skip = false
				break
			}
		}
		if skip {
			continue
		}
		log.Printf("Run %v", build.name)
		build.jsons[f] = true
		build.path = path.Dir(f)

		// For each source file, assume we create an object file with the last char replaced
		// with 'o'. We can get smarter later.
		for _, v := range build.SourceFiles {
			f := path.Base(v)
			o := f[:len(f)-1] + "o"
			build.ObjectFiles = appendIfMissing(build.ObjectFiles, o)
		}

		for _, v := range build.Include {
			include(v, &build)
		}
		results = append(results, build)
	}
	return results
}

func buildkernel(b *build) {
	if b.Kernel == nil {
		return
	}
	envFunc := buildEnv(b)
	for name, path := range b.Kernel.Ramfiles {
		b.Kernel.Ramfiles[name] = os.Expand(path, envFunc);
	}
	codebuf := confcode(b.path, b.Kernel)
	if b.Kernel.CodeFile == "" {
		log.Fatalf("Missing Kernel.CodeFile in %v\n", b.path)
	}
	failOn(ioutil.WriteFile(b.Kernel.CodeFile, codebuf, 0666))
}

func wrapInQuote(args []string) []string {
	var res []string
	for _, a := range(args){
		if strings.Contains(a, "=") {
			res = append(res, "'" + a + "'")
		} else {
			res = append(res, a)
		}
	}
	return res
}

func convertLibPathsToArgs(b *build) []string {
	libLocations := make([]string, 0)
	args := make([]string, 0)
	defaultLibLocation := fromRoot("/arch/$ARCH/lib")
	for _, lib := range b.Libs {
		ldir := filepath.Dir(lib)
		if ldir != defaultLibLocation {
			if !isValueInList(ldir, libLocations) {
				libLocations = append(libLocations, ldir)
				args = append(args, "-L", ldir)
			}
		}
		lib = strings.Replace(lib, ldir + "/lib", "-l", 1)
		lib = strings.Replace(lib, ".a", "", 1)
		args = append(args, lib)
	}
	return args
}

func compile(b *build) {
	log.Printf("Building %s\n", b.name)
	// N.B. Plan 9 has a very well defined include structure, just three things:
	// /amd64/include, /sys/include, .
	args := b.SourceFiles
	args = append(args, b.Cflags...)
	if !isValueInList("-c", b.Cflags) {
		args = append(args, convertLibPathsToArgs(b)...)
		args = append(args, b.Oflags...)
	}
	if len(b.SourceFilesCmd) > 0 {
		for _, i := range b.SourceFilesCmd {
			largs := make([]string, 3)
			largs[0] = i
			largs[1] = "-o"
			largs[2] = strings.Replace(filepath.Base(i), filepath.Ext(i), "", 1)
			cmd := exec.Command(tools["cc"], append(largs, args...)...)
			run(b, *shellhack, cmd)
		}
		return
	}
	if !isValueInList("-c", b.Cflags) {
		args = append(args, "-o", b.Program)
	}
	cmd := exec.Command(tools["cc"], args...)
	run(b, *shellhack, cmd)
}

func link(b *build) {
	if !isValueInList("-c", b.Cflags) {
		return
	}
	log.Printf("Linking %s\n", b.name)
	if len(b.SourceFilesCmd) > 0 {
		for _, n := range b.SourceFilesCmd {
			// Split off the last element of the file
			var ext = filepath.Ext(n)
			if len(ext) == 0 {
				log.Fatalf("refusing to overwrite extension-less source file %v", n)
				continue
			}
			n = n[:len(n)-len(ext)]
			f := path.Base(n)
			o := f[:len(f)] + ".o"
			args := []string{"-o", n, o}
			args = append(args, b.Oflags...)
			args = append(args, b.Libs...)
			run(b, *shellhack, exec.Command(tools["ld"], args...))
		}
		return
	}
	args := []string{"-o", b.Program}
	args = append(args, b.ObjectFiles...)
	args = append(args, b.Oflags...)
	args = append(args, b.Libs...)
	run(b, *shellhack, exec.Command(tools["ld"], args...))
}

func install(b *build) {
	if b.Install == "" {
		return
	}

	log.Printf("Installing %s\n", b.name)
	failOn(os.MkdirAll(b.Install, 0755))

	switch {
	case len(b.SourceFilesCmd) > 0:
		for _, n := range b.SourceFilesCmd {
			ext := filepath.Ext(n)
			exe := n[:len(n)-len(ext)]
			move(exe, b.Install)
		}
	case len(b.Program) > 0:
		move(b.Program, b.Install)
	case len(b.Library) > 0:
		libpath := path.Join(b.Install, b.Library)
		args := append([]string{"-rs", libpath}, b.ObjectFiles...)
		run(b, *shellhack, exec.Command(tools["ar"], args...))
		run(b, *shellhack, exec.Command(tools["ranlib"], libpath))
	}
}

func move(from, to string) {
	final := path.Join(to, from)
	log.Printf("move %s %s\n", from, final)
	_ = os.Remove(final)
	failOn(os.Link(from, final))
	failOn(os.Remove(from))
}

func run(b *build, pipe bool, cmd *exec.Cmd) {
	if b != nil {
		cmd.Env = append(os.Environ(), b.Env...)
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if pipe {
		// Sh sends cmd to a shell. It's needed to enable $LD_PRELOAD tricks, see https://github.com/Harvey-OS/jehanne/issues/8#issuecomment-131235178
		shell := exec.Command(tools["sh"])
		shell.Env = cmd.Env
		shell.Stderr = os.Stderr
		shell.Stdout = os.Stdout

		commandString := cmd.Args[0]
		commandString += " " + strings.Join(wrapInQuote(cmd.Args[1:]), " ")
		shStdin, err := shell.StdinPipe()
		if err != nil {
			log.Fatalf("cannot pipe [%v] to %s: %v", commandString, tools["sh"], err)
		}
		go func() {
			defer shStdin.Close()
			io.WriteString(shStdin, commandString)
		}()

		log.Printf("%q | %s\n", commandString, tools["sh"])
		failOn(shell.Run())
		return
	}
	log.Println(strings.Join(cmd.Args, " "))
	failOn(cmd.Run())
}

func projects(b *build, r []*regexp.Regexp) {
	for _, v := range b.Projects {
		f, _ := findBuildfile(v)
		log.Printf("Doing %s\n", f)
		project(f, r, b)
	}
}

// assumes we are in the wd of the project.
func project(bf string, which []*regexp.Regexp, container *build) {
	cwd, err := os.Getwd()
	failOn(err)
	debug("Start new project cwd is %v", cwd)
	defer os.Chdir(cwd)
	dir := path.Dir(bf)
	root := path.Base(bf)
	debug("CD to %v and build using %v", dir, root)
	failOn(os.Chdir(dir))
	builds := process(root, which)
	debug("Processing %v: %d target", root, len(builds))
	for _, b := range builds {
		debug("Processing %v: %v", b.name, b)
		if container != nil {
			b.Env = append(container.Env, b.Env...)
		}
		projects(&b, regexpAll)
		for _, c := range b.Pre {
			// this is a hack: we just pass the command through as an exec.Cmd
			run(&b, true, exec.Command(c))
		}
		envFunc := buildEnv(&b);
		b.Program = os.Expand(b.Program, envFunc)
		for i, s := range b.SourceFiles {
			b.SourceFiles[i] = fromRoot(os.Expand(s, envFunc));
		}
		for i, s := range b.SourceFilesCmd {
			b.SourceFilesCmd[i] = fromRoot(os.Expand(s, envFunc));
		}
		for i, s := range b.ObjectFiles {
			b.ObjectFiles[i] = fromRoot(os.Expand(s, envFunc));
		}
		buildkernel(&b)
		if len(b.SourceFiles) > 0 || len(b.SourceFilesCmd) > 0 {
			compile(&b)
		}
		if b.Program != "" || len(b.SourceFilesCmd) > 0 {
			link(&b)
		}
		install(&b)
		for _, c := range b.Post {
			run(&b, true, exec.Command(c))
		}
	}
}

func main() {
	// A small amount of setup is done in the paths*.go files. They are
	// OS-specific path setup/manipulation. "jehanne" is set there and $PATH is
	// adjusted.
	var err error
	findTools(os.Getenv("TOOLPREFIX"))
	flag.Parse()
	cwd, err = os.Getwd()
	failOn(err)

	a := os.Getenv("ARCH")
	if a == "" || !arch[a] {
		s := []string{}
		for i := range arch {
			s = append(s, i)
		}
		log.Fatalf("You need to set the ARCH environment variable from: %v", s)
	}

	// ensure this is exported, in case we used a default value
	os.Setenv("JEHANNE", jehanne)

	if os.Getenv("LD_PRELOAD") != "" {
		log.Println("Using shellhack")
		*shellhack = true
	}

	// If no args, assume 'build.json'
	// Otherwise the first argument is either
	// - the path to a json file
	// - a directory containing a 'build.json' file
	// - a regular expression to apply assuming 'build.json'
	// Further arguments are regular expressions.
	consumedArgs := 0;
	bf := ""
	if len(flag.Args()) == 0 {
		f, err := findBuildfile("build.json")
		failOn(err)
		bf = f
	} else {
		f, err := findBuildfile(flag.Arg(0))
		failOn(err)

		if f == "" {
			f, err := findBuildfile("build.json")
			failOn(err)
			bf = f
		} else {
			consumedArgs = 1
			bf = f
		}
	}

	re := []*regexp.Regexp{regexp.MustCompile(".")}
	if len(flag.Args()) > consumedArgs {
		re = re[:0]
		for _, r := range flag.Args()[consumedArgs:] {
			rx, err := regexp.Compile(r)
			failOn(err)
			re = append(re, rx)
		}
	}
	project(bf, re, nil)
}

func findTools(toolprefix string) {
	var err error
	for k, v := range tools {
		if x := os.Getenv(strings.ToUpper(k)); x != "" {
			v = x
		}
		if v != "sh" {
			v = toolprefix + v;
		}
		v, err = exec.LookPath(v)
		failOn(err)
		tools[k] = v
	}
}

// disambiguate the buildfile argument
func findBuildfile(f string) (string, error) {
	if strings.HasSuffix(f, ".json"){
		if fi, err := os.Stat(f); err == nil  && !fi.IsDir() {
			return f, nil
		}
		return "", fmt.Errorf("unable to find buildfile %s", f)
	}
	if strings.Contains(f, "/") {
		return findBuildfile(path.Join(f, "build.json"))
	}
	return "", nil
}
