export SSH_ADDRESS = localhost:2222
export SSH_HOSTKEY = id_rsa
export SSH_PASSWORD_FILE = password

run: $(SSH_HOSTKEY) $(SSH_PASSWORD_FILE)
	go run main.go bash

$(SSH_HOSTKEY):
	ssh-keygen -t rsa -f $@

$(SSH_PASSWORD_FILE):
	diceware --num 4 --delimiter ' ' --no-caps > $@
