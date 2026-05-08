#!/usr/bin/env python3
import os
import glob
import json
import shlex
import shutil

def fetch_apps():
    apps = {}
    home = os.path.expanduser('~')

    data_dirs = [
        os.environ.get('XDG_DATA_HOME', f'{home}/.local/share'),
        f'{home}/.local/state/nix/profiles/home-manager/home-path/share',
        f'/etc/profiles/per-user/{os.environ.get("USER", "asura")}/share',
        f'{home}/.nix-profile/share',
    ]
    data_dirs.extend(os.environ.get(
        'XDG_DATA_DIRS',
        '/run/current-system/sw/share:/usr/local/share:/usr/share',
    ).split(':'))
    data_dirs.extend([
        '/var/lib/flatpak/exports/share',
        f'{home}/.local/share/flatpak/exports/share',
        '/var/lib/snapd/desktop',
    ])

    dirs = []
    for base in data_dirs:
        if not base:
            continue
        app_dir = os.path.join(os.path.expanduser(base), 'applications')
        if app_dir not in dirs:
            dirs.append(app_dir)

    for d in dirs:
        if not os.path.exists(d):
            continue

        for f in glob.glob(os.path.join(d, '**/*.desktop'), recursive=True):
            try:
                with open(f, 'r', encoding='utf-8') as file:
                    app = {'name': '', 'exec': '', 'icon': ''}
                    is_desktop = False
                    app_type = ''
                    hidden = False
                    no_display = False
                    try_exec = ''

                    for line in file:
                        line = line.strip()
                        if not line or line.startswith('#'):
                            continue
                        if line == '[Desktop Entry]':
                            is_desktop = True
                        elif line.startswith('['):
                            is_desktop = False

                        if is_desktop:
                            if '=' not in line:
                                continue
                            key, value = line.split('=', 1)
                            if key == 'Type':
                                app_type = value
                            elif key == 'Name' and not app['name']:
                                app['name'] = value
                            elif key == 'Exec' and not app['exec']:
                                parts = [
                                    part for part in shlex.split(value.replace('@@', '').replace('@@u', ''))
                                    if not part.startswith('%')
                                ]
                                app['exec'] = ' '.join(shlex.quote(part) for part in parts)
                            elif key == 'Icon' and not app['icon']:
                                app['icon'] = value
                            elif key == 'NoDisplay' and value.lower() in ('true', '1'):
                                no_display = True
                            elif key == 'Hidden' and value.lower() in ('true', '1'):
                                hidden = True
                            elif key == 'TryExec':
                                try_exec = value

                    if try_exec and not os.path.isabs(try_exec):
                        try_exec = shutil.which(try_exec) or try_exec

                    if (
                        app['name']
                        and app['exec']
                        and app_type in ('', 'Application')
                        and not hidden
                        and not no_display
                        and (not try_exec or os.path.exists(try_exec))
                    ):
                        desktop_id = os.path.basename(f)
                        if desktop_id not in apps:
                            apps[desktop_id] = app
            except Exception:
                pass

    # Sort alphabetically and return as JSON
    res = list(apps.values())
    res.sort(key=lambda x: x['name'].lower())
    print(json.dumps(res))

if __name__ == "__main__":
    fetch_apps()
