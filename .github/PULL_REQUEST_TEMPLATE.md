# Pull Request

## Summary

Describe what changed and why.

## Validation

Paste command output or confirm each check:

- [ ] `nix flake check --no-build`
- [ ] `pytest tests/test_migration.py -q` (via nix-shell)
- [ ] `nix build .#nixosConfigurations.x15xs.config.system.build.toplevel --no-link`

## Docs

- [ ] Updated relevant docs (`README.md`, `END4_SETTINGS.md`, `HYPRLAND_CONTROLS.md`)

## Notes

List any known follow-ups or tradeoffs.
