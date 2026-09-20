{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    git

    wget
    curl
    screen

    vim
    nano

    # archiver
    zip
    unzip
    unar
    p7zip

    just

    # Nix Language Server
    nixd
    nil
  ];
}
