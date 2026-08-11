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
        client_max_body_size 50000M;
        send_timeout         600s;
        create_full_put_path on;
        #client_body_temp_path /srv/client-temp;
        autoindex on;

        allow all;
        '';
    };
  };
  systemd.services.nginx.serviceConfig.ReadWritePaths = [ "/mnt/data/webdav" ];

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
  systemd.timers."pocket-id-backup" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar="weekly";
      Unit = "pocket-id-backup.service";
    };
  };
  systemd.services."pocket-id-backup" = {
    script = ''
      cd /var/lib/pocket-id
      ENCRYPTION_KEY_FILE=/run/agenix/pocket-id-key ${pkgs.pocket-id}/bin/pocket-id export --path /mnt/data/pocket-id-backup/pocket-id-export.zip
    '';
    serviceConfig = {
      Type = "oneshot";
      User = config.services.pocket-id.user;
    };
  };

  # Immich
  age.secrets.immich-oidc-secret = {
    file = ../../secrets/immich-oidc-secret.age;
    owner = config.services.immich.user;
    group = config.services.immich.group;
  };
  age.secrets.immich-smtp-password = {
    file = ../../secrets/immich-smtp-password.age;
    owner = config.services.immich.user;
    group = config.services.immich.group;
  };
  services.immich = {
    enable = true;
    port = 2283;
    mediaLocation = "/mnt/data/immich";
    settings = {
      server.externalDomain = "https://immich.vdw.life";
      newVersionCheck.enabled = true;
      passwordLogin.enabled = false;
      oauth = {
        enabled = true;
        issuerUrl = "https://auth.vdw.life/.well-known/openid-configuration";
        endSessionEndpoint = "https://auth.vdw.life/api/oidc/end-session";
        autoLaunch = true;
        autoRegister = true;
        clientId = "a8258857-72d7-4efa-9fd2-47c78713bcc6";
        clientSecret._secret = config.age.secrets.immich-oidc-secret.path;
        scope = "openid email profile";
        roleClaim = "immich_role";
        storageLabelClaim = "preferred_username";
        storageQuotaClaim = "immich_quota";
      };
      storageTemplate = {
        enabled = true;
        hashVerificationEnabled = true;
        template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
      };
      notifications = {
        smtp = {
          enabled = true;
          from = "immich@vdw.life";
          replyTo = "noreply@vdw.life";
          transport = {
            host = "live.smtp.mailtrap.io";
            ignoreCert = false;
            port = 587;
            secure = false;
            username = "api";
            password._secret = config.age.secrets.immich-smtp-password.path;
          };
        };
      };
    };
  };
  services.nginx.virtualHosts."immich.vdw.life" = {
    enableACME = true;
    acmeRoot = null;
    addSSL = true;
    http2 = true;
    http3 = true;
    locations."/" = {
      proxyPass = "http://localhost:2283";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        client_max_body_size 50000M;
        proxy_read_timeout   600s;
        proxy_send_timeout   600s;
        send_timeout         600s;
      '';
    };
  };

  # Paperless NGX
  age.secrets.paperless-env = {
    file = ../../secrets/paperless-env.age;
    owner = config.services.paperless.user;
    group = config.services.paperless.user;
  };
  services.paperless = {
    enable = true;
    consumptionDirIsPublic = true;
    database.createLocally = true;
    dataDir = "/mnt/data/paperless";
    environmentFile = "${config.age.secrets.paperless-env.path}";
    settings = {
      PAPERLESS_DBENGINE = "postgresql";
      PAPERLESS_CONSUMER_IGNORE_PATTERN = [
        ".DS_STORE/*"
        "desktop.ini"
      ];
      PAPERLESS_CONSUMER_DELETE_DUPLICATES = true;
      PAPERLESS_CONSUMER_RECURSIVE = true;
      PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = true;
      PAPERLESS_OCR_LANGUAGE = "fra+eng";
      PAPERLESS_OCR_USER_ARGS = {
        optimize = 3;
        continue_on_soft_render_error = true;
      };
      PAPERLESS_OCR_MAX_IMAGE_PIXELS = 80000000;
      PAPERLESS_URL = "https://paperless.vdw.life";
      PAPERLESS_TASK_WORKERS = 1;
      PAPERLESS_THREADS_PER_WORKER = 1;
      PAPERLESS_CONVERT_MEMORY_LIMIT = 128;
      PAPERLESS_CONSUMER_ENABLE_ASN_BARCODE = true;
      PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
      PAPERLESS_LOGOUT_REDIRECT_URL = "https://auth.vdw.life/api/oidc/end-session";
      PAPERLESS_SOCIAL_AUTO_SIGNUP = true;
      PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = true;
      PAPERLESS_DISABLE_REGULAR_LOGIN = true;
      PAPERLESS_REDIRECT_LOGIN_TO_SSO = false;
      PAPERLESS_TOKEN_THROTTLE_RATE = "5/min";
    };
  };
  services.nginx.virtualHosts."paperless.vdw.life" = {
    enableACME = true;
    acmeRoot = null;
    addSSL = true;
    http2 = true;
    http3 = true;
    locations."/" = {
      proxyPass = "http://localhost:28981";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        client_max_body_size 50000M;
        proxy_read_timeout   600s;
        proxy_send_timeout   600s;
        send_timeout         600s;
      '';
    };
    locations."/admin" = {
      extraConfig = ''
        deny all;
        return 404;
      '';
    };
  };

  # Navidrome
  services.navidrome = {
    enable = true;
    settings.MusicFolder = "/mnt/data/music";
  };
  services.nginx.virtualHosts."music.vdw.life" = {
    enableACME = true;
    acmeRoot = null;
    addSSL = true;
    http2 = true;
    http3 = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:4533";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        client_max_body_size 50000M;
        proxy_read_timeout   600s;
        proxy_send_timeout   600s;
        send_timeout         600s;
      '';
    };
  };
  services.nfs.server = {
    enable = true;
    # fixed rpc.statd port; for firewall
    lockdPort = 4001;
    mountdPort = 4002;
    statdPort = 4000;
    extraNfsdConfig = '''';
    exports = ''
      /mnt/data/music    192.168.0.0/16(insecure,rw,no_subtree_check,all_squash,anonuid=989,anongid=987) 2a02:8428:1c70:a900::/56(insecure,rw,no_subtree_check,all_squash,anonuid=989,anongid=987)
    '';
  };

}
