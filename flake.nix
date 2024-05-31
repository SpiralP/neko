{
  inputs = {
    # need unstable for libclipboard
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      makePackages = (pkgs:
        let
          clientManifest = lib.importJSON ./client/package.json;
        in
        rec {
          default = server;

          server = pkgs.buildGoModule {
            pname = "neko-server";
            version = "${self.shortRev or self.dirtyShortRev}";

            src = ./server;

            postPatch = ''
              substituteInPlace internal/desktop/clipboard/clipboard.go \
                --replace-fail /usr/local/lib/libclipboard.a -lclipboard

              test -f ${client}/lib/node_modules/neko-client/dist/index.html
              substituteInPlace internal/config/server.go \
                --replace-fail ./www ${client}/lib/node_modules/neko-client/dist
            '';

            vendorHash = "sha256-OSgGwK+pBDBO4/9jSdpJ2f5Erd0Z/jndvrNIYR2ZBk0=";

            buildInputs = with pkgs; with xorg; with pkgs.gst_all_1; [
              client
              gst-plugins-bad
              gst-plugins-base
              gst-plugins-good
              gst-plugins-ugly
              gstreamer
              libclipboard
              libX11
              libXfixes
              libXi
              libXrandr
              libXtst

              gst-libav
              gst-vaapi
              libva
            ];

            nativeBuildInputs = with pkgs; [
              makeWrapper
              pkg-config
            ];

            postInstall = ''
              wrapProgram $out/bin/neko \
                --prefix GST_PLUGIN_PATH : "$GST_PLUGIN_SYSTEM_PATH_1_0" \
            '';
          };

          client = pkgs.buildNpmPackage {
            pname = clientManifest.name;
            version = clientManifest.version;

            src = ./client;

            npmDepsHash = "sha256-L8/ToH05+mIAS9+cTMQ3tWMDkyJ/4LeiAU1ywbie9a4=";
          };
        }
      );
    in
    builtins.foldl' lib.recursiveUpdate { } (builtins.map
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          packages = makePackages pkgs;
        in
        {
          devShells.${system} = packages;
          packages.${system} = packages;
        })
      lib.systems.flakeExposed);
}
