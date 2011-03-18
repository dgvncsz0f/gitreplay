#!/usr/bin/env bash

git=${gitbin:-/usr/bin/git}
hg=${hgbin:-/usr/bin/hg}

# Executes the command with any number of arguments and fail (aborts)
# if there was any error.
#
# Example: replay_strict /bin/ls -l /tmp
function replay_strict
{
  local prog=${1}
  local status=0
  shift 1

  "${prog}" ${@} || exit ${?}
}

# A callback that is able to commit to svn using git-svn.
function replay_gitsvn_callback
{
  "${git}" svn dcommit
}

# A callback that is able to commit to hg using default binaries. It
# assumes that the remote repository and such are configured in .hgrc
# files.
function replay_hg_callback
{
  "${hg}" addremove
  "${hg}" commit -m "gitreplay"
  "${hg}" push
}

# Pulls changes from the remote git repository and after that perform
# `svn dcommit'.
function replay_push
{
  local rem_root=${1}
  local loc_root=${2}
  local rem_ref=${3}
  local loc_ref=${4}
  local callback=${5}

  (export GIT_DIR="${loc_root}/.git";
     cd "${loc_root}" && \
        "${git}" checkout ${loc_ref} && \
        "${git}" pull -s recursive -X theirs "file://${rem_root}" ${rem_ref} && \
        "${callback}")
}

# For each change git push produces, invokes a callback with the ref
# that is being modified and that is it. That function is responsible
# for calling any replay_xxx functions to replicate changes back to
# svn. Refer to myreplay.sh for an example of how implementing this
# callback.
function replay_run
{
  local callback=${1}
  shift 1
  while read orev nrev ref
  do
    "${callback}" "${ref}" ${@}
  done
}

# Very simple locking mechanism that relies on mkdir. Obviously I
# don't expect it to be safe, it is more to avoid damage.
function replay_lock
{
  local lock=/bin/mkdir
  local mutex=${1:-${HOME}/gitreplay_mutex}
  local timeout=3600
  
  echo -n "[replay_lock] acquiring lock ... "
  ${lock} "${mutex}" 2>/dev/null
  if [ "${?}" = "0" ]
  then
    echo "ok!"
    return 0
  else
    echo "fail!"
    return 1
  fi
}

function replay_check
{
  local check=/usr/bin/test
  local mutex=${1:-${HOME}/gitreplay_mutex}

  ${check} -d "${mutex}"
}

function replay_unlock
{
  local unlock=/bin/rmdir
  local mutex=${1:-${HOME}/gitreplay_mutex}
  
  echo "[replay_unlock] releasing lock"
  ${unlock} "${mutex}"
}
