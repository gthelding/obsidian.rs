{
  description = "obsidian.rs — CLI, MCP, and LSP tools for Obsidian vaults";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs) lib rustPlatform;

          # Shared workspace build. `buildAndTestSubdir` selects one Cargo workspace
          # member; path deps (obsidian-core) are still built from the monorepo root.
          mkCrate =
            {
              pname,
              subdir,
              mainProgram,
              description,
            }:
            rustPlatform.buildRustPackage {
              inherit pname;
              version = "0.5.0-unstable";
              src = self;

              cargoLock.lockFile = ./Cargo.lock;

              buildAndTestSubdir = subdir;

              # Integration tests are covered in CI; skip here for faster client installs.
              doCheck = false;

              meta = {
                inherit description mainProgram;
                homepage = "https://github.com/epwalsh/obsidian.rs";
                license = lib.licenses.asl20;
                platforms = lib.platforms.unix;
              };
            };

          obsidian-rs = mkCrate {
            pname = "obsidian-rs";
            subdir = "obsidian-cli";
            mainProgram = "obsidian-rs";
            description = "CLI for querying and managing Obsidian vaults";
          };

          obsidian-mcp = mkCrate {
            pname = "obsidian-mcp";
            subdir = "obsidian-mcp";
            mainProgram = "obsidian-mcp";
            description = "MCP server for interacting with Obsidian vaults";
          };

          obsidian-lsp = mkCrate {
            pname = "obsidian-lsp";
            subdir = "obsidian-lsp";
            mainProgram = "obsidian-lsp";
            description = "Language server for editing Obsidian vaults";
          };

          # Convenience package: CLI + MCP (the usual agent/desktop combo).
          obsidian-rs-tools = pkgs.symlinkJoin {
            name = "obsidian-rs-tools";
            paths = [
              obsidian-rs
              obsidian-mcp
            ];
            meta = {
              description = "obsidian.rs CLI and MCP server";
              homepage = "https://github.com/epwalsh/obsidian.rs";
              license = lib.licenses.asl20;
              mainProgram = "obsidian-rs";
              platforms = lib.platforms.unix;
            };
          };
        in
        {
          default = obsidian-rs-tools;
          inherit obsidian-rs obsidian-mcp obsidian-lsp obsidian-rs-tools;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.obsidian-rs}/bin/obsidian-rs";
        };
        obsidian-rs = {
          type = "app";
          program = "${self.packages.${system}.obsidian-rs}/bin/obsidian-rs";
        };
        obsidian-mcp = {
          type = "app";
          program = "${self.packages.${system}.obsidian-mcp}/bin/obsidian-mcp";
        };
        obsidian-lsp = {
          type = "app";
          program = "${self.packages.${system}.obsidian-lsp}/bin/obsidian-lsp";
        };
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              cargo
              rustc
              rustfmt
              clippy
              rust-analyzer
              pkg-config
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
