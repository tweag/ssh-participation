# Arbitrary SSH user forwarder

This is a very simple SSH server that accepts arbitrary user names, authenticating them with a global OTP then calling a command that can handle that username.

Env vars to configure the server:
- `SSH_ADDRESS`: The address and port to listen on. E.g. `localhost:2222`
- `SSH_HOSTKEY`: Absolute or relative path to the hostkey. Generate this with `ssh-keygen -t rsa -f id_rsa` (without password)
- `SSH_OTPFILE`: Absolute or relative path to the file where the current OTP code should be written to. The file is appended with the latest code when it changes

The CLI arguments are called when a user connects

Env var available in the called command:
- `SSH_USER`: The username that was used to connect to the server

## Building

```
nix-build
```

## Running for development

```
make
```
