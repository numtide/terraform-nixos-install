{
  description = "A flake for hetzner cloud machines";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable-small";

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux = {
      #formatter = blender_3_3;
    };
  };
}
