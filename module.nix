{ lib, pkgs, config, ... }:
let
  ssh-forward = import ./default.nix { inherit pkgs; };
  cfg = config.services.ssh-participation;

  login = pkgs.writeShellScript "login" ''
    set -euo pipefail

    # Get the primary group of the user
    if ! group=$(id -gn "$SSH_USER" 2>/dev/null); then
      # This fails if the user doesn't exist, so create it
      useradd -b /home/participants -m -g participants "$SSH_USER"
      chmod g+rX /home/participants/"$SSH_USER"
    elif [[ ! "$group" == participants ]]; then
      # If the user exists, but its primary group is not participants, we don't allow users to log into it
      echo "User \"$SSH_USER\" cannot be used to participate with"
      exit 1
    fi

    # Log into the user, which should now exist and be a participating user
    exec su - "$SSH_USER"
  '';
in {
  options.services.ssh-participation = {
    enable = lib.mkEnableOption "ssh participation";
  };

  config = lib.mkIf cfg.enable {

    systemd.services.ssh-participation = {
      path = [
        "/run/wrappers"
        pkgs.shadow
        pkgs.openssh
        pkgs.diceware
      ];
      preStart = ''
        if [[ ! -f id_rsa ]]; then
          ssh-keygen -t rsa -f id_rsa
        fi
        if [[ ! -f password ]]; then
          diceware --num 4 --delimiter ' ' --no-caps > password
        fi
      '';
      environment = {
        SSH_ADDRESS = ":22";
        SSH_HOSTKEY = "id_rsa";
        SSH_PASSWORD_FILE = "password";
      };

      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "bouncer";
        Group = "bouncer";
        ExecStart = "${ssh-forward}/bin/module-ssh-server sudo -E ${login}";
        StateDirectory = "bouncer";
        WorkingDirectory = "%S/bouncer";
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      };
    };

    users.users.bouncer = {
      isSystemUser = true;
      group = "bouncer";
    };
    users.groups.bouncer = {};

    users.groups.participants = {};

    security.sudo.extraRules = [
      {
        users = [ "bouncer" ];
        runAs = "root";
        commands = [{
          command = "${login}";
          options = [ "NOPASSWD" "SETENV" ];
        }];
      }
    ];

    # Move the normal ssh server to port 222
    services.openssh.ports = [ 222 ];

    networking.firewall.allowedTCPPorts = [ 22 ];

  };
}
