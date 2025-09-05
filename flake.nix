{
  description = "Nix package and dev shells for the project";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = f:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
          f (import nixpkgs { inherit system; })
        );
    in
    {
      packages = forAllSystems (pkgs:
        let
          python = pkgs.python313;

          # Nix-native Python env (no pip at build time)
          pythonEnv = python.withPackages (ps: with ps; [
            pyusb
            customtkinter
            tkinter
            libusb-package
          ]);
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "watchman-pairing-assistant";
            version = "0.1.0";

            src = ./.;

            # Native libs needed at runtime
            buildInputs = [
              pythonEnv
              pkgs.libusb1
              pkgs.tcl
              pkgs.tk
            ];

            installPhase = ''
              mkdir -p $out/bin
              # Launcher that runs your main script with the prepared Python env
              cat > $out/bin/watchman-pairing-assistant <<'SH'
              #!${pkgs.bash}/bin/bash
              exec ${pythonEnv}/bin/python "$PWD/source/main.py" "$@"
              SH
              chmod +x $out/bin/watchman-pairing-assistant
            '';
          };
        }
      );

      devShells = forAllSystems (pkgs:
        let
          python = pkgs.python313;

          pythonEnv = python.withPackages (ps: with ps; [
            pyusb
            customtkinter
            tkinter
            libusb-package
          ]);
        in
        {
          # Default dev shell: uses nixpkgs Python packages (no pip network access)
          default = pkgs.mkShell {
            packages = [
              pythonEnv
              pkgs.libusb1
              pkgs.tcl
              pkgs.tk
              #pkgs.task
              pkgs.git
            ];
            # Helpful for GUI apps with Tk
            shellHook = ''
              echo "Nix dev shell ready. Try: python source/main.py"
            '';
          };

          # Optional venv dev shell: installs exact versions from requirements.txt via pip
          venv = pkgs.mkShell {
            packages = [
              python
              pkgs.python313Packages.venvShellHook
              pkgs.libusb1
              pkgs.tcl
              pkgs.tk
              pkgs.python313
              #pkgs.task
              pkgs.git
            ];

            # Directory for the virtualenv
            venvDir = ".venv";

            # Create venv and install pinned deps from requirements.txt
            postVenvCreation = ''
              python -m pip install --upgrade pip
              if [ -f requirements.txt ]; then
                pip install -r requirements.txt
              fi
              echo "Virtualenv ready. Activate: source .venv/bin/activate"
            '';

            # For subsequent shells
            postShellHook = ''
              source .venv/bin/activate
              echo "Venv activated. Run: python source/main.py"
            '';
          };
        }
      );
    };
}