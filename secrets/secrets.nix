#https://github.com/ryantm/agenix#install-via-niv

let
  user1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILUuijNhW7+RinV54uTOgptYixD2FRbZacus63AUEIK4";
  users = [ user1 ];

  system1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEulzKfLIdzyAOTAVOSKor8xMd2nV+kbSrslV1bHNsQ7";
  systems = [ system1 ];
in
{
  "webdav-htpasswd.age".publicKeys = users ++ systems;
  "acme.age".publicKeys = users ++ systems;
  "pocket-id-key.age".publicKeys = users ++ systems;
  "immich-oidc-secret.age".publicKeys = users ++ systems;
}