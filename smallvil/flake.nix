{
  description = "Smallvil - A Wayland compositor based on Smithay";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rustc-dev" ];
        };

        buildInputs = with pkgs; [
          libxkbcommon
          libinput
          mesa
          wayland
          wayland-protocols
          xorg.libX11
          xorg.libXcursor
          xorg.libXrandr
          xorg.libXi
          vulkan-loader
          libGL
          udev
          systemd
        ];

        nativeBuildInputs = with pkgs; [
          pkg-config
          rustToolchain
        ];

        libPath = pkgs.lib.makeLibraryPath buildInputs;

      in
      {
        devShells.default = pkgs.mkShell {
          inherit buildInputs;
          
          nativeBuildInputs = nativeBuildInputs ++ (with pkgs; [
            rustToolchain
            
            rust-analyzer
            cargo-watch
            cargo-edit
            cargo-expand
            gdb
            lldb
            weston
          ]);

          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
          LD_LIBRARY_PATH = libPath;
          PKG_CONFIG_PATH = "${pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" buildInputs}";
          XDG_RUNTIME_DIR = "/tmp";

          shellHook = ''
            echo "🦀 Smallvil development environment loaded"
            echo "Rust toolchain: ${rustToolchain.version}"
          '';
        };

        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "smallvil";
          version = "0.1.0";

          src = ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
            outputHashes = {
              "smithay-0.3.0" = pkgs.lib.fakeSha256;
            };
          };

          inherit buildInputs nativeBuildInputs;

          PKG_CONFIG_PATH = "${pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" buildInputs}";

          postFixup = ''
            patchelf --set-rpath "${libPath}" $out/bin/smallvil
          '';

          meta = with pkgs.lib; {
            description = "A Wayland compositor example using Smithay";
            license = licenses.mit;
            platforms = platforms.linux;
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/smallvil";
        };
      }
    );
}
