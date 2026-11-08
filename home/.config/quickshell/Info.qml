import Quickshell
import Quickshell.Io

// About: Super+B opens or closes the terminal view
Scope {
    id: root

    function toggle() {
        Quickshell.execDetached(["sh", "-c", "if hyprctl clients | grep -q 'class: yunagi-about$'; then hyprctl dispatch \"hl.dsp.window.close({window='class:yunagi-about'})\"; else exec kitty --class yunagi-about -o font_size=11 -o background_opacity=1 -o confirm_os_window_close=0 -e \"$HOME/.local/bin/yunagi-about\"; fi"]);
    }

    IpcHandler {
        target: "info"
        function toggle(): void {
            root.toggle();
        }
    }
}
