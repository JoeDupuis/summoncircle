{ pkgs, lib, config, inputs, ... }:
{

  cachix.enable = false;

  env = {
    LD_LIBRARY_PATH = "${config.devenv.profile}/lib";
  };

  packages = with pkgs; [
    git
    libyaml
    sqlite-interactive
    bashInteractive
    openssl
    curl
    libxml2
    libxslt
    libffi
  ];

  languages.ruby.enable = true;
  languages.ruby.versionFile = ./.ruby-version;
}
