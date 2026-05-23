{
  description = "Rust development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    utils.url = "github:numtide/flake-utils";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      crane,
      rust-overlay,
      advisory-db,
      ...
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        # Import nixpkgs with rust-overlay applied
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        inherit (pkgs) lib;

        # Read ./rust-toolchain.toml, just like rustup.
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

        # Create a crane library instance using this toolchain.
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        # Clean project source (drops target/, .git, etc.).
        # ! Assumes Cargo.toml and Cargo.lock are at the repo root.
        src = craneLib.cleanCargoSource (craneLib.path ./.);

        # Shared build arguments.
        commonArgs = {
          inherit src;
          strictDeps = true;

          buildInputs = [
            # Add system libraries here if needed, e.g.:
            # pkgs.openssl
            # pkgs.sqlite
          ]
          ++ lib.optionals pkgs.stdenv.isDarwin [
            pkgs.libiconv
          ];
        };

        # Build only Cargo dependencies (good for caching / CI).
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        # Main crate derivation.
        #
        # TODO: rename `my-crate` to your package name (e.g. `my-app`).
        my-crate = craneLib.buildPackage (
          commonArgs
          // {
            inherit cargoArtifacts;
            doCheck = false; # Tests are run separately in checks.tests
          }
        );

        checks = {
          inherit my-crate;

          # Build + tests
          tests = craneLib.cargoTest (commonArgs // { inherit cargoArtifacts; });

          clippy = craneLib.cargoClippy (
            commonArgs
            // {
              inherit cargoArtifacts;
              # Fail on any warnings
              cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            }
          );

          # Build documentation and fail on warnings
          doc = craneLib.cargoDoc (
            commonArgs
            // {
              inherit cargoArtifacts;
              env.RUSTDOCFLAGS = "--deny warnings";
            }
          );

          # Check formatting
          fmt = craneLib.cargoFmt {
            inherit src;
          };

          # Format all .toml files using taplo
          toml-fmt = craneLib.taploFmt {
            src = lib.sources.sourceFilesBySuffices src [ ".toml" ];
            # taplo arguments can be further customized below as needed
            # taploExtraArgs = "--config ./taplo.toml";
          };

          # Audit dependencies against RustSec advisory DB
          audit = craneLib.cargoAudit {
            inherit src advisory-db;
          };

          # License / advisory policy checks
          deny = craneLib.cargoDeny {
            inherit src;
          };

          # Run tests with cargo-nextest
          nextest = craneLib.cargoNextest (
            commonArgs
            // {
              inherit cargoArtifacts;
              partitions = 1;
              partitionType = "count";
              cargoNextestPartitionsExtraArgs = "--no-tests=pass";
            }
          );
        };
      in
      {
        # Nix package and `nix run .` entry

        packages = {
          default = my-crate; # TODO: rename `my-crate` if needed
        };

        apps.default = utils.lib.mkApp {
          drv = my-crate; # TODO: rename `my-crate` if needed
        };

        inherit checks;

        # Dev shell for local development (`nix develop`).
        devShells.default = craneLib.devShell {
          # Inherit inputs from all checks (including crate).
          checks = self.checks.${system};

          # Optional: extra shell-only tools
          packages = with pkgs; [
            # pkgs.ripgrep
          ];

          # Standard library sources inside the toolchain (needed by rust-analyzer).
          # Can be removed if rust-src and rust-analyzer are removed from the toolchain components in rust-toolchain.toml.
          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";

          # Optional: keep target/ in the project (instead of /tmp) so
          # incremental builds survive shell restarts.
          CARGO_TARGET_DIR = ".target";

          shellHook = ''
            echo "Loaded Rust dev shell"
            echo "rustc  : $(rustc --version || echo 'not found')"
            echo "cargo  : $(cargo --version || echo 'not found')"
            echo

            echo "Project layout:"
            echo "  - src/lib.rs  : library crate for reusable logic"
            echo "  - src/main.rs : binary crate that can call into the library"
            echo
            echo "Notes:"
            echo "  - You can keep BOTH lib.rs and main.rs:"
            echo "      * 'cargo run' builds and runs the binary from main.rs."
            echo "      * lib.rs is used when other crates depend on this package."
            echo "  - If you want a library-only crate, delete src/main.rs (or move binaries to src/bin/...)."
            echo "  - If you want a binary-only crate, delete src/lib.rs or switch to a bin-only layout."
            echo
            echo "  - Rename 'my-crate' in flake.nix and Cargo.toml to match your package name,"
            echo "    then rebuild Cargo.lock (e.g. delete it and run 'cargo build' or 'nix build .')."
            echo "  - Edit rust-toolchain.toml to change channel/components."
            echo "  - Use 'cargo build', 'cargo test', 'cargo run' as usual."
          '';
        };
      }
    );
}
