{ modulesPath, pkgs, lib, ... }: {

  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
  ]
  ++ lib.optionals (builtins.pathExists ./configuration-nix-generator.nix) [
    ./configuration-nix-generator.nix
  ];
  ec2.hvm = true;

  environment.systemPackages = with pkgs; [
    git
    htop
    vim
    wget
  ];

  services.nginx.enable = true;
}
