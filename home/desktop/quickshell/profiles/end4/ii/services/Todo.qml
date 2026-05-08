pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property var filePath: Directories.todoPath
    property var list: []

    function normalizeItem(item) {
        let content = ""
        let done = false

        if (typeof item === "string") {
            content = item
        } else if (item && typeof item === "object") {
            if (item.content !== undefined && item.content !== null) {
                content = String(item.content)
            }
            done = item.done === true
        }

        content = content.trim()
        if (content.length === 0) {
            return null
        }

        return {
            "content": content,
            "done": done,
        }
    }

    function normalizeList(candidate) {
        if (!candidate || candidate.constructor !== Array) {
            return []
        }

        const normalized = []
        for (let i = 0; i < candidate.length; i++) {
            const item = normalizeItem(candidate[i])
            if (item) {
                normalized.push(item)
            }
        }

        return normalized
    }

    function persistList() {
        const nextList = normalizeList(root.list)
        root.list = nextList
        todoFileView.setText(JSON.stringify(nextList, null, 2))
    }

    function addItem(item) {
        const normalizedItem = normalizeItem(item)
        if (!normalizedItem) {
            return false
        }

        const nextList = normalizeList(root.list)
        nextList.push(normalizedItem)
        root.list = nextList
        persistList()
        return true
    }

    function addTask(desc) {
        return addItem({
            "content": desc,
            "done": false,
        })
    }

    function setDone(index, done) {
        const nextList = normalizeList(root.list)
        if (index < 0 || index >= nextList.length) {
            return
        }

        nextList[index].done = done
        root.list = nextList
        persistList()
    }

    function markDone(index) {
        setDone(index, true)
    }

    function markUnfinished(index) {
        setDone(index, false)
    }

    function deleteItem(index) {
        const nextList = normalizeList(root.list)
        if (index < 0 || index >= nextList.length) {
            return
        }

        nextList.splice(index, 1)
        root.list = nextList
        persistList()
    }

    function loadListFromDisk() {
        const rawText = (todoFileView.text() || "").trim()

        if (rawText.length === 0) {
            console.log("[To Do] Empty file, resetting list.")
            root.list = []
            persistList()
            return
        }

        try {
            const parsed = JSON.parse(rawText)
            const normalized = normalizeList(parsed)
            root.list = normalized

            if (JSON.stringify(parsed) !== JSON.stringify(normalized)) {
                persistList()
            }

            console.log("[To Do] File loaded")
        } catch (error) {
            console.log("[To Do] Invalid file contents, resetting list: " + error)
            root.list = []
            persistList()
        }
    }

    function refresh() {
        todoFileView.reload()
    }

    Component.onCompleted: {
        refresh()
    }

    FileView {
        id: todoFileView
        path: Qt.resolvedUrl(root.filePath)

        onLoaded: {
            root.loadListFromDisk()
        }

        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                console.log("[To Do] File not found, creating new file.")
                root.list = []
                persistList()
            } else {
                console.log("[To Do] Error loading file: " + error)
            }
        }
    }
}
