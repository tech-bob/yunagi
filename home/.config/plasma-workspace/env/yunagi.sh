# Hyprland puts QT_QPA_PLATFORMTHEME (xdgdesktopportal) in the systemd user
# environment, and it stays there after logging out. Plasma started with it waits
# on the portal and stays black.
unset QT_QPA_PLATFORMTHEME GTK_THEME QT_WAYLAND_DISABLE_WINDOWDECORATION
systemctl --user unset-environment QT_QPA_PLATFORMTHEME GTK_THEME QT_WAYLAND_DISABLE_WINDOWDECORATION
