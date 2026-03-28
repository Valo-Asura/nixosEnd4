# Contributing

## Scope

This repository is a declarative NixOS + Home Manager setup for the `x15xs` host.
All changes should preserve reproducibility and keep behavior defined in Nix.

## Local Checks

Run these before opening a pull request:

```bash
nix flake check --no-build
nix-shell -p python3 python3Packages.pytest python3Packages.hypothesis --run "pytest tests/test_migration.py -q"
nix build .#nixosConfigurations.x15xs.config.system.build.toplevel --no-link
```

## Change Rules

- Keep ownership clear: one module should own one concern.
- Prefer relative markdown links so docs work on GitHub.
- Update docs when behavior changes.
- Keep generated/local-only files out of git (`.cache`, `.venv`, `__pycache__`, editor state).

## Pull Request Checklist

- [ ] CI passes (`ci` and `markdown` workflows)
- [ ] Structural tests updated when needed
- [ ] Docs updated (`README.md`, `END4_SETTINGS.md`, `HYPRLAND_CONTROLS.md`) if user-visible behavior changed
- [ ] No runtime `git clone` patterns added
