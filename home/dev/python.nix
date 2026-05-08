{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.dev.python;
  pythonToolchain = pkgs.python3.withPackages (
    ps: with ps; [
      black
      debugpy
      flake8
      ipykernel
      isort
      jupyterlab
      mypy
      pip
      pylint
      pytest
      ruff
      setuptools
      virtualenv
      wheel
    ]
  );
in
{
  config = lib.mkIf (config.modules.dev.enable && cfg.enable) {
    home.sessionPath = [ "${pythonToolchain}/bin" ];

    home.sessionVariables = {
      PIP_DISABLE_PIP_VERSION_CHECK = "1";
      UV_PYTHON = "${pythonToolchain}/bin/python3";
    };
  };
}
