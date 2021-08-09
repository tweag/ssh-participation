# Arbitrary SSH user forwarder

This is a very simple SSH server that accepts arbitrary user names and calls a binary with it.

Env vars to configure the server:
- `SSH_BINARY`: Absolute or relative path to the binary to run for users that connect
- `SSH_HOSTKEY`: Absolute or relative path to the hostkey. Generate this with `ssh-keygen -t rsa -f id_rsa` (without password)

Env var available in the called binary:
- `SSH_USER`: The username that was used to connect to the server
