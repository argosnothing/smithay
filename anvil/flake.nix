{
  description = "Anvil - A Wayland compositor built with Smithay";

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
          extensions = [ "rust-src" "rust-analyzer" ];
        };

        commonBuildInputs = with pkgs; [
          wayland
          libxkbcommon
        ];

        udevBackendInputs = with pkgs; [
          udev
          libinput
          libgbm
          seatd
          mesa
        ];

        x11Inputs = with pkgs; [
          xorg.libX11
          xorg.libXcursor
          xwayland
        ];

        graphicsInputs = with pkgs; [
          vulkan-loader
          vulkan-headers
          libGL
          libglvnd
        ];

        nativeBuildInputs = with pkgs; [
          rustToolchain
          pkg-config
          cmake
        ];

        buildInputs = commonBuildInputs 
          ++ udevBackendInputs 
          ++ x11Inputs 
          ++ graphicsInputs;

      in
      {
        devShells.default = pkgs.mkShell {
          inherit nativeBuildInputs buildInputs;

          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH"
            export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" buildInputs}"
            
            # Vulkan setup
            export VK_LAYER_PATH="${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d"
            
            echo "Anvil development environment loaded"
            echo "Available commands:"
            echo "  cargo run -- --x11        # Run with X11 backend"
            echo "  cargo run -- --winit      # Run with Winit backend"
            echo "  cargo run -- --tty-udev   # Run with TTY/udev backend (requires root/logind)"
          '';

          RUST_BACKTRACE = "1";
          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
        };

        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "anvil";
          version = "0.0.1";

          src = ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
          };

          inherit nativeBuildInputs buildInputs;

          doCheck = false;

          meta = with pkgs.lib; {
            description = "Anvil - A Wayland compositor testing ground for Smithay";
            homepage = "https://github.com/Smithay/smithay";
            license = licenses.mit;
            platforms = platforms.linux;
            mainProgram = "anvil";
          };
        };
      }
    );
}
