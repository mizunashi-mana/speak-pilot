{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/packages/
  packages = [];

  # https://devenv.sh/languages/
  languages.python.enable = true;
  languages.python.uv.enable = true;

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  enterShell = ''
    if [[ "$(uname)" == "Darwin" ]]
    then
        # filter out xcrun from $PATH
        export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v '/nix/store/.*xcbuild.*/bin' | tr '\n' ':' | sed 's/:$//')
        unset DEVELOPER_DIR
        unset SDKROOT
    fi
  '';

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
