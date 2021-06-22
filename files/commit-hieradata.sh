#!/bin/sh

readonly cluster_id=$1

cd appuio_hieradata || exit 1

git config user.name "${GIT_AUTHOR_NAME}"
git config user.email "${GIT_AUTHOR_EMAIL}"

amend=0
if ! git checkout -b tf/lbaas/${cluster_id}; then 
  git checkout tf/lbaas/${cluster_id}
  amend=1
fi

git add lbaas/${cluster_id}.yaml

status=$(git status --porcelain)
echo "'${status}'"

if [ "${status}"  == "M  lbaas/${cluster_id}.yaml" ]; then
  if [ "$amend" -eq 1 ]; then
    git commit --amend --no-edit
  else
    git commit -m"Update LBaaS hieradata for ${cluster_id}"
  fi
elif [ "${status}" != "" ]; then
  # assume new hieradata
  git commit -m "Create LBaaS hieradata for ${cluster_id}"
fi
