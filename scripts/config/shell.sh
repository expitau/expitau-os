#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

bind '"\t":menu-complete'

alias ls='ls --color=auto'
alias grep='grep --color=auto'

# source /etc/profile.d/trueline.sh
prompt_command() {
    local STATUS=$?;
    local BRANCH=$(git branch --show-current 2>/dev/null);
    
    PS1="\n╭─ \w";
    [ -n "$BRANCH" ] && PS1+=" \[\e[38;5;248m\]$BRANCH\[\e[0m\]";
    [ "$STATUS" -ne 0 ] && PS1+=" \[\e[38;5;203m\]$STATUS\[\e[0m\]";
    
    PS1+="\n╰ ";
    
    if [[ "$(uname -n)" == *devbox* ]]; then
        PS1+="\[\e[38;5;75;1m\]λ\[\e[0m\] ";
    elif [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
        PS1+="\[\e[38;5;71;1m\]λ\[\e[0m\] ";
    elif [ "$(whoami)" = "root" ]; then
        PS1+="\[\e[38;5;203;1m\]λ\[\e[0m\] ";
    else
        PS1+="\[\e[38;5;141;1m\]λ\[\e[0m\] ";
    fi
}

PROMPT_COMMAND='prompt_command'
