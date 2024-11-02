{
  description = "Zen Browser"; # Description of the flake

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable"; # Import nixpkgs from the unstable branch
  };

  outputs =
    { self
    , nixpkgs
    ,
    }:
    let
      system = "x86_64-linux"; # Define the target system architecture
      version = "1.0.1-a.17"; # Define the version of Zen Browser
      downloadUrl = {
        "specific" = {
          url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-specific.tar.bz2"; # URL for the specific variant
          sha256 = "sha256:1cd7ac6v2p6psilvdi5gazqbwk3fzwlragrfg0i1gsj6pp8sbd7a"; # SHA256 hash for the specific variant
        };
        "generic" = {
          url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-generic.tar.bz2"; # URL for the generic variant
          sha256 = "sha256:1yn9yb3j0b0r2shqwk4i3922vap2mpv8gpi3zdpryzr6ins5qylr"; # SHA256 hash for the generic variant
        };
      };

      pkgs = import nixpkgs {
        inherit system; # Import nixpkgs for the specified system
      };

      runtimeLibs = with pkgs;
        [
          libGL
          libGLU
          libevent
          libffi
          libjpeg
          libpng
          libstartup_notification
          libvpx
          libwebp
          stdenv.cc.cc
          fontconfig
          libxkbcommon
          zlib
          freetype
          gtk3
          libxml2
          dbus
          xcb-util-cursor
          alsa-lib
          libpulseaudio
          pango
          atk
          cairo
          gdk-pixbuf
          glib
          udev
          libva
          mesa
          libnotify
          cups
          pciutils
          ffmpeg
          libglvnd
          pipewire
        ]
        ++ (with pkgs.xorg; [
          libxcb
          libX11
          libXcursor
          libXrandr
          libXi
          libXext
          libXcomposite
          libXdamage
          libXfixes
          libXScrnSaver
        ]); # List of runtime libraries required by Zen Browser

      mkZen = { variant }:
        let
          downloadData = downloadUrl."${variant}"; # Select the download URL and SHA256 hash based on the variant
        in
        pkgs.stdenv.mkDerivation {
          inherit version; # Inherit the version defined earlier
          pname = "zen-browser"; # Package name

          src = builtins.fetchTarball {
            url = downloadData.url; # Fetch the source tarball from the specified URL
            sha256 = downloadData.sha256; # Verify the tarball with the specified SHA256 hash
          };

          desktopSrc = ./.; # Source directory for desktop files

          phases = [ "installPhase" "fixupPhase" ]; # Define the build phases

          nativeBuildInputs = [ pkgs.makeWrapper pkgs.copyDesktopItems pkgs.wrapGAppsHook ]; # Native build inputs

          installPhase = ''
            mkdir -p $out/bin && cp -r $src/* $out/bin # Copy the source files to the output bin directory
            install -D $desktopSrc/zen.desktop $out/share/applications/zen.desktop # Install the desktop entry
            install -D $src/browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/zen.png # Install the application icon
          '';

          fixupPhase =
            /*
          sh
            */
            ''
              # Set executable permissions on all files in the bin directory
              chmod 755 $out/bin/*

              # Patch the ELF interpreter for the zen binary to use the correct dynamic linker
              patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/zen

              # Wrap the zen binary with the required environment variables
              wrapProgram $out/bin/zen --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}" \
                                      --set MOZ_LEGACY_PROFILES 1 \
                                      --set MOZ_ALLOW_DOWNGRADE 1 \
                                      --set MOZ_APP_LAUNCHER zen \
                                      --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"

              # Patch the ELF interpreter for the zen-bin binary to use the correct dynamic linker
              patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/zen-bin

              # Wrap the zen-bin binary with the required environment variables
              wrapProgram $out/bin/zen-bin --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}" \
                                          --set MOZ_LEGACY_PROFILES 1 \
                                          --set MOZ_ALLOW_DOWNGRADE 1 \
                                          --set MOZ_APP_LAUNCHER zen \
                                          --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"

              # Patch the ELF interpreter for the glxtest binary to use the correct dynamic linker
              patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/glxtest

              # Wrap the glxtest binary with the required environment variables
              wrapProgram $out/bin/glxtest --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"

              # Patch the ELF interpreter for the updater binary to use the correct dynamic linker
              patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/updater

              # Wrap the updater binary with the required environment variables
              wrapProgram $out/bin/updater --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"

              # Patch the ELF interpreter for the vaapitest binary to use the correct dynamic linker
              patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/vaapitest

              # Wrap the vaapitest binary with the required environment variables
              wrapProgram $out/bin/vaapitest --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}"
            '';

          meta.mainProgram = "zen"; # Define the main program
        };
    in
    {
      packages."${system}" = {
        generic = mkZen { variant = "generic"; }; # Define the generic package
        specific = mkZen { variant = "specific"; }; # Define the specific package
        default = self.packages."${system}".specific; # Set the default package to the specific variant
      };
    };
}
