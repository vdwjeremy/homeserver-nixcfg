# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{pkgs, config,...}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "olinet"; # Define your hostname.
  # networking.wireless.enable = true; # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."nixos" = {
    isNormalUser = true;
    description = "nixos";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII8TR1gvyHwr7C3/lgCywRw6M/Yx9L6sOW3+NetXjJl4"
    ];
  };
  users.users."root" = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII8TR1gvyHwr7C3/lgCywRw6M/Yx9L6sOW3+NetXjJl4"
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    htop
    git
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
    allowSFTP = true;
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

  # nixos-upgrade.service, nixos-upgrade.timer
  system.autoUpgrade.enable = true;
  system.autoUpgrade.dates  = "*-*-* *:23:30";
  system.autoUpgrade.flake  = "github:vdwjeremy/homeserver-nixcfg#olinet";
  system.autoUpgrade.flags  = ["--refresh"];
  system.autoUpgrade.randomizedDelaySec = "5m";
  system.autoUpgrade.allowReboot = true;  # Set to true if you want automatic reboots
  system.autoUpgrade.runGarbageCollection = true;

  # PostgreSQL DB
  services.postgresql = {
    enable = true;
    checkConfig = true;
    ensureDatabases = [ ];
    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser  auth-method
      local all       all     trust
    '';
    enableJIT = true;
    package = pkgs.postgresql_18;
    extensions = with pkgs.postgresql_18.pkgs; [ pgvector vectorchord ];
  };

  # Web
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  age.secrets.acme = {
    file = ../../secrets/acme.age;
    owner = "acme";
    group = config.services.nginx.group;
  };
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "admin@vdw.life";
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53"; # Use cloudflare's dns 
      environmentFile = "${config.age.secrets.acme.path}";
    };
    #certs."vdw.life" = {
    #  domain = "vdw.life";
    #  extraDomainNames = [ "*.vdw.life" ];
    #};
  };
  services.nginx = {
    enable = true;
    package = (pkgs.nginx.override { modules = [
      pkgs.nginxModules.dav
    ]; });
  };
  systemd.services.nginx.serviceConfig.StateDirectory = "nginx";

  # Webdav
  age.secrets.webdav-htpasswd = {
    file = ../../secrets/webdav-htpasswd.age;
    owner = config.services.nginx.user;
    group = config.services.nginx.group;
  };
  services.nginx.virtualHosts."dav.vdw.life" = {
    enableACME = true;
    acmeRoot = null;
    http2 = true;
    http3 = true;
    root = "/var/lib/nginx";
    locations."/" = {
      extraConfig = ''
        auth_basic "Restricted WebDAV";
        auth_basic_user_file ${config.age.secrets.webdav-htpasswd.path};

        dav_methods PUT DELETE MKCOL COPY MOVE;
        dav_ext_methods PROPFIND OPTIONS LOCK UNLOCK;
        # Adjust as desired:
        dav_access user:rw group:rw all:r;
        client_max_body_size 0;
        create_full_put_path on;
        #client_body_temp_path /srv/client-temp;
        autoindex on;

        allow all;
        '';
    };
  };

}
