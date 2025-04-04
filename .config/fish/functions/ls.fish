function ls
    if type -q eza
        eza --icons $argv
    else if type -q lsd
        lsd $argv
    else
        /usr/bin/ls --color $argv
    end
end
