# bash completion
[[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"

# enable color support of ls and also add handy aliases
alias ls='eza'

export PATH=$HOME/.cargo/bin:$HOME/Documents/ibm/go/src/bin:/usr/local/go/bin:$HOME/.local/nvim/bin:/home/dchoi/Documents/personal/lua-language-server/bin:/opt/homebrew/bin:$PATH
export GOPATH=$HOME/Documents/ibm/go/src/

export ibm="cd $HOME/Documents/ibm"
export personal="cd $HOME/Documents/personal"

# podman specific alias
alias p="podman"
alias pstart="podman machine start"
alias pstop="podman machine stop"
alias pprune="podman system prune --all && podman volume prune && podman network prune"
# brew specific alias
alias dnfclean="brew autoremove && brew cleanup --prune=all"
alias dnfupdate="brew update --force"
# other alias
alias l="lazygit"
alias ss="sudo pmset sleepnow"
alias vim="nvim"
alias vi="nvim"
alias v="nvim"

# get current branch in git repo
function parse_git_branch() {
    BRANCH=`git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
    if [ ! "${BRANCH}" == "" ]
    then
        STAT=`parse_git_dirty`
        echo "[${BRANCH}${STAT}]"
    else
        echo ""
    fi
}

# get current status of git repo
function parse_git_dirty {
    status=`git status 2>&1 | tee`
    dirty=`echo -n "${status}" 2> /dev/null | grep "modified:" &> /dev/null; echo "$?"`
    untracked=`echo -n "${status}" 2> /dev/null | grep "Untracked files" &> /dev/null; echo "$?"`
    ahead=`echo -n "${status}" 2> /dev/null | grep "Your branch is ahead of" &> /dev/null; echo "$?"`
    newfile=`echo -n "${status}" 2> /dev/null | grep "new file:" &> /dev/null; echo "$?"`
    renamed=`echo -n "${status}" 2> /dev/null | grep "renamed:" &> /dev/null; echo "$?"`
    deleted=`echo -n "${status}" 2> /dev/null | grep "deleted:" &> /dev/null; echo "$?"`
    bits=''
    if [ "${renamed}" == "0" ]; then
        bits=">${bits}"
    fi
    if [ "${ahead}" == "0" ]; then
        bits="*${bits}"
    fi
    if [ "${newfile}" == "0" ]; then
        bits="+${bits}"
    fi
    if [ "${untracked}" == "0" ]; then
        bits="?${bits}"
    fi
    if [ "${deleted}" == "0" ]; then
        bits="x${bits}"
    fi
    if [ "${dirty}" == "0" ]; then
        bits="!${bits}"
    fi
    if [ ! "${bits}" == "" ]; then
        echo " ${bits}"
    else
        echo ""
    fi
}

export PS1="\W \[\e[32m\]\`parse_git_branch\`\[\e[m\]-> "


# __vte_urlencode() (
#   # This is important to make sure string manipulation is handled
#   # byte-by-byte.
#   LC_ALL=C
#   str="$1"
#   while [ -n "$str" ]; do
#     safe="${str%%[!a-zA-Z0-9/:_\.\-\!\'\(\)~]*}"
#     printf "%s" "$safe"
#     str="${str#"$safe"}"
#     if [ -n "$str" ]; then
#       printf "%%%02X" "'$str"
#       str="${str#?}"
#     fi
#   done
# )
#
# __vte_osc7 () {
#   printf "\033]7;file://%s%s\007" "${HOSTNAME:-}" "$(__vte_urlencode "${PWD}")"
# }
#
# __vte_prompt_command() {
#   local command=$(HISTTIMEFORMAT= history 1 | sed 's/^ *[0-9]\+ *//')
#   command="${command//;/ }"
#   local pwd='~'
#   [ "$PWD" != "$HOME" ] && pwd=${PWD/#$HOME\//\~\/}
#   printf "\033]0;%s@%s:%s\007%s" "${USER}" "${HOSTNAME%%.*}" "${pwd}" "$(__vte_osc7)"
# }
#
# [ -n "$BASH_VERSION" ] && PROMPT_COMMAND="__vte_prompt_command"
# . "$HOME/.cargo/env"
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

rustvim() {
	touch .vimspector.json
	echo '{
	"configurations": {
		"launch": {
			"adapter": "CodeLLDB",
			"configuration": {
				"request": "launch",
				"program": "./target/debug/program"
			}
		}
	}
}' > .vimspector.json
}

pythonvim() {
	touch .vimspector.json
	echo '{
	"configurations": {
		"launch": {
			"adapter": "debugpy",
			"filetypes": [ "python" ],
			"configuration": {
				"request": "launch",
				"type": "python",
				"program": "main.py"
			}
		}
	}
}' > .vimspector.json
}
