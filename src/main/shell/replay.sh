#!/usr/bin/env bash

git=${gitbin:-/usr/bin/git}
egrep=${egrepbin:-/bin/egrep}

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

# Pulls changes from the remote git repository and after that perform
# `svn dcommit'.
function replay_push
{
  local rem_root=${1}
  local loc_root=${2}
  local rem_ref=${3}
  local loc_ref=${4}

  (export GIT_DIR="${loc_root}/.git";
     cd "${loc_root}" && \
     "${git}" checkout ${loc_ref} && \
     "${git}" pull "file://${rem_root}" ${rem_ref} && \
     "${git}" svn dcommit)
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

  ${lock} "${mutex}" 2>/dev/null
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

  ${unlock} "${mutex}"
}
