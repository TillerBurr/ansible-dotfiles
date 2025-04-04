if status is-interactive
    # Commands to run in interactive sessions can go here
end
set -x DISPlAY :0
# set -x DISPLAY $(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
# set -e WAYLAND_DISPLAY
# setxkbmap -layout us -variant dvorak
# set -x WAYLAND_DISPLAY 'wayland-1'
# set -x GDK_BACKEND x11
fish_add_path -p ~/.local/bin
fish_add_path -p ~/.cargo/bin
fish_add_path -p ~/chromedrivers
fish_add_path -p ~/tools/lua-language-server/bin
fish_add_path -p ~/tools/ripgrep
fish_add_path -p ~/tools/nvim/bin
fish_add_path -p ~/.local/share/nvim/mason/bin/

set -gx PIPX_DEFAULT_PYTHON $HOME/.local/share/mise/installs/python/3.11.4/bin/python
set -gx DPRINT_INSTALL $HOME/.dprint

set -Ux fish_tmux_unicode true
set -x GPG_TTY (tty)
# echo $(tty)
set -x DISPLAY :0
# gpg-connect-agent updatestartuptty /bye >/dev/null
# if not test -f ~/.gnupg/S.gpg-agent
#     eval (gpg-agent --daemon --options ~/.gnupg/gpg-agent.conf)
# end

# set -x GPG_AGENT_INFO $HOME/.gnupg/S.gpg-agent:0:1

if test -d $HOME/.pyenv
    eval (pyenv init --path)
end

if test -e ~/.private
    source ~/.private
end
# eval (aactivator init)

set -U fish_greeting "🐟"
set -x UID $(id -u)
set -x GID $(id -g)
set -x UNAME $(whoami)
set -U autovenv_enable yes
set -U autovenv_announce yes

starship init fish | source
#scheme set default
set -x MISE_CONFIG_FILE $HOME/.config/.mise.toml
set mise_bin $HOME/.local/bin/mise
if type -q $mise_bin
    $mise_bin activate -s fish | source
end

# source $HOME/.local/git-subrepo/.fish.rc
fish_add_path -p ~/.rye/shims
fish_add_path -p $DPRINT_INSTALL/bin

# bit
if not string match -q -- "/home/tbaur/bin" $PATH
  set -gx PATH $PATH "/home/tbaur/bin"
end
# bit end

if type -q thefuck
    thefuck --alias | source
end
if type -q jj
    jj util completion fish | source
end


# Temporary fix for WSLg keyboard layout (only change the first line)
# Temporary fix for WSLg keyboard layout (only change the first line)
# bash $HOME/.config/fish/keyboard.sh
