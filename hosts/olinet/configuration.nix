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

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 
      80 443                          # HTTP/HTTPS
      111 2049 4000 4001 4002 20048   # NFS
    ];
    allowedUDPPorts = [ 
      443                             # HTTPS
      111 2049 4000 4001 4002 20048   # NFS
    ];
  };

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

  # NFS
  services.nfs.server = {
    enable = true;
    # fixed rpc.statd port; for firewall
    lockdPort = 4001;
    mountdPort = 4002;
    statdPort = 4000;
    extraNfsdConfig = '''';
    exports = ''
      /mnt/data/music    192.168.0.0/16(insecure,rw,no_subtree_check) 2a02:8428:1c70:a900::/56(insecure,rw,no_subtree_check)
    '';
  };

  # Web
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
      environmentFile = "${config.age.secrets.acme.path}"; # ! API Keys deprecated, API Tokens migration to plan
    };
  };
  services.nginx = {
    enable = true;
    package = (pkgs.nginx.override { modules = [
      pkgs.nginxModules.dav
    ]; });
  };

  # Webdav
  age.secrets.webdav-htpasswd = {
    file = ../../secrets/webdav-htpasswd.age;
    owner = config.services.nginx.user;
    group = config.services.nginx.group;
  };
  services.nginx.virtualHosts."dav.vdw.life" = {
    enableACME = true;
    acmeRoot = null;
    addSSL = true;
    http2 = true;
    http3 = true;
    root = "/mnt/data/webdav";
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

  # Pocket ID
  age.secrets.pocket-id-key = {
    file = ../../secrets/pocket-id-key.age;
    owner = config.services.pocket-id.user;
    group = config.services.pocket-id.group;
  };
  services.pocket-id = {
    enable = true;
    credentials = {
      ENCRYPTION_KEY = config.age.secrets.pocket-id-key.path;
    };
    settings = {
      # <https://pocket-id.org/docs/configuration/environment-variables>
      APP_URL = "https://auth.vdw.life";
      TRUST_PROXY = true;
      HOST = "localhost";
      PORT = 1411;
      ALLOW_INSECURE_CALLBACK_URLS = false;
      #DB_CONNECTION_STRING = "postgresql:///pocketid";
    };
  };
  services.nginx.virtualHosts."auth.vdw.life" = {
    enableACME = true;
    acmeRoot = null;
    addSSL = true;
    http2 = true;
    http3 = true;
    locations."/" = {
      proxyPass = "http://localhost:1411";
      proxyWebsockets = true; # needed if you need to use WebSocket
      extraConfig = ''
        proxy_set_header        Host $host;
        proxy_set_header        X-Real-IP $remote_addr;
        proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto https;
        proxy_set_header        X-Forwarded-Host $host;
        proxy_set_header        X-Forwarded-Server $hostname;
        proxy_busy_buffers_size   512k;
        proxy_buffers   4 512k;
        proxy_buffer_size   256k;
        '';
    };
  };

}
