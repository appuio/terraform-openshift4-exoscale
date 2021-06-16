#!/bin/sh

readonly cluster_id=$1

cd appuio_hieradata || exit 1

git config user.name "${GIT_AUTHOR_NAME}"
git config user.email "${GIT_AUTHOR_EMAIL}"

if ! git checkout -b tf/lbaas/${cluster_id}; then 
  git checkout tf/lbaas/${cluster_id}
fi

git add lbaas/${cluster_id}.yaml

status=$(git status --porcelain)
echo "'${status}'"

if [ "${status}"  == "M  lbaas/${cluster_id}.yaml" ]; then
  git commit --amend --no-edit
else
  git commit -m "Create LBaaS hieradata for ${cluster_id}"
fi
