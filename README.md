## Useful commands

nix flake check
nix flake update

nixos-rebuild switch --flake /etc/nixos#olinet

nix shell github:ryantm/agenix
    agenix -e secret.age

htpasswd -nb user password