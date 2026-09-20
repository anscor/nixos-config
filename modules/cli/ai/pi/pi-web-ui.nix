{ inputs, ... }: let
  port = 23366;
in {
  networking.firewall.allowedTCPPorts = [ port ];
  home-manager.sharedModules = [
    inputs.pi-web-ui.homeManagerModules.default
    ({ pkgs, ... }: {
      home.packages = [ pkgs.nodejs ];

      services.pi-web-ui = {
        enable = true;
        host = "0.0.0.0";
        inherit port;
        allowOrigins = [
          "https://pi.anscor.top"
        ];
        extraArgs = [
          "--no-browser"
        ];
      };
    })
  ];
}