# Copy the content of `configuration.nix` into `/etc/nixos/configuration.nix`.
#
# This is useful only for image building, so that the
# generated image's configuration.nix contains the configuration.nix
# that generated it.
#
# For this reason, this module should usually be conditionally included,
# so that it is not present/used on the machine started from the image.
{ pkgs, ... }: {

  environment.etc."nixos/configuration.nix".source = ./configuration.nix;

}
