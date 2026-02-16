{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      esp32 = pkgs.dockerTools.pullImage {
        imageName = "espressif/idf-rust";
        imageDigest = "sha256:146ab2f7674cc5d3143db651c3adbc7fbb62a736302c018bc40b2378ca584936";
        sha256 = "56Z+CZgTBw1qhq0ce5gk4oxCB3zrThWRmJZwOPBLDn8=";
        finalImageName = "espressif/idf-rust";
        finalImageTag = "all_1.90.0.0";
      };
    in
    {
      packages.x86_64-linux.esp32 = pkgs.stdenv.mkDerivation {
        name = "esp32";
        src = esp32;
        unpackPhase = ''
          mkdir -p source
          tar -C source -xvf $src
        '';
        sourceRoot = "source";
        nativeBuildInputs = [
          pkgs.autoPatchelfHook
          pkgs.jq
        ];
        buildInputs = [
          pkgs.xz
          pkgs.zlib
          pkgs.libxml2_13
          pkgs.python3
          pkgs.libudev-zero
          pkgs.stdenv.cc.cc
        ];
        buildPhase = ''
          jq -r '.[0].Layers | @tsv' < manifest.json > layers
        '';
        installPhase = ''
          mkdir -p $out
          for i in $(< layers); do
            tar -C $out -xvf "$i" home/esp/.cargo home/esp/.rustup || true
          done
          mv -t $out $out/home/esp/{.cargo,.rustup}
          rmdir $out/home/esp
          rmdir $out/home
          export PATH=$out/.rustup/toolchains/esp/bin:$PATH

          # find Xtensa ELF GCC dynamically
          # export PATH=$out/.rustup/toolchains/esp/xtensa-esp-elf-esp-13.2.0_20230928/stensa-esp-elf/bin:$PATH
          XTENSA_PATH=$(find $out/.rustup/toolchains/esp -type d -name "bin" | grep "xtensa-esp-elf" | head -n 1)
          if [ -n "$XTENSA_PATH" ]; then
            export PATH="$XTENSA_PATH:$PATH"
          fi

          export RUST_SRC_PATH="$(rustc --print sysroot)/lib/rustlib/src/rust/src"
          # [ -d $out/.cargo ] && [ -d $out/.rustup ]
        '';
      };
    };
}
