pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell

Singleton {
    id: root
    property var appCommandSubstitutions: ({
        "file-manager": "file-manager",
        "files": "file-manager",
        "nemo": "file-manager",
        "nemo.desktop": "file-manager"
    })

    function isPinned(appId) {
        return Config.options.launcher.pinnedApps.indexOf(appId) !== -1;
    }

    function launchCommand(command) {
        if (!command || command.length === 0)
            return;

        Quickshell.execDetached(["uwsm", "app", "--", "bash", "-lc", command]);
    }

    function launchDesktopEntry(entry) {
        if (!entry)
            return;

        const entryId = entry.id || "";
        if (entryId.length > 0) {
            Quickshell.execDetached(["uwsm", "app", "--", entryId]);
            return;
        }

        entry.execute();
    }

    function normalizedAppIds(appId) {
        const raw = String(appId || "").trim();
        if (raw.length === 0)
            return [];

        const lower = raw.toLowerCase();
        const withoutDesktop = lower.endsWith(".desktop") ? lower.slice(0, -8) : lower;
        const withDesktop = `${withoutDesktop}.desktop`;
        const candidates = [raw, lower, withoutDesktop, withDesktop];
        const seen = ({});

        return candidates.filter(id => {
            if (!id || seen[id])
                return false;

            seen[id] = true;
            return true;
        });
    }

    function lookupDesktopEntry(appId) {
        const candidates = normalizedAppIds(appId);
        for (const candidate of candidates) {
            const entry = DesktopEntries.byId(candidate) || DesktopEntries.heuristicLookup(candidate);
            if (entry)
                return entry;
        }

        return null;
    }

    function launchAppId(appId) {
        const entry = lookupDesktopEntry(appId);
        if (entry) {
            launchDesktopEntry(entry);
            return;
        }

        const command = appCommandSubstitutions[String(appId || "").toLowerCase()];
        if (command) {
            launchCommand(command);
        }
    }

    function togglePin(appId) {
        if (root.isPinned(appId)) {
            Config.options.launcher.pinnedApps = Config.options.launcher.pinnedApps.filter(id => id !== appId)
        } else {
            Config.options.launcher.pinnedApps = Config.options.launcher.pinnedApps.concat([appId])
        }
    }

    function moveToFront(appId) {
        if (!root.isPinned(appId)) return;
        const pinnedApps = Config.options.launcher.pinnedApps;
        Config.options.launcher.pinnedApps = [appId].concat(pinnedApps.filter(id => id !== appId));
    }

    function moveLeft(appId) {
        const pinnedApps = Config.options.launcher.pinnedApps;
        const index = pinnedApps.indexOf(appId);
        if (index === -1 || index === 0) return;
        Config.options.launcher.pinnedApps = pinnedApps.slice(0, index - 1).concat([appId]).concat(pinnedApps[index - 1]).concat(pinnedApps.slice(index + 1));
    }

    function moveRight(appId) {
        const pinnedApps = Config.options.launcher.pinnedApps;
        const index = pinnedApps.indexOf(appId);
        if (index === -1 || index === pinnedApps.length - 1) return;
        Config.options.launcher.pinnedApps = pinnedApps.slice(0, index).concat(pinnedApps[index + 1]).concat([appId]).concat(pinnedApps.slice(index + 2));
    }
}
