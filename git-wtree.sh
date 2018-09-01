#!/bin/sh

### git_wtree_new <name:branch name> [dir:<dir name>]
### git_wtree_drop <name:branch name>
### git_wtree_{cd, pushd} <name:branch name>
### git_wtree_root
### git_wtree_ls

# TODO: use 'git check-ref-format --branch' to check branch's name validness

### GIT_WTREE_ALIAS_ENABLED=true

### For debugging purposes:
### GIT_WTREE_DRY_RUN=true
### GIT_WTREE_DEBUG=true

_git_wtree_last_error_dir=$(mktemp --suffix=git.wtree. -d)
_git_wtree_last_error_msg=${_git_wtree_last_error_dir}/msg
_git_wtree_last_error_out=${_git_wtree_last_error_dir}/out
trap "test -d ${_git_wtree_last_error_dir} && rm -rf '${_git_wtree_last_error_dir}'" EXIT QUIT

### Execute `git' subcommand with passed arguments
### $1     : routine description
### $2     : git subcommand, e.g.: worktree
### ${n,}  : git subcomand's arguments
_git_wtree_exec() {
    _git_wtree_set_last_error "$1 FAILED"
    shift

    cmd="git $*"
    if [ -n "${GIT_WTREE_DRY_RUN}" ]; then
        echo "[git-wtree:DRY-RUN]: ${cmd}"
        return 0
    fi

    [ -n "${GIT_WTREE_DEBUG}" ] && echo -e "git:{\n"
    ${cmd}
    rc=$?
    [ -n "${GIT_WTREE_DEBUG}" ] && echo -e "\n}:git"

    return $rc
}

### Return key's value from arguments
### $1    : arg's name
### ${2,n}: argv to search in
### NOTE: for the sake of simplicity no long values are supported
_git_wtree_arg() {
    arg_name=$1
    shift

    while [ ! $# -eq 0 ]; do
        case "$1" in
            --${arg_name}) echo -n $2 && break ;;
            *) shift ;;
        esac
    done
}

_git_wtree_show_last_error() {
    echo "[git-wtree:ERROR] $(cat ${_git_wtree_last_error_msg})" >&2
    [ -s "${_git_wtree_last_error_out}" ] && echo "[git-wtree:ERROR] $(cat ${_git_wtree_last_error_out})" >&2
    true
}

_git_wtree_set_last_error() {
    echo "$*" > ${_git_wtree_last_error_msg}
}

_git_wtree_worktree_root() {
    worktree_root=$(git config worktree.root 2>${_git_wtree_last_error_out} || echo -n)
    [ -n "${worktree_root}" -a -d "${worktree_root}" ] && echo -n "${worktree_root}" && return 0
    _git_wtree_set_last_error "Non-defined or not accessible worktree root '${worktree_root}'. 'worktree.root' in .git/config should point to an existing dir."
    return 1
}

_git_wtree_arg_dir_name() {
    dir_name=$(_git_wtree_arg dir $*)
    _git_wtree_set_last_error "Missing directory name. Shall be specified with --dir argument"
    [ -n "${dir_name}" ] && echo -n "${dir_name}" && return 0
    return 1
}

_git_wtree_arg_branch_name() {
    branch_name=$(_git_wtree_arg branch $*)

    _git_wtree_set_last_error "Missing branch name. Shall be specified with either --branch or --name argument"
    [ -z "${branch_name}" ] && branch_name=$(_git_wtree_arg name $*)
    [ -n "${branch_name}" ] && echo -n "${branch_name}" && return 0
    return 1
}

_git_wtree_dir_by_branch_name() {
    branch_name="$1"
    candidates_amount=$(git worktree list 2>${_git_wtree_last_error_out} | grep "${branch_name}" | wc -l)

    ### TODO: won't work for names with a common prefix
    _git_wtree_set_last_error "No exact branch '${branch_name}' is available but ${candidates_amount} candidates"
    [ 1 -eq "${candidates_amount}" ] || return 1

    _git_wtree_set_last_error "No worktree dir is found for branch '${branch_name}'"
    dir_name=$(git worktree list 2>/dev/null | grep "${branch_name}" | cut -d ' ' -f 1)
    [ -n "${dir_name}" ] || return 1

    _git_wtree_set_last_error "No worktree dir '${dir_name}' is available for branch '${branch_name}'"
    [ -d "${dir_name}" ] || return 1

    echo -n "${dir_name}"
    return 0
}

###
### Locate a corresponding directory of specified branch.
### Arguments:
### --<name|branch> <branch_name>
###
git_wtree_cmd_locate() {
    current_top_level=$(git rev-parse --show-toplevel 2>${_git_wtree_last_error_out} || echo -n)
    _git_wtree_set_last_error "'$(pwd)' is not a git directory"
    [ -z "${current_top_level}" ] && _git_wtree_show_last_error && return 1

    branch_name=$(_git_wtree_arg_branch_name $*)
    [ -z "${branch_name}" ] && _git_wtree_show_last_error && return 1

    branch_dir_name=$(_git_wtree_dir_by_branch_name ${branch_name})
    [ -z "${branch_dir_name}" ] && _git_wtree_show_last_error && return 1

    echo -n "${branch_dir_name}"
    return 0
}

####
#### Same as `git_wtree_cmd_locate`. Suppresses an error output. A corresponding exit code is preserved.
####
git_wtree_cmd_locate_noerror() {
    branch_dir_name=$(git_wtree_cmd_locate $* 2>/dev/null)
    [ 0 -eq $? ] || return 1

    echo -n "${branch_dir_name}"
    return 0;
}

###
### Drop worktree's directory
### Arguments:
### --<name|branch> <branch_name>
###   Should be specified in a relative way
###
git_wtree_cmd_drop() {
    branch_name=$(_git_wtree_arg_branch_name $*)
    [ -z "${branch_name}" ] && _git_wtree_show_last_error && return 1

    branch_dir_name=$(_git_wtree_dir_by_branch_name ${branch_name})
    [ -z "${branch_dir_name}" ] && _git_wtree_show_last_error && return 1

    # echo "- '${branch_name}' to be dropped from '${branch_dir_name}'"

    cmd="git worktree remove ${branch_dir_name}"
    _git_wtree_exec                                 \
        "Drop directory of branch '${branch_name}'" \
        worktree remove ${branch_dir_name}
    [ 0 -ne $? ] && _git_wtree_show_last_error && return 1
    return 0
}

###
### Create a new worktree branch
### Arguments:
### --<name|branch> <branch_name>
### --dir <worktree_directory name>
###   Should be specified in a relative way
###
git_wtree_cmd_new() {
    branch_name=$(_git_wtree_arg_branch_name $*)
    [ -z "${branch_name}" ] && _git_wtree_show_last_error && return 1
    branch_dir_name=$(_git_wtree_arg_dir_name $*)
    [ -z "${branch_dir_name}" ] && _git_wtree_show_last_error && return 1
    parent_branch_dir_name=$(_git_wtree_worktree_root)
    [ -z "${parent_branch_dir_name}" ] && _git_wtree_show_last_error && return 1
    
    branch_dir_name="${parent_branch_dir_name}/${branch_dir_name}"
    _git_wtree_set_last_error "'${branch_dir_name}' already exists"
    [ -e "${branch_dir_name}" ] && _git_wtree_show_last_error && return 1

    # echo "- '${branch_name}' to be created in '${branch_dir_name}'"
   
    _git_wtree_exec                                              \
        "Create branch '${branch_name}' in '${branch_dir_name}'" \
         worktree add -b ${branch_name} ${branch_dir_name} $(_git_wtree_arg commit $*)
    [ 0 -ne $? ] && _git_wtree_show_last_error && return 1
    return 0
}

###
### List all available worktrees
### Arguments: none
###
git_wtree_cmd_ls() {
    _git_wtree_exec                \
        "List available worktrees" \
        worktree list | awk -F'[][]' '{print $2}'
    [ 0 -ne $? ] && _git_wtree_show_last_error && return
}

###
### Helper to change a current directory to a worktree's one using a specified change dir command. Nothing is executed in a case of any error.
### Arguments:
### $1 - change dir command. E.g.: cd, pushd etc.
### $2 - branch name
###
git_wtree_cmd_tool_chdir() {
    chdir_cmd=$1
    shift
    branch_dir_name=$(git_wtree_cmd_locate_noerror --name $1)
    [ 0 -eq $? ] && eval "${chdir_cmd} ${branch_dir_name}"
}

###
### Helper to change a current directory to a worktree's one using 'cd'
### Arguments:
### $1 - branch name
###
git_wtree_cmd_tool_cd() {
    git_wtree_cmd_tool_chdir cd $1
}

###
### Helper to change a current directory to a worktree's one using 'pushd'
### Arguments:
### $1 - branch name
###
git_wtree_cmd_tool_pushd() {
    git_wtree_cmd_tool_chdir pushd $1
}

git_wtree() {
    [ 0 -eq $# ] && _git_wtree_set_last_error "Command expected: new, drop, locate" && _git_wtree_show_last_error && return

    cmd=git_wtree_cmd_$1
    shift

    ${cmd} $*
    return $?
}

if [ -n "${GIT_WTREE_ALIAS_ENABLED}" ]; then
    alias git.wtree=git_wtree
    alias git.wtree:ls=git_wtree_cmd_ls
    alias git.wtree:new=git_wtree_cmd_new
    alias git.wtree:drop=git_wtree_cmd_drop
    alias git.wtree:cd=git_wtree_cmd_tool_cd
    alias git.wtree:pushd=git_wtree_cmd_tool_pushd
fi

