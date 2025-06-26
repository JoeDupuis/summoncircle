{ pkgs, lib, config, inputs, ... }:
{

  cachix.enable = false;

  env = {
    LD_LIBRARY_PATH = "${config.devenv.profile}/lib";
    #dummy dev secrets
    SECRET_KEY_BASE = "7673a7ec4efb3a2bf86ff8631ec2fbd0578a927194e88c30b17231b69ecf47d2904fd1f06e4980d27b0c222eccf260306fd085a08edc291d0fda418230da37fe";
    MCP_AUTH_TOKEN = "0fdec0799098a261cacfefb8d03c86f83c53b535c5f55c68047f911cbade56d6ba6cca28958cb4e60e252950a1ee273c322a31cad119f69f1b65989f414f26e9";
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY="AGLheXe57DJJNZxAiWWam7J16zTIl4eW";
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY="q6Iuf7LiJkpzBgREI6oh1w5PAGP8I7Aa";
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT="tvcLHWLLBKQo4ReCfPC0YslWzewuyzq0";
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
    docker
  ];

  languages.ruby.enable = true;
  languages.ruby.versionFile = ./.ruby-version;
}
