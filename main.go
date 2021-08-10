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
	"time"

	"github.com/gliderlabs/ssh"
	"github.com/creack/pty"
	gossh "golang.org/x/crypto/ssh"
	"github.com/xlzd/gotp"
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
	address, hasAddress := os.LookupEnv("SSH_ADDRESS")
	if ! hasAddress {
		log.Fatalln("SSH_ADDRESS not set")
	}
	hostkey, hasHostkey := os.LookupEnv("SSH_HOSTKEY")
	if ! hasHostkey {
		log.Fatalln("SSH_HOSTKEY not set")
	}
	otpFile, hasOtpFile := os.LookupEnv("SSH_OTPFILE")
	if ! hasOtpFile {
		log.Fatalln("SSH_OTPFILE not set")
	}

	f, err := os.Create(otpFile)
	if err != nil {
		fmt.Println(err)
		return
	}
	defer f.Close()

	secretLength := 16
	secret := gotp.RandomSecret(secretLength)
	otp := gotp.NewDefaultHOTP(secret)
	counter := 0

	go func() {
		for {
			value := otp.At(counter)

			fmt.Printf("OTP code is now %s\n", value)
			_, err := f.WriteString(value + "\n")
			if err != nil {
				log.Fatalln(err)
			}

			time.Sleep(60 * time.Second)
			counter += 1

		}
	}()

	ssh.Handle(func(s ssh.Session) {
		cmd := exec.Command(binary)
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
		answers, err := challenge("", "", []string{"Enter OTP code: "}, []bool{true})
		if err != nil {
			fmt.Printf("Got error while challenging: %s\n", err)
			return false
		}
		return otp.Verify(answers[0], counter)
	})

	log.Printf("starting ssh server on %s with binary %s and hostkey %s, writing the otp password to %s...\n", address, binary, hostkey, otpFile)
	log.Fatal(ssh.ListenAndServe(address, nil, ssh.HostKeyFile(hostkey), interactiveOption))
}
