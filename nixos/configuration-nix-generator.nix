# Copy the content of `configuration.nix` into `/etc/nixos/configuration.nix`.
#
# This is useful only for image building, so that the
# generated image's configuration.nix contains the configuration.nix
# that generated it.
#
# For this reason, this module should usually be conditionally included,
# so that it is not present/used on the machine started from the image.
{ pkgs, lib, ... }: {

  # Just like the installer does it:
  # https://github.com/NixOS/nixpkgs/blob/f0f040c3f7f07fa4dc28b32d44e1db78fa3a0cc1/nixos/modules/installer/cd-dvd/channel.nix#L34
  boot.postBootCommands = lib.mkAfter ''
    if ! [ -e /var/lib/nixos/did-initial-configuration-copy ]; then
      echo "Creating intial configuration.nix"
      cp ${./configuration.nix} /etc/nixos/configuration.nix
      touch /var/lib/nixos/did-initial-configuration-copy
    fi
  '';

}
