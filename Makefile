export SSH_HOSTKEY = id_rsa
export SSH_OTPFILE = otp.txt
export SSH_ADDRESS = localhost:2222

run: $(SSH_HOSTKEY)
	go run main.go bash

$(SSH_HOSTKEY):
	ssh-keygen -t rsa -f $@
