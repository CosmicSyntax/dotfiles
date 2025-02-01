# enter vi mode
set -o vi
# enable color support of ls and also add handy aliases
alias ls='eza'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

export PATH=$HOME/.cargo/bin:$HOME/Documents/ibm/go/src/bin:/usr/local/go/bin:$HOME/.local/nvim/bin:$HOME/Documents/ibm/oc:$HOME/Documents/personal/zig/zls/zig-out/bin:$PATH
export GOPATH=$HOME/Documents/ibm/go/src/

export ibm="cd $HOME/Documents/ibm"
export personal="cd $HOME/Documents/personal"

# podman specific alias
alias pprune="podman system prune -af && podman volume prune -f && podman network prune -f"
# fedora specific alias
alias dnfclean="sudo dnf autoremove && sudo dnf clean all"
alias dnfupdate="sudo dnf update --refresh"
alias fpclean="sudo rm -rfv /var/tmp/flatpak-cache-*"
# other alias
alias open="xdg-open"
alias ss="systemctl suspend"
alias vim="nvim"
alias vi="nvim"
alias v="nvim"
# cargo binary update
alias cupdate="cargo install eza bottom git-delta ripgrep tree-sitter-cli bacon cargo-audit cargo-cache cargo-llvm-cov fd-find just"
alias cclean="cargo cache trim --limit 0M"

export EDITOR=nvim

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


__vte_urlencode() (
  # This is important to make sure string manipulation is handled
  # byte-by-byte.
  LC_ALL=C
  str="$1"
  while [ -n "$str" ]; do
    safe="${str%%[!a-zA-Z0-9/:_\.\-\!\'\(\)~]*}"
    printf "%s" "$safe"
    str="${str#"$safe"}"
    if [ -n "$str" ]; then
      printf "%%%02X" "'$str"
      str="${str#?}"
    fi
  done
)

__vte_osc7 () {
  printf "\033]7;file://%s%s\007" "${HOSTNAME:-}" "$(__vte_urlencode "${PWD}")"
}

__vte_prompt_command() {
  local command=$(HISTTIMEFORMAT= history 1 | sed 's/^ *[0-9]\+ *//')
  command="${command//;/ }"
  local pwd='~'
  [ "$PWD" != "$HOME" ] && pwd=${PWD/#$HOME\//\~\/}
  printf "\033]0;%s@%s:%s\007%s" "${USER}" "${HOSTNAME%%.*}" "${pwd}" "$(__vte_osc7)"
}

[ -n "$BASH_VERSION" ] && PROMPT_COMMAND="__vte_prompt_command"
. "$HOME/.cargo/env"
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

if [ "x${BASH_VERSION-}" != x -a "x${PS1-}" != x -a "x${BASH_COMPLETION_VERSINFO-}" = x ]; then

    # Check for recent enough version of bash.
    if [ "${BASH_VERSINFO[0]}" -gt 4 ] ||
        [ "${BASH_VERSINFO[0]}" -eq 4 -a "${BASH_VERSINFO[1]}" -ge 2 ]; then
        [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bash_completion" ] &&
            . "${XDG_CONFIG_HOME:-$HOME/.config}/bash_completion"
        if shopt -q progcomp && [ -r /usr/share/bash-completion/bash_completion ]; then
            # Source completion code.
            . /usr/share/bash-completion/bash_completion
        fi
    fi

fi

_just() {
    local i cur prev words cword opts cmd
    COMPREPLY=()

    # Modules use "::" as the separator, which is considered a wordbreak character in bash.
    # The _get_comp_words_by_ref function is a hack to allow for exceptions to this rule without
    # modifying the global COMP_WORDBREAKS environment variable.
    if type _get_comp_words_by_ref &>/dev/null; then
        _get_comp_words_by_ref -n : cur prev words cword
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=$COMP_WORDS
        cword=$COMP_CWORD
    fi

    cmd=""
    opts=""

    for i in ${words[@]}
    do
        case "${cmd},${i}" in
            ",$1")
                cmd="just"
                ;;
            *)
                ;;
        esac
    done

    case "${cmd}" in
        just)
            opts="-E -n -g -f -q -u -v -d -c -e -l -s -h -V --check --chooser --clear-shell-args --color --command-color --dotenv-filename --dotenv-path --dry-run --dump-format --explain --global-justfile --highlight --justfile --list-heading --list-prefix --list-submodules --no-aliases --no-deps --no-dotenv --no-highlight --one --quiet --allow-missing --set --shell --shell-arg --shell-command --timestamp --timestamp-format --unsorted --unstable --verbose --working-directory --yes --changelog --choose --command --completions --dump --edit --evaluate --fmt --groups --init --list --man --request --show --summary --variables --help --version [ARGUMENTS]..."
                if [[ ${cur} == -* ]] ; then
                    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
                    return 0
                elif [[ ${cword} -eq 1 ]]; then
                    local recipes=$(just --summary 2> /dev/null)

                    if echo "${cur}" | \grep -qF '/'; then
                        local path_prefix=$(echo "${cur}" | sed 's/[/][^/]*$/\//')
                        local recipes=$(just --summary 2> /dev/null -- "${path_prefix}")
                        local recipes=$(printf "${path_prefix}%s\t" $recipes)
                    fi

                    if [[ $? -eq 0 ]]; then
                        COMPREPLY=( $(compgen -W "${recipes}" -- "${cur}") )
                        if type __ltrim_colon_completions &>/dev/null; then
                            __ltrim_colon_completions "$cur"
                        fi
                        return 0
                    fi
                fi
            case "${prev}" in
                --chooser)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --color)
                    COMPREPLY=($(compgen -W "auto always never" -- "${cur}"))
                    return 0
                    ;;
                --command-color)
                    COMPREPLY=($(compgen -W "black blue cyan green purple red yellow" -- "${cur}"))
                    return 0
                    ;;
                --dotenv-filename)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --dotenv-path)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                -E)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --dump-format)
                    COMPREPLY=($(compgen -W "json just" -- "${cur}"))
                    return 0
                    ;;
                --justfile)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                -f)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --list-heading)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --list-prefix)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --set)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --shell)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --shell-arg)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --timestamp-format)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --working-directory)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                -d)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --command)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                -c)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --completions)
                    COMPREPLY=($(compgen -W "bash elvish fish nushell powershell zsh" -- "${cur}"))
                    return 0
                    ;;
                --list)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                -l)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --request)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                --show)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                -s)
                    COMPREPLY=($(compgen -f "${cur}"))
                    return 0
                    ;;
                *)
                    COMPREPLY=()
                    ;;
            esac
            COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
            return 0
            ;;
    esac
}

if [[ "${BASH_VERSINFO[0]}" -eq 4 && "${BASH_VERSINFO[1]}" -ge 4 || "${BASH_VERSINFO[0]}" -gt 4 ]]; then
    complete -F _just -o nosort -o bashdefault -o default just
else
    complete -F _just -o bashdefault -o default just
fi

__kubectl_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE-} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Macs have bash3 for which the bash-completion package doesn't include
# _init_completion. This is a minimal version of that function.
__kubectl_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

# This function calls the kubectl program to obtain the completion
# results and the directive.  It fills the 'out' and 'directive' vars.
__kubectl_get_completion_results() {
    local requestComp lastParam lastChar args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly kubectl allows handling aliases
    args=("${words[@]:1}")
    requestComp="${words[0]} __complete ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __kubectl_debug "lastParam ${lastParam}, lastChar ${lastChar}"

    if [[ -z ${cur} && ${lastChar} != = ]]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __kubectl_debug "Adding extra empty parameter"
        requestComp="${requestComp} ''"
    fi

    # When completing a flag with an = (e.g., kubectl -n=<TAB>)
    # bash focuses on the part after the =, so we need to remove
    # the flag part from $cur
    if [[ ${cur} == -*=* ]]; then
        cur="${cur#*=}"
    fi

    __kubectl_debug "Calling ${requestComp}"
    # Use eval to handle any environment variables and such
    out=$(eval "${requestComp}" 2>/dev/null)

    # Extract the directive integer at the very end of the output following a colon (:)
    directive=${out##*:}
    # Remove the directive
    out=${out%:*}
    if [[ ${directive} == "${out}" ]]; then
        # There is not directive specified
        directive=0
    fi
    __kubectl_debug "The completion directive is: ${directive}"
    __kubectl_debug "The completions are: ${out}"
}

__kubectl_process_completion_results() {
    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16
    local shellCompDirectiveKeepOrder=32

    if (((directive & shellCompDirectiveError) != 0)); then
        # Error code.  No completion.
        __kubectl_debug "Received error from custom completion go code"
        return
    else
        if (((directive & shellCompDirectiveNoSpace) != 0)); then
            if [[ $(type -t compopt) == builtin ]]; then
                __kubectl_debug "Activating no space"
                compopt -o nospace
            else
                __kubectl_debug "No space directive not supported in this version of bash"
            fi
        fi
        if (((directive & shellCompDirectiveKeepOrder) != 0)); then
            if [[ $(type -t compopt) == builtin ]]; then
                # no sort isn't supported for bash less than < 4.4
                if [[ ${BASH_VERSINFO[0]} -lt 4 || ( ${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -lt 4 ) ]]; then
                    __kubectl_debug "No sort directive not supported in this version of bash"
                else
                    __kubectl_debug "Activating keep order"
                    compopt -o nosort
                fi
            else
                __kubectl_debug "No sort directive not supported in this version of bash"
            fi
        fi
        if (((directive & shellCompDirectiveNoFileComp) != 0)); then
            if [[ $(type -t compopt) == builtin ]]; then
                __kubectl_debug "Activating no file completion"
                compopt +o default
            else
                __kubectl_debug "No file completion directive not supported in this version of bash"
            fi
        fi
    fi

    # Separate activeHelp from normal completions
    local completions=()
    local activeHelp=()
    __kubectl_extract_activeHelp

    if (((directive & shellCompDirectiveFilterFileExt) != 0)); then
        # File extension filtering
        local fullFilter filter filteringCmd

        # Do not use quotes around the $completions variable or else newline
        # characters will be kept.
        for filter in ${completions[*]}; do
            fullFilter+="$filter|"
        done

        filteringCmd="_filedir $fullFilter"
        __kubectl_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif (((directive & shellCompDirectiveFilterDirs) != 0)); then
        # File completion for directories only

        local subdir
        subdir=${completions[0]}
        if [[ -n $subdir ]]; then
            __kubectl_debug "Listing directories in $subdir"
            pushd "$subdir" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
        else
            __kubectl_debug "Listing directories in ."
            _filedir -d
        fi
    else
        __kubectl_handle_completion_types
    fi

    __kubectl_handle_special_char "$cur" :
    __kubectl_handle_special_char "$cur" =

    # Print the activeHelp statements before we finish
    if ((${#activeHelp[*]} != 0)); then
        printf "\n";
        printf "%s\n" "${activeHelp[@]}"
        printf "\n"

        # The prompt format is only available from bash 4.4.
        # We test if it is available before using it.
        if (x=${PS1@P}) 2> /dev/null; then
            printf "%s" "${PS1@P}${COMP_LINE[@]}"
        else
            # Can't print the prompt.  Just print the
            # text the user had typed, it is workable enough.
            printf "%s" "${COMP_LINE[@]}"
        fi
    fi
}

# Separate activeHelp lines from real completions.
# Fills the $activeHelp and $completions arrays.
__kubectl_extract_activeHelp() {
    local activeHelpMarker="_activeHelp_ "
    local endIndex=${#activeHelpMarker}

    while IFS='' read -r comp; do
        if [[ ${comp:0:endIndex} == $activeHelpMarker ]]; then
            comp=${comp:endIndex}
            __kubectl_debug "ActiveHelp found: $comp"
            if [[ -n $comp ]]; then
                activeHelp+=("$comp")
            fi
        else
            # Not an activeHelp line but a normal completion
            completions+=("$comp")
        fi
    done <<<"${out}"
}

__kubectl_handle_completion_types() {
    __kubectl_debug "__kubectl_handle_completion_types: COMP_TYPE is $COMP_TYPE"

    case $COMP_TYPE in
    37|42)
        # Type: menu-complete/menu-complete-backward and insert-completions
        # If the user requested inserting one completion at a time, or all
        # completions at once on the command-line we must remove the descriptions.
        # https://github.com/spf13/cobra/issues/1508
        local tab=$'\t' comp
        while IFS='' read -r comp; do
            [[ -z $comp ]] && continue
            # Strip any description
            comp=${comp%%$tab*}
            # Only consider the completions that match
            if [[ $comp == "$cur"* ]]; then
                COMPREPLY+=("$comp")
            fi
        done < <(printf "%s\n" "${completions[@]}")
        ;;

    *)
        # Type: complete (normal completion)
        __kubectl_handle_standard_completion_case
        ;;
    esac
}

__kubectl_handle_standard_completion_case() {
    local tab=$'\t' comp

    # Short circuit to optimize if we don't have descriptions
    if [[ "${completions[*]}" != *$tab* ]]; then
        IFS=$'\n' read -ra COMPREPLY -d '' < <(compgen -W "${completions[*]}" -- "$cur")
        return 0
    fi

    local longest=0
    local compline
    # Look for the longest completion so that we can format things nicely
    while IFS='' read -r compline; do
        [[ -z $compline ]] && continue
        # Strip any description before checking the length
        comp=${compline%%$tab*}
        # Only consider the completions that match
        [[ $comp == "$cur"* ]] || continue
        COMPREPLY+=("$compline")
        if ((${#comp}>longest)); then
            longest=${#comp}
        fi
    done < <(printf "%s\n" "${completions[@]}")

    # If there is a single completion left, remove the description text
    if ((${#COMPREPLY[*]} == 1)); then
        __kubectl_debug "COMPREPLY[0]: ${COMPREPLY[0]}"
        comp="${COMPREPLY[0]%%$tab*}"
        __kubectl_debug "Removed description from single completion, which is now: ${comp}"
        COMPREPLY[0]=$comp
    else # Format the descriptions
        __kubectl_format_comp_descriptions $longest
    fi
}

__kubectl_handle_special_char()
{
    local comp="$1"
    local char=$2
    if [[ "$comp" == *${char}* && "$COMP_WORDBREAKS" == *${char}* ]]; then
        local word=${comp%"${comp##*${char}}"}
        local idx=${#COMPREPLY[*]}
        while ((--idx >= 0)); do
            COMPREPLY[idx]=${COMPREPLY[idx]#"$word"}
        done
    fi
}

__kubectl_format_comp_descriptions()
{
    local tab=$'\t'
    local comp desc maxdesclength
    local longest=$1

    local i ci
    for ci in ${!COMPREPLY[*]}; do
        comp=${COMPREPLY[ci]}
        # Properly format the description string which follows a tab character if there is one
        if [[ "$comp" == *$tab* ]]; then
            __kubectl_debug "Original comp: $comp"
            desc=${comp#*$tab}
            comp=${comp%%$tab*}

            # $COLUMNS stores the current shell width.
            # Remove an extra 4 because we add 2 spaces and 2 parentheses.
            maxdesclength=$(( COLUMNS - longest - 4 ))

            # Make sure we can fit a description of at least 8 characters
            # if we are to align the descriptions.
            if ((maxdesclength > 8)); then
                # Add the proper number of spaces to align the descriptions
                for ((i = ${#comp} ; i < longest ; i++)); do
                    comp+=" "
                done
            else
                # Don't pad the descriptions so we can fit more text after the completion
                maxdesclength=$(( COLUMNS - ${#comp} - 4 ))
            fi

            # If there is enough space for any description text,
            # truncate the descriptions that are too long for the shell width
            if ((maxdesclength > 0)); then
                if ((${#desc} > maxdesclength)); then
                    desc=${desc:0:$(( maxdesclength - 1 ))}
                    desc+="…"
                fi
                comp+="  ($desc)"
            fi
            COMPREPLY[ci]=$comp
            __kubectl_debug "Final comp: $comp"
        fi
    done
}

__start_kubectl()
{
    local cur prev words cword split

    COMPREPLY=()

    # Call _init_completion from the bash-completion package
    # to prepare the arguments properly
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -n =: || return
    else
        __kubectl_init_completion -n =: || return
    fi

    __kubectl_debug
    __kubectl_debug "========= starting completion logic =========="
    __kubectl_debug "cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}, cword is $cword"

    # The user could have moved the cursor backwards on the command-line.
    # We need to trigger completion from the $cword location, so we need
    # to truncate the command-line ($words) up to the $cword location.
    words=("${words[@]:0:$cword+1}")
    __kubectl_debug "Truncated words[*]: ${words[*]},"

    local out directive
    __kubectl_get_completion_results
    __kubectl_process_completion_results
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_kubectl kubectl
else
    complete -o default -o nospace -F __start_kubectl kubectl
fi
