import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "LinearApi.js" as Api

Item {
    id: root

    required property string pluginId
    required property var pluginService
    readonly property var preferences: SettingsData.pluginSettings[pluginId] ?? ({})
    readonly property string defaultKeyPath: (Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config")) + "/dank-todo/linear-api-key"
    readonly property string keyPath: String(preferences.apiKeyPath || "").trim() || defaultKeyPath

    property var viewer: null
    property var teams: []
    property var issues: []
    property bool busy: false
    property bool connected: false
    property string pendingIssueId: ""
    property string _errorCode: ""
    readonly property string error: _errorCode ? errorText(_errorCode) : ""
    property string lastSyncedAt: ""
    readonly property int activeCount: issues.filter(t => t.isMine && !Api.isDone(t)).length
    readonly property int doneCount: issues.filter(t => t.isMine && Api.isDone(t)).length
    property string _apiKey: ""
    property var _request: null
    property int _generation: 0
    property bool _writing: false
    property bool _initialized: false

    signal mutationFinished(bool success)

    function treeRows(filterKey, collapsedIds) {
        return Api.treeRows(issues, filterKey, collapsedIds)
    }

    function errorText(code) {
        switch (code) {
        case "keyFormat": return I18n.trFor("dankTodo", "The API key file must contain one key and nothing else.")
        case "keyRead": return I18n.trFor("dankTodo", "Cannot read the API key file. Check the configured path and file permissions.")
        case "auth": return I18n.trFor("dankTodo", "Linear authentication failed. Check the key and its permissions.")
        case "rate": return I18n.trFor("dankTodo", "Linear rate limit reached. Wait before refreshing.")
        case "timeout": return I18n.trFor("dankTodo", "Request timed out. Refresh to check whether changes were applied.")
        case "response": return I18n.trFor("dankTodo", "Linear could not complete this request. Refresh and try again.")
        default: return I18n.trFor("dankTodo", "Unable to reach Linear. Check your connection and refresh.")
        }
    }

    function cancelRequest() {
        _generation++
        requestTimeout.stop()
        if (_request)
            _request.cancel()
        _request = null
        busy = false
        pendingIssueId = ""
    }

    function fail(code) {
        requestTimeout.stop()
        _request = null
        busy = false
        pendingIssueId = ""
        if (code === "auth")
            connected = false
        _errorCode = code
        if (_writing) {
            _writing = false
            mutationFinished(false)
        }
    }

    function send(query, variables, callback) {
        const generation = _generation
        requestTimeout.restart()
        _request = Api.request(_apiKey, query, variables, function (data, code) {
            // Handle immediate transport failures asynchronously, like network replies.
            Qt.callLater(function () {
                if (generation !== root._generation)
                    return
                requestTimeout.stop()
                root._request = null
                if (code) {
                    root.fail(code)
                    return
                }
                callback(data)
            })
        })
    }

    function resetConnection() {
        cancelRequest()
        if (_writing) {
            _writing = false
            mutationFinished(false)
        }
        _apiKey = ""
        viewer = null
        teams = []
        issues = []
        lastSyncedAt = ""
        connected = false
        _errorCode = ""
    }

    function reloadCredentials() {
        resetConnection()
        keyFile.reload()
    }

    function refresh() {
        if (busy)
            return false
        if (!_apiKey) {
            reloadCredentials()
            return false
        }
        busy = true
        _errorCode = ""
        loadTeams([], null)
        return true
    }

    function loadTeams(collected, cursor) {
        send(Api.bootstrapQuery, { after: cursor }, function (data) {
            if (!data.viewer || !data.viewer.id || !Api.validPage(data.teams)) {
                root.fail("response")
                return
            }
            const page = data.teams
            for (const team of page.nodes) {
                if (!team || !team.id || !Api.validPage(team.states) || team.states.pageInfo.hasNextPage
                        || !team.states.nodes.every(s => s && s.id && typeof s.name === "string" && typeof s.type === "string")) {
                    root.fail("response")
                    return
                }
                collected.push({
                    id: team.id, name: team.name,
                    states: team.states.nodes.slice().sort((a, b) => a.position - b.position)
                })
            }
            if (page.pageInfo.hasNextPage) {
                root.loadTeams(collected, page.pageInfo.endCursor)
                return
            }
            root.viewer = data.viewer
            root.teams = collected
            root.connected = true
            root.loadIssues([], null)
        })
    }

    function loadIssues(collected, cursor) {
        send(Api.issuesQuery, { viewer: viewer.id, after: cursor }, function (data) {
            if (!Api.validPage(data.issues) || !data.issues.nodes.every(t => Api.validIssue(t)
                    && (!t.parent || Api.validIssue(t.parent)))) {
                root.fail("response")
                return
            }
            const page = data.issues
            const next = collected.concat(page.nodes.map(t => Object.assign({}, t, { isMine: true })))
            if (page.pageInfo.hasNextPage) {
                root.loadIssues(next, page.pageInfo.endCursor)
                return
            }
            const byId = new Map(next.map(t => [t.id, t]))
            for (const issue of next) {
                if (issue.parent && !byId.has(issue.parent.id))
                    byId.set(issue.parent.id, Object.assign({}, issue.parent, { isMine: false }))
            }
            root.loadAncestors(byId)
        })
    }

    function loadAncestors(byId) {
        const missing = Array.from(byId.values()).find(t => t.parent && !byId.has(t.parent.id))
        if (missing) {
            send(Api.parentQuery, { id: missing.parent.id }, function (data) {
                if (!Api.validIssue(data.issue) || (data.issue.parent && !Api.validIssue(data.issue.parent))) {
                    root.fail("response")
                    return
                }
                byId.set(data.issue.id, Object.assign({}, data.issue, { isMine: false }))
                root.loadAncestors(byId)
            })
            return
        }
        issues = Array.from(byId.values())
        lastSyncedAt = new Date().toISOString()
        busy = false
    }

    function canCompleteIssue(id) {
        const issue = issues.find(t => t.id === id && t.isMine)
        const team = issue ? teams.find(t => t.id === issue.team.id) : null
        return !busy && connected && !!viewer && !!viewer.id && !!issue
            && !Api.isDone(issue) && !!team && team.states.some(s => s.type === "completed")
    }

    function completeIssue(id) {
        if (!canCompleteIssue(id))
            return false
        const issue = issues.find(t => t.id === id)
        const team = teams.find(t => t.id === issue.team.id)
        const state = team.states.find(s => s.type === "completed")
        busy = true
        _writing = true
        pendingIssueId = id
        _errorCode = ""
        send(Api.updateMutation, { id: id, input: { stateId: state.id } }, function (data) {
            if (!data.issueUpdate || data.issueUpdate.success !== true) {
                root.fail("response")
                return
            }
            root._writing = false
            root.pendingIssueId = ""
            // The server confirmed the mutation, even if the following refresh fails.
            root.mutationFinished(true)
            root.loadIssues([], null)
        })
        return true
    }

    FileView {
        id: keyFile
        path: root.keyPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.resetConnection()
            const key = text().trim()
            if (!key || /\s/.test(key)) {
                root._apiKey = ""
                root.connected = false
                root._errorCode = "keyFormat"
                return
            }
            root._apiKey = key
            root.refresh()
        }
        onLoadFailed: {
            root.resetConnection()
            root._errorCode = "keyRead"
        }
        onFileChanged: root.reloadCredentials()
    }

    Timer {
        id: requestTimeout
        interval: 20000
        onTriggered: {
            root.cancelRequest()
            root.fail("timeout")
        }
    }

    // Shared IPC exposes no key, and never accepts credentials as command arguments.
    IpcHandler {
        target: "dankTodo"
        function refresh(): string { return root.refresh() ? "STARTED" : "NOT_STARTED" }
        function list(): string { return JSON.stringify(root.issues.filter(t => t.isMine)) }
        function count(): string { return root.activeCount + "/" + (root.activeCount + root.doneCount) }
    }

    onKeyPathChanged: {
        if (_initialized)
            reloadCredentials()
    }
    Component.onCompleted: {
        _initialized = true
        reloadCredentials()
    }
    Component.onDestruction: cancelRequest()
}
