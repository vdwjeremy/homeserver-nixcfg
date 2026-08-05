#https://github.com/ryantm/agenix#install-via-niv

let
  user1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPPb8OLpRQ540CqpbVGn7yUMKnU95MYTYAEv099E23fa";
  users = [ user1 ];

  system1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICScrS51RvpecVzMYIS05zY6T57sCZscUd8McRSn1R3/";
  systems = [ system1 ];
in
{
  "secret1.age".publicKeys = [ user1 system1 ];
  "secret2.age".publicKeys = users ++ systems;
  "armored-secret.age" = {
    publicKeys = [ user1 ];
    armor = true;
  };
}