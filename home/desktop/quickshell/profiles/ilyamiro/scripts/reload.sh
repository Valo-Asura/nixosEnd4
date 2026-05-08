#!/usr/bin/env bash
qs -p ~/.config/hypr/scripts/quickshell/Main.qml ipc call main forceReload
qs -p ~/.config/hypr/scripts/quickshell/TopBar.qml ipc call topbar forceReload
qs -p ~/.config/hypr/scripts/quickshell/Floating.qml ipc call floating forceReload
