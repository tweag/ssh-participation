package main

// This file is mostly copied from https://github.com/gliderlabs/ssh/blob/master/_examples/ssh-pty/pty.go
import (
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"syscall"
	"unsafe"

	"github.com/gliderlabs/ssh"
	"github.com/creack/pty"
)

func setWinsize(f *os.File, w, h int) {
	syscall.Syscall(syscall.SYS_IOCTL, f.Fd(), uintptr(syscall.TIOCSWINSZ),
		uintptr(unsafe.Pointer(&struct{ h, w, x, y uint16 }{uint16(h), uint16(w), 0, 0})))
}

func main() {
	binary, hasBinary := os.LookupEnv("SSH_BINARY")
	if ! hasBinary {
		log.Fatalln("SSH_BINARY not set")
	}
	hostkey, hasHostkey := os.LookupEnv("SSH_HOSTKEY")
	if ! hasHostkey {
		log.Fatalln("SSH_HOSTKEY not set")
	}

	ssh.Handle(func(s ssh.Session) {
		cmd := exec.Command(binary)
		ptyReq, winCh, isPty := s.Pty()
		if isPty {
			cmd.Env = append(cmd.Env, fmt.Sprintf("TERM=%s", ptyReq.Term))
			cmd.Env = append(cmd.Env, fmt.Sprintf("SSH_USER=%s", s.User()))
			f, err := pty.Start(cmd)
			if err != nil {
				panic(err)
			}
			go func() {
				for win := range winCh {
					setWinsize(f, win.Width, win.Height)
				}
			}()
			go func() {
				io.Copy(f, s) // stdin
			}()
			io.Copy(s, f) // stdout
			cmd.Wait()
		} else {
			io.WriteString(s, "No PTY requested.\n")
			s.Exit(1)
		}
	})

	log.Printf("starting ssh server on port 2222 with binary %s and hostkey %s ...\n", binary, hostkey)
	log.Fatal(ssh.ListenAndServe(":2222", nil, ssh.HostKeyFile(hostkey)))
}
