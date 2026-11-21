pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// AI usage from yunagi-ai-usage: the AI account's agents in /home/delat, your own
// (Grok Bot) in ~/.local/state. Read by the robot in the bar and the AI page.
Singleton {
    id: usage

    property var shared: null
    property var own: null
    property real now: Date.now()
    readonly property var agents: {
        const a = shared ? shared.agents || [] : [];
        return a.concat((own ? own.agents || [] : []).filter(o => !a.some(b => b.id === o.id)));
    }

    function peak(a) {
        return Math.max(0, ...(a.limits || []).map(l => l.used));
    }
    function color(u) {
        return u >= 0.9 ? "#f7768e" : u >= 0.7 ? "#e0af68" : Colors.primary;
    }
    function until(iso) {
        const s = (new Date(iso).getTime() - now) / 1000;
        if (!(s > 0)) return "now";
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
        return h >= 24 ? Math.floor(h / 24) + "d " + h % 24 + "h" : h ? h + "h " + m + "m" : m + "m";
    }
    // Share of the window already gone; use above it is ahead of pace
    function gone(l) {
        if (!l.windowMins || !l.resetsAt) return 0;
        const left = (new Date(l.resetsAt).getTime() - now) / 60000;
        return Math.min(1, Math.max(0, 1 - left / l.windowMins));
    }

    FileView {
        id: sharedFile
        path: "/home/delat/ai-usage.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { usage.shared = JSON.parse(text()); } catch (e) {} }
        onLoadFailed: usage.shared = null
    }
    FileView {
        id: ownFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/yunagi/ai-usage.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { usage.own = JSON.parse(text()); } catch (e) {} }
        onLoadFailed: usage.own = null
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: { usage.now = Date.now(); sharedFile.reload(); ownFile.reload(); }
    }
}
