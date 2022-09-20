with import <nixpkgs> {};
mkShell {
  nativeBuildInputs = [
    bashInteractive

    (terraform.withPlugins (p: [
      p.null
      # used in the example
      p.tls
      p.hcloud
    ]))

  ];
}
