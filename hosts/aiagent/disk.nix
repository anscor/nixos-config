{ ... }: {
  disko.devices = {
    disk.system = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "fmask=0077" "dmask=0077" ];
            };
          };
          nixos = {
            size = "100%";
            content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; };
          };
        };
      };
    };
    disk.home = {
      type = "disk";
      device = "/dev/sdb";
      content = {
        type = "gpt";
        partitions = {
          home = {
            size = "100%";
            content = { type = "filesystem"; format = "ext4"; mountpoint = "/home"; };
          };
        };
      };
    };
  };
}
