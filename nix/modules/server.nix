{
  lib,
  config,
  pkgs,
  options,
  ...
}:
{
  # Taken from https://github.com/nix-community/srvos/blob/main/nixos/common/default.nix

  # Use systemd during boot as well except:
  boot.initrd.systemd.enable = true;

  # Don't install the /lib/ld-linux.so.2 stub. This saves one instance of nixpkgs.
  environment.ldso32 = null;

  # Ensure a clean & sparkling /tmp on fresh boots.
  boot.tmp.cleanOnBoot = lib.mkDefault true;

  # Taken from https://github.com/nix-community/srvos/blob/main/nixos/common/networking.nix

  # Allow PMTU / DHCP
  # networking.firewall.allowPing = true;

  # Keep dmesg/journalctl -k output readable by NOT logging
  # each refused connection on the open internet.
  # networking.firewall.logRefusedConnections = lib.mkDefault false;

  # Use networkd instead of the pile of shell scripts
  networking.useNetworkd = lib.mkDefault true;

  # The notion of "online" is a broken concept
  # https://github.com/systemd/systemd/blob/e1b45a756f71deac8c1aa9a008bd0dab47f64777/NEWS#L13
  # systemd.services.NetworkManager-wait-online.enable = false;
  systemd.network.wait-online.enable = lib.mkForce true;

  # Do not take down the network for too long when upgrading,
  # This also prevents failures of services that are restarted instead of stopped.
  # It will use `systemctl restart` rather than stopping it with `systemctl stop`
  # followed by a delayed `systemctl start`.
  systemd.services.systemd-networkd.stopIfChanged = false;
  # Services that are only restarted might be not able to resolve when resolved is stopped before
  systemd.services.systemd-resolved.stopIfChanged = false;

  # Taken from https://github.com/nix-community/srvos/blob/main/nixos/common/nix.nix

  # De-duplicate store paths using hardlinks except in containers
  # where the store is host-managed.
  nix.optimise.automatic = true;

  # If the user is in @wheel they are trusted by default.
  nix.settings.trusted-users = [ "@wheel" ];

  nix.daemonCPUSchedPolicy = lib.mkDefault "batch";
  nix.daemonIOSchedClass = lib.mkDefault "idle";
  nix.daemonIOSchedPriority = lib.mkDefault 7;

  systemd.services.nix-gc.serviceConfig = {
    CPUSchedulingPolicy = "batch";
    IOSchedulingClass = "idle";
    IOSchedulingPriority = 7;
  };

  # Make builds to be more likely killed than important services.
  # 100 is the default for user slices and 500 is systemd-coredumpd@
  # We rather want a build to be killed than our precious user sessions as builds can be easily restarted.
  systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = lib.mkDefault 250;

  # Taken from https://github.com/nix-community/srvos/blob/main/nixos/common/openssh.nix

  services.openssh = {
    settings.X11Forwarding = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PasswordAuthentication = false;
    settings.UseDns = false;
    # unbind gnupg sockets if they exists
    settings.StreamLocalBindUnlink = true;

    # Use key exchange algorithms recommended by `nixpkgs#ssh-audit`
    settings.KexAlgorithms = [
      "curve25519-sha256"
      "curve25519-sha256@libssh.org"
      "diffie-hellman-group16-sha512"
      "diffie-hellman-group18-sha512"
      "sntrup761x25519-sha512@openssh.com"
    ];
    # Only allow system-level authorized_keys to avoid injections.
    # We currently don't enable this when git-based software that relies on this is enabled.
    # It would be nicer to make it more granular using `Match`.
    # However those match blocks cannot be put after other `extraConfig` lines
    # with the current sshd config module, which is however something the sshd
    # config parser mandates.
    # authorizedKeysFiles = lib.mkIf (
    #   !config.services.gitea.enable
    #   && !config.services.gitlab.enable
    #   && !config.services.gitolite.enable
    #   && !config.services.gerrit.enable
    #   && !config.services.forgejo.enable
    # ) (lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ]);
  };

  # Only allow members of the wheel group to execute sudo by setting the executable’s permissions accordingly. This prevents users that are not members of wheel from exploiting vulnerabilities in sudo such as CVE-2021-3156.
  security.sudo.execWheelOnly = true;
  # Don't lecture the user. Less mutable state.
  security.sudo.extraConfig = ''
    Defaults lecture = never
  '';

  assertions =
    let
      validUsers = users: users == [ ] || users == [ "root" ];
      validGroups = groups: groups == [ ] || groups == [ "wheel" ];
      validUserGroups = builtins.all (
        r: validUsers (r.users or [ ]) && validGroups (r.groups or [ ])
      ) config.security.sudo.extraRules;
    in
    [
      {
        assertion = config.security.sudo.execWheelOnly -> validUserGroups;
        message = "Some definitions in `security.sudo.extraRules` refer to users other than 'root' or groups other than 'wheel'. Disable `config.security.sudo.execWheelOnly`, or adjust the rules.";
      }
    ];

  # Taken from https://github.com/nix-community/srvos/blob/main/nixos/common/zfs.nix

  services.zfs = lib.mkIf (config.boot.zfs.enabled) {
    autoSnapshot.enable = lib.mkDefault true;
    # defaults to 12, which is a bit much given how much data is written
    autoSnapshot.monthly = lib.mkDefault 1;
    autoScrub.enable = lib.mkDefault true;
  };

  # Taken from

  programs.git.package = lib.mkDefault pkgs.gitMinimal;

  environment = {
    # Print the URL instead on servers
    variables.BROWSER = "echo";
    # Don't install the /lib/ld-linux.so.2 and /lib64/ld-linux-x86-64.so.2
    # stubs. Server users should know what they are doing.
    stub-ld.enable = lib.mkDefault false;
  };

  # Restrict the number of boot entries to prevent full /boot partition.
  #
  # Servers don't need too many generations.
  boot.loader.grub.configurationLimit = lib.mkDefault 5;
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 5;

  documentation.nixos.enable = lib.mkDefault false;

  # No need for fonts on a server
  fonts.fontconfig.enable = lib.mkDefault false;

  programs.command-not-found.enable = lib.mkDefault false;

  # freedesktop xdg files
  xdg.autostart.enable = lib.mkDefault false;
  xdg.icons.enable = lib.mkDefault false;
  xdg.menus.enable = lib.mkDefault false;
  xdg.mime.enable = lib.mkDefault false;
  xdg.sounds.enable = lib.mkDefault false;

  programs.vim = {
    defaultEditor = lib.mkDefault true;
  }
  // lib.optionalAttrs (options.programs.vim ? enable) {
    enable = lib.mkDefault true;
  };

  # Make sure firewall is enabled
  networking.firewall.enable = true;

  # Delegate the hostname setting to dhcp/cloud-init by default
  networking.hostName = lib.mkOverride 1337 ""; # lower prio than lib.mkDefault

  # security.sudo.wheelNeedsPassword = false;

  # Enable SSH everywhere
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  # UTC everywhere!
  # time.timeZone = lib.mkDefault "UTC";

  # No mutable users by default
  # users.mutableUsers = false;

  # Given that our systems are headless, emergency mode is useless.
  # We prefer the system to attempt to continue booting so
  # that we can hopefully still access it remotely.
  # boot.initrd.systemd.suppressedUnits = lib.mkIf config.systemd.enableEmergencyMode [
  #   "emergency.service"
  #   "emergency.target"
  # ];

  systemd = {
    # Given that our systems are headless, emergency mode is useless.
    # We prefer the system to attempt to continue booting so
    # that we can hopefully still access it remotely.
    # enableEmergencyMode = false;

    # For more detail, see:
    #   https://0pointer.de/blog/projects/watchdog.html
    settings.Manager = {
      # systemd will send a signal to the hardware watchdog at half
      # the interval defined here, so every 7.5s.
      # If the hardware watchdog does not get a signal for 15s,
      # it will forcefully reboot the system.
      RuntimeWatchdocSec = lib.mkDefault "15s";
      # Forcefully reboot if the final stage of the reboot
      # hangs without progress for more than 30s.
      # For more info, see:
      #   https://utcc.utoronto.ca/~cks/space/blog/linux/SystemdShutdownWatchdog
      RebootWatchdogSec = lib.mkDefault "30s";
      # Forcefully reboot when a host hangs after kexec.
      # This may be the case when the firmware does not support kexec.
      KExecWatchdogSec = lib.mkDefault "1m";
    };

    sleep.settings.Sleep = {
      AllowSuspend = "no";
      AllowHibernation = "no";
    };
  };

  # Make sure the serial console is visible in qemu when testing the server configuration
  # with nixos-rebuild build-vm
  # virtualisation.vmVariant.virtualisation.graphics = lib.mkDefault false;
}
