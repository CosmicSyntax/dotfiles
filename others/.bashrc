# function print_centered {
#      [[ $# == 0 ]] && return 1
#
#      declare -i TERM_COLS="$(tput cols)"
#      declare -i str_len="${#1}"
#      [[ $str_len -ge $TERM_COLS ]] && {
#           echo -e "$1";
#           return 0;
#      }
#
#      declare -i filler_len="$(( (TERM_COLS - str_len) / 2 ))"
#      [[ $# -ge 2 ]] && ch="${2:0:1}" || ch=" "
#      filler=""
#      for (( i = 0; i < filler_len; i++ )); do
#           filler="${filler}${ch}"
#      done
#
#      printf "\e[1;92m%s%s%s\e[m" "$filler" "$1" "$filler"
#      [[ $(( (TERM_COLS - str_len) % 2 )) -ne 0 ]] && printf "%s" "${ch}"
#      printf "\n"
#
#      return 0
# }
#
# echo ""
# print_centered " ░░     ░░ ░░░░░░░ ░░       ░░░░░░  ░░░░░░  ░░░    ░░░ ░░░░░░░     ░░░░░░   ░░░░░  ░░░    ░░ ░░ "
# print_centered " ▒▒     ▒▒ ▒▒      ▒▒      ▒▒      ▒▒    ▒▒ ▒▒▒▒  ▒▒▒▒ ▒▒          ▒▒   ▒▒ ▒▒   ▒▒ ▒▒▒▒   ▒▒ ▒▒ "
# print_centered " ▒▒  ▒  ▒▒ ▒▒▒▒▒   ▒▒      ▒▒      ▒▒    ▒▒ ▒▒ ▒▒▒▒ ▒▒ ▒▒▒▒▒       ▒▒   ▒▒ ▒▒▒▒▒▒▒ ▒▒ ▒▒  ▒▒ ▒▒ "
# print_centered " ▓▓ ▓▓▓ ▓▓ ▓▓      ▓▓      ▓▓      ▓▓    ▓▓ ▓▓  ▓▓  ▓▓ ▓▓          ▓▓   ▓▓ ▓▓   ▓▓ ▓▓  ▓▓ ▓▓    "
# print_centered "  ███ ███  ███████ ███████  ██████  ██████  ██      ██ ███████     ██████  ██   ██ ██   ████ ██ "
# echo ""

export PATH=$HOME/.cargo/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/opt/homebrew/opt/llvm/bin:$HOME/Documents/randori/go/src/bin:/usr/local/go/bin:~/Documents/randori/python/skycrane/bin:$PATH
export GOPATH=$HOME/Documents/randori/go/src/

export rand="cd $HOME/Documents/randori"
export personal="cd $HOME/Documents/personal"

alias vim="nvim"
alias vi="nvim"
alias v="nvim"
alias l="lazygit"
alias ss="systemctl suspend"

if command -v pyenv 1>/dev/null 2>&1; then
	eval "$(pyenv init -)"
fi

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

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PATH=/home/dchoi/Documents/randori/python/skycrane/bin:$PATH
