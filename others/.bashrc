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

export PATH=$HOME/.cargo/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/opt/homebrew/opt/llvm/bin:$HOME/Documents/personal/go/bin:$HOME/Documents/personal/go/bin:/opt/homebrew/opt/node@14/bin:/opt/homebrew/opt/libpq/bin:$PATH
export GOPATH=$HOME/Documents/salt/go/src/

export salt="cd $HOME/Documents/salt"
export personal="cd $HOME/Documents/personal"

export LDFLAGS="-L/opt/homebrew/opt/node@14/lib"
export CPPFLAGS="-I/opt/homebrew/opt/node@14/include"

alias vim="nvim"
alias vi="nvim"
alias v="nvim"
alias l="lazygit"
# alias python="python3"

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

export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
