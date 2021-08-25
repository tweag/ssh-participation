{ lib, pkgs, config, ... }:
let
  inherit (lib) types;
  ssh-participation = import ./default.nix { inherit pkgs; };
  cfg = config.services.ssh-participation;

  login = pkgs.writeShellScript "login" ''
    set -euo pipefail

    user=''${SSH_USER,,}
    # FIXME: Lock user

    # Get the primary group of the user
    if ! group=$(id -gn "$user" 2>/dev/null); then
      # This fails if the user doesn't exist, so create it
      useradd -b /home/participants -m -g participants "$user"
      chmod g+rX /home/participants/"$user"
      uid=$(id -u "$user")
      ln -s /etc/ssh-participation/user.slice.d "/var/lib/bouncer/slices/user-$uid.slice.d"
    elif [[ ! "$group" == participants ]]; then
      # If the user exists, but its primary group is not participants, we don't allow users to log into it
      echo "User \"$user\" cannot be used to participate with"
      exit 1
    fi

    # Log into the user, which should now exist and be a participating user
    exec machinectl --quiet shell "$user"@
  '';

  clear = pkgs.writeShellScriptBin "ssh-participation-clear" ''
    set -euo pipefail
    shopt -s nullglob

    cd /home/participants
    cp -r . "/var/lib/bouncer/runs/$(date -Iseconds)"

    for user in *; do
      loginctl terminate-user "$user"
      userdel -r "$user"
    done
  '';
in {
  options.services.ssh-participation = {
    enable = lib.mkEnableOption "ssh participation";
    port = lib.mkOption {
      type = types.port;
      default = 22;
    };
    passwordCommand = lib.mkOption {
      type = types.uniq (types.listOf types.str);
      default = [
        (lib.getBin pkgs.diceware + "/bin/diceware")
        "--num=4"
        "--delimiter= "
        "--no-caps"
      ];
      description = ''
        Command whose output should be used as the password required to log in.
        Runs in a writable directory that can be used to persist state between
        runs to have a persistent password. By default the password changes
        every run. The password is output
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    environment.etc."ssh-participation/user.slice.d/limits.conf".text = ''
      [Slice]
      CPUAccounting=yes
      CPUQuota=50%
      MemoryAccounting=yes
      MemoryMax=20%
      TasksAccounting=yes
      TasksMax=100
    '';

    boot.extraSystemdUnitPaths = [ "/var/lib/bouncer/slices" ];

    # Users logging in from these terminals require their terminfo to be usable
    # because they have a custom TERM value/protocol
    environment.systemPackages = with pkgs; [
      kitty
      termite
    ];

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
        mkdir -p slices runs
      '';
      environment = {
        SSH_ADDRESS = ":${toString cfg.port}";
        SSH_HOSTKEY = "id_rsa";
      };

      script = ''
        tmp=$(mktemp)
        ${lib.escapeShellArgs cfg.passwordCommand} > "$tmp"
        SSH_PASSWORD_FILE="$tmp" ${ssh-participation}/bin/ssh-participation sudo -E ${login}
      '';

      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "bouncer";
        Group = "bouncer";
        StateDirectory = "bouncer";
        WorkingDirectory = "%S/bouncer";
        # Allow binding to ports < 1024
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        PrivateTmp = true;
      };
    };

    users.users.bouncer = {
      isSystemUser = true;
      group = "bouncer";
    };
    users.groups.bouncer = {};

    users.groups.participants = {};

    # We need to be able to create new users on-the-fly
    users.mutableUsers = true;

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

    networking.firewall.allowedTCPPorts = [ cfg.port ];

    assertions = [
      {
        assertion = config.services.openssh.enable -> ! lib.elem cfg.port config.services.openssh.ports;
        message = ''
          The port ${toString cfg.port} for ssh-participation is already used by openssh.
          Either change the openssh port using `services.openssh.ports`
          Or change the ssh-participation port using `services.ssh-participation.port`
        '';
      }
    ];

  };
}
