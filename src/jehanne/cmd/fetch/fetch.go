package main

import (
	"archive/tar"
	"bytes"
	"compress/bzip2"
	"compress/gzip"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/hex"
	"encoding/json"
	"hash"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path"
	"strings"
)

const (
	dirPermissions   = 0755
)

type Fetch struct {
	Upstream     string
	Digest       map[string]string
	Compress     string
	RemovePrefix bool
	Exclude      []string
}

func main() {

	j, err := ioutil.ReadFile("fetch.json")
	if err != nil {
		log.Fatal(err)
	}

	fetches := make(map[string]Fetch)
	if err := json.Unmarshal(j, &fetches); err != nil {
		log.Fatal(err)
	}

	for name, f := range(fetches) {
		log.Printf("Fetch: %v from %v", name, f.Upstream)
		if err := do(f, name); err != nil {
			log.Fatal(err)
		}
	}
}

func do(f Fetch, name string) error {
	fname := fetch(f)
	s, err := os.Open(fname)
	if err != nil {
		return err
	}
	defer os.Remove(fname)

	os.MkdirAll(name, dirPermissions)

	var unZ io.Reader
	switch f.Compress {
	case "gzip":
		unZ, err = gzip.NewReader(s)
		if err != nil {
			return err
		}
	case "bzip2":
		unZ = bzip2.NewReader(s)
	default:
		unZ = s
	}

	ar := tar.NewReader(unZ)
	h, err := ar.Next()
untar:
	for ; err == nil; h, err = ar.Next() {
		n := h.Name
		if f.RemovePrefix {
			n = strings.SplitN(n, "/", 2)[1]
		}
		for _, ex := range f.Exclude {
			if strings.HasPrefix(n, ex) {
				continue untar
			}
		}
		n = path.Join(name, n)
		if h.FileInfo().IsDir() {
			os.MkdirAll(n, dirPermissions)
			continue
		}
		os.MkdirAll(path.Dir(n), dirPermissions)
		out, err := os.Create(n)
		if err != nil {
			log.Println(err)
			continue
		}

		if n, err := io.Copy(out, ar); n != h.Size || err != nil {
			return err
		}
		out.Close()
		if err := os.Chmod(n, h.FileInfo().Mode()); err != nil {
			return err;
		}
	}
	if err != io.EOF {
		return err
	}
	return nil
}

type match struct {
	hash.Hash
	Good []byte
	Name string
}

func (m match) OK() bool {
	return bytes.Equal(m.Good, m.Hash.Sum(nil))
}

func fetch(v Fetch) string {
	if len(v.Digest) == 0 {
		log.Fatal("no checksums specifed")
	}

	f, err := ioutil.TempFile("", "cmdVendor")
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	req, err := http.NewRequest("GET", v.Upstream, nil)
	if err != nil {
		log.Fatal(err)
	}
	client := &http.Client{
		Transport: &http.Transport{
			Proxy:              http.ProxyFromEnvironment,
			DisableCompression: true,
		},
	}
	res, err := client.Do(req)
	if err != nil {
		log.Fatal(err)
	}
	defer res.Body.Close()

	var digests []match
	for k, v := range v.Digest {
		g, err := hex.DecodeString(v)
		if err != nil {
			log.Fatal(err)
		}
		switch k {
		case "sha224":
			digests = append(digests, match{sha256.New224(), g, k})
		case "sha256":
			digests = append(digests, match{sha256.New(), g, k})
		case "sha384":
			digests = append(digests, match{sha512.New384(), g, k})
		case "sha512":
			digests = append(digests, match{sha512.New(), g, k})
		}
	}
	ws := make([]io.Writer, len(digests))
	for i := range digests {
		ws[i] = digests[i]
	}
	w := io.MultiWriter(ws...)

	for _, h := range digests {
		if !h.OK() {
			log.Fatalf("mismatched %q hash\n\tWanted %x\n\tGot %x\n", h.Name, h.Good, h.Hash.Sum(nil))
		}
	}

	if _, err := io.Copy(f, io.TeeReader(res.Body, w)); err != nil {
		log.Fatal(err)
	}
	return f.Name()
}

func run(exe string, arg ...string) error {
	cmd := exec.Command(exe, arg...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
