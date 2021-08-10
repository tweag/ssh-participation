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
	"io/ioutil"
	"strings"

	"github.com/gliderlabs/ssh"
	"github.com/creack/pty"
	gossh "golang.org/x/crypto/ssh"
)

func setWinsize(f *os.File, w, h int) {
	syscall.Syscall(syscall.SYS_IOCTL, f.Fd(), uintptr(syscall.TIOCSWINSZ),
		uintptr(unsafe.Pointer(&struct{ h, w, x, y uint16 }{uint16(h), uint16(w), 0, 0})))
}

func main() {
	if len(os.Args) < 2 {
		log.Fatalln("No arguments provided for command to run for connections")
	}
	binary := os.Args[1]
	args := os.Args[2:]

	address, hasAddress := os.LookupEnv("SSH_ADDRESS")
	if ! hasAddress {
		log.Fatalln("SSH_ADDRESS not set")
	}
	hostkey, hasHostkey := os.LookupEnv("SSH_HOSTKEY")
	if ! hasHostkey {
		log.Fatalln("SSH_HOSTKEY not set")
	}
	passwordFile, hasPasswordFile := os.LookupEnv("SSH_PASSWORD_FILE")
	if ! hasPasswordFile {
		log.Fatalln("SSH_PASSWORD_FILE not set")
	}

	content, err := ioutil.ReadFile(passwordFile)
	if err != nil {
		log.Fatalln(err)
	}
	password := strings.Trim(string(content), "\n")

	ssh.Handle(func(s ssh.Session) {
		cmd := exec.Command(binary)
		cmd.Args = append(cmd.Args, args...)
		ptyReq, winCh, isPty := s.Pty()
		if isPty {
			cmd.Env = append(os.Environ(), fmt.Sprintf("TERM=%s", ptyReq.Term))
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

	interactiveOption := ssh.KeyboardInteractiveAuth(func(ctx ssh.Context, challenge gossh.KeyboardInteractiveChallenge) bool {
		answers, err := challenge("", "", []string{"Enter password: "}, []bool{true})
		if err != nil {
			fmt.Printf("Got error while challenging: %s\n", err)
			return false
		}
		return answers[0] == password
	})

	log.Printf("starting ssh server on %s...\n", address)
	log.Fatal(ssh.ListenAndServe(address, nil, ssh.HostKeyFile(hostkey), interactiveOption))
}
