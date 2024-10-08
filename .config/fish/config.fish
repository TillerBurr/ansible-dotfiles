if status is-interactive
    # Commands to run in interactive sessions can go here
end

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
set -x GPG_TTY $(tty)
# echo $(tty)
# set -e DISPLAY
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
$HOME/.local/bin/mise activate -s fish | source

# source $HOME/.local/git-subrepo/.fish.rc
fish_add_path -p ~/.rye/shims
fish_add_path -p $DPRINT_INSTALL/bin

# bit
if not string match -q -- "/home/tbaur/bin" $PATH
  set -gx PATH $PATH "/home/tbaur/bin"
end
# bit end

thefuck --alias | source
