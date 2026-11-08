pragma Singleton
import Quickshell

Singleton {
    function isInternal(name) {
        return /^(eDP|LVDS)/.test(name);
    }
}
