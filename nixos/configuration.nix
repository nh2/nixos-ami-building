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

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    80 # nginx
    443 # nginx
  ];
  networking.firewall.allowedUDPPorts = [
  ];

  services.nginx.enable = true;
}
