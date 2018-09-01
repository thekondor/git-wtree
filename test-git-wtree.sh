#!/bin/sh

. $(dirname $0)/git-wtree.sh

#set -e

SELF_PID=$$
SELF_ROOT=$(readlink -e $(dirname $0))
FIXED_FAKE_ROOT=/tmp/git-wtree-test.root
FAKE_ROOT=$([ -z "${GIT_WTREE_TEST_FIXED_ROOT}" ] && mktemp -d || (mkdir ${FIXED_FAKE_ROOT} && ${FIXED_FAKE_ROOT}))
trap cleanup  KILL QUIT EXIT

fail() {
    echo -n "*** FAILED: "
    [ $# -gt 0 ] && echo "$*" || echo "unknown reason"
    kill -9 ${SELF_PID}
}

cleanup() {
    cd "${SELF_ROOT}"
    [ -d "${FAKE_ROOT}" ] && (echo "- Clean the fake root ${FAKE_ROOT} up"; rm -rf "${FAKE_ROOT}")
}

echo "- Fake root: ${FAKE_ROOT}"
[ -n "${FAKE_ROOT}" -a -d "${FAKE_ROOT}" ] || fail "fake root ${FAKE_ROOT} location is set"

echo "- Prepare fake git repository"
mkdir ${FAKE_ROOT}/main.git || fail "fake root ${FAKE_ROOT} is created"

cd ${FAKE_ROOT}/main.git
git init . || fail "fake git repository is initialized"

touch dummy.file || fail "dummy file in the git repository is created"
git add dummy.file || fail "dummy file is added to the git repository"
git commit -m "initial auto commit" || fail "initial commit is made to the git repository"

echo "= TEST: Master is a single available worktree"
worktrees=$(git_wtree_cmd_ls | wc -l)
[ 1 -eq ${worktrees} ] || fail "master is an only one workspace"

echo "= TEST(new)"
echo "== requires --name argument"
git_wtree_cmd_new 2>&1 | grep -qi 'ERROR.*missing branch name'
[ 0 -eq $? ] || "error message about missing '--name' argument"

echo "== requires --dir argument"
git_wtree_cmd_new --name branch-name 2>&1 | grep -qi 'ERROR.*missing directory name'
[ 0 -eq $? ] || fail "error message about missing '--dir' argument"

echo "== requires 'worktree.root' in config"
git_wtree_cmd_new --name worktree --dir worktree.d 2>&1 | grep -qi "ERROR.*worktree.root.*should point"
[ 0 -eq $? ] || fail "error message about missing 'worktree.root' variable"

echo "- Set worktree.root"
git config --local worktree.root ${FAKE_ROOT} || fail "'worktree.root' is set to a config"
git config --local worktree.root | grep -qi "${FAKE_ROOT}"
[ 0 -eq $? ] || fail "'worktree.root' is available through config"

echo "== creates worktree"
git_wtree_cmd_new --name test-branch-name --dir test-branch.d || fail "new worktree is created"
git worktree list | grep -q 'test-branch.d.*test-branch-name'
[ 0 -eq $? ] || fail "newly created worktree is listed"

echo "== fails on a duplicated name"
git_wtree_cmd_new --name test-branch-name --dir alternative-branch.d 2>&1 | grep -q FAILED
[ 0 -eq $? ] || fail "error message about failed creation of already existing branch"

echo "= TEST(ls)"
echo "== Lists worktrees"
worktrees=$(git_wtree_cmd_ls | grep -E '^master|^test-branch-name' | wc -l)
[ 2 -eq ${worktrees} ] || fail "Master and the newly created worktree are listed: ${worktrees}"

echo "= TEST(cd)"
echo "== PWD is changed to worktree"
pwd | grep -qi ${FAKE_ROOT}/main.git
[ 0 -eq $? ] || fail "initial directory is main fake root"
git_wtree_cmd_tool_cd test-branch-name 2>&1
[ x"${FAKE_ROOT}/test-branch.d" = x"$(pwd)" ] || fail "current directory is test-branche's one"

echo "== PWD is changed to master"
pwd | grep -qi ${FAKE_ROOT}/test-branch.d
[ 0 -eq $? ] || fail "initial directory is worktree's one"
git_wtree_cmd_tool_cd master 2>&1
[ x"${FAKE_ROOT}/main.git" = x"$(pwd)" ] || fail "current directory is master's one"

echo "= TEST(drop)"
cd ${FAKE_ROOT}/main.git

echo "== requires --name argument"
git_wtree_cmd_drop 2>&1 | grep -qi "ERROR.*missing branch name"
[ 0 -eq $? ] || fail "error message about no candidates to drop"

echo "== drops worktree directory"
git_wtree_cmd_drop --name test-branch-name || fail "drop command is succeeded"
worktrees=$(git_wtree_cmd_ls | grep master | wc -l)
[ 1 -eq ${worktrees} ] || fail "only master branch is left"

echo "== fails on already dropped worktree directory"
for branch_name in test-branch-name never-existed-branch-name; do
    git_wtree_cmd_drop --name ${branch_name} 2>&1 | grep -qi "ERROR.*0 candidates"
    [ 0 -eq $? ] || fail "error message about no candidates to drop"
done

