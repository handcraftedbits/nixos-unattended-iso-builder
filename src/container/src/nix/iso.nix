{ config, lib, pkgs, ... }:
let
  vars = {
    bootstrapUrl = builtins.getEnv "INSTALL_BOOTSTRAP_URL";
  };

  autoInstallScript = import ./autoinstall.sh.nix { inherit vars; };
in
{
  imports = [ <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix> ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = true;

  environment.etc."autoinstall.sh".text = autoInstallScript;

  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  systemd.services.autoinstall = {
    after = [ "network-online.target" ];
    description = "Unattended NixOS Installation";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];

    path = with pkgs; [
      bash
      coreutils
      curl
      dosfstools
      jq
      e2fsprogs
      git
      gnutar
      gzip
      nix
      nixos-install-tools
      parted
      systemd
      util-linux
    ];

    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash /etc/autoinstall.sh";
      RemainAfterExit = true;
      StandardError = "journal+console";
      StandardOutput = "journal+console";
      TimeoutStartSec = "infinity";
      Type = "oneshot";
    };
  };
}
