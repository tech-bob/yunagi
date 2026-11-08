# Yunagi: Pure prompt, eza icons, autopair, no greeting

# Only in interactive sessions
status is-interactive; or exit

# --- No greeting -------------------------------------------------------------
# fastfetch is still available as a command.
function fish_greeting
end

# --- eza (ls with icons), same aliases as CachyOS ---------------------------
if type -q eza
    alias ls='eza -alg --color=always --group-directories-first --icons'  # default listing
    alias la='eza -a  --color=always --group-directories-first --icons'  # all files/directories
    alias ll='eza -lg  --color=always --group-directories-first --icons'  # long format
    alias lt='eza -aT --color=always --group-directories-first --icons'  # tree view
    alias l.="eza -a | grep -e '^\.'"                                     # dotfiles only
end

# --- Colored grep -----------------------------------------------------------
alias grep='grep --color=auto'

