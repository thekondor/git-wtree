# git-wtree

Several naive `(ba)sh`-shortcuts for `git worktree` subcommand.

## Overview

Creation of `git` worktrees and switching between them is quite verbose thing to do for my regular use-cases. `git-wtree` is intended to simplify this routine.
This one is a simple shell script supposed to be sourced inside of a shell. It was intentionally developed in a shell-agnostic way (no bashishm's are used) but tested with `bash` only and `git` 2.18.0.

## Installation

Inside of `~/.bashrc`:

    # The comment for the line below could be removed to establish short aliases for provided commands
    # GIT_WTREE_ALIAS_ENABLED=true

    . git-wtree/git-wtree.sh

## Usage

Inside of `git` repository where worktrees are supposed to be intensively used:

    git config --local worktree.root <ROOT_DIR>

where `<ROOT_DIR>` is a directory where all worktrees are created and removed from.

### Create worktree

    git_wtree_cmd_new --name <BRANCH_NAME> --dir <DIR>
    
    # alias:
    git.wtree:ls --name <BRANCH_NAME> --dir <DIR>

where:

- `<BRANCH_NAME>` is name of the branch to be created;
- `<DIR>` is name of directory inside of `<ROOT_DIR>`

vs native `git worktree add -b <BRANCH_NAME> <ROOT_DIR>/<DIR>`.

### Delete worktree

    ```bash
    git_wtree_cmd_drop --name <BRANCH_NAME>
    # alias:
    git.wtree:drop --name <BRANCH_NAME>
    ```

where `<BRANCH_NAME>` is a name of the branch to be deleted.

vs native `git worktreee remove <FULL_PATH_TO_DIR_OF_BRANCH_NAME>`

### List branches inside worktrees

    git_wtree_cmd_ls
    # alias:
    git.wtree:ls

vs native `git worktree list` and futher grepping for a branch name.

### Switch to a worktree dir

    git_wtree_cmd_tool_cd <BRANCH_NAME>
    # alias:
    git.wtree:cd <BRANCH_NAME>

    git_wtree_cmd_tool_pushd <BRANCH_NAME>
    # alias:
    git.wtree:pushd <BRANCH_NAME>

vs native `git worktree list`, grepping and furhter cd/pushd execution.

# License

MIT

