{
  inputs = {
    naersk.url = "github:nix-community/naersk/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, utils, naersk, fenix }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        naersk-lib = pkgs.callPackage naersk {
          cargo = toolchain;
          rustc = toolchain;
        };

        rust-toolchain = with fenix.packages.${system}; toolchainOf {
          channel = "nightly";
          date = "2023-03-12";
          sha256 = "sha256-HR9SudxYVO79xHuCrpGEz+MwC8dIW8CO32Eg43KzFSM=";
        };

        toolchain = with fenix.packages.${system}; combine [
          rust-toolchain.cargo
          rust-toolchain.clippy
          rust-toolchain.rustc
          rust-toolchain.rustfmt
          rust-toolchain.rust-std
        ];

        bevyRequirements = with pkgs; [
          udev
          alsa-lib
          vulkan-loader
          xorg.libXcursor
          xorg.libXrandr
          xorg.libXi
          libxkbcommon
        ];

        libPath = with pkgs; lib.makeLibraryPath bevyRequirements;
      in
      {
        defaultPackage = naersk-lib.buildPackage {
          src = ./.;
          pname = "foxtrot";

          nativeBuildInputs = with pkgs; [
            makeWrapper
          ] ++ bevyRequirements;

          buildInputs = with pkgs; [
            pkg-config
            toolchain
            clang
            lld
          ] ++ bevyRequirements;

          postInstall = ''
            wrapProgram "$out/bin/foxtrot" --prefix LD_LIBRARY_PATH : "${libPath}"
            cp -r $src/assets $out/bin/assets
          '';

          cargoBuildOptions = d: d ++ [ "--no-default-features" "--features native"];
        };
        devShell = with pkgs; mkShell {        
          nativeBuildInputs = [
            pkg-config
          ] ++ bevyRequirements;

          buildInputs = [
            pre-commit
            rust-analyzer
            toolchain
            clang
            lld
          ] ++ bevyRequirements;
          RUST_SRC_PATH = rustPlatform.rustLibSrc;
          LD_LIBRARY_PATH = libPath;
        };
      });
}
