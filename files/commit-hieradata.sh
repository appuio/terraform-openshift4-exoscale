#!/bin/sh

readonly cluster_id=$1

cd appuio_hieradata || exit 1

git config user.name "${GIT_AUTHOR_NAME}"
git config user.email "${GIT_AUTHOR_EMAIL}"

amend=0
# Checkout feature branch
# 1. try to check out as tracking branch from upstream
# 2. checkout as new branch
# 3. checkout existing local branch
# For existing local branch, amend existing commit
if ! git checkout -t origin/tf/lbaas/${cluster_id}; then
  if ! git checkout -b tf/lbaas/${cluster_id}; then
    git checkout tf/lbaas/${cluster_id}
    amend=1
  fi
fi

git add lbaas/${cluster_id}.yaml

status=$(git status --porcelain)
echo "'${status}'"

commit_message="Update LBaaS hieradata for ${cluster_id}"
push=1
if [ "${status}"  == "M  lbaas/${cluster_id}.yaml" ]; then
  if [ "$amend" -eq 1 ]; then
    git commit --amend --no-edit
  else
    git commit -m"${commit_message}"
  fi
elif [ "${status}" != "" ]; then
  # assume new hieradata
  commit_message="Create LBaaS hieradata for ${cluster_id}"
  git commit -m "${commit_message}"
else
  push=0
fi

if [ "${push}" -eq 1 ]; then
  push_args=
  if [ "${amend}" -eq 1 ]; then
    push_args="--force"
  fi
  # Push and set local branch to track upstream branch at origin
  git push -u ${push_args} origin "${branch}"
fi

# Create MR if none exists yet
open_mrs=$(curl -sH "Authorization: Bearer ${HIERADATA_REPO_TOKEN}" \
  "https://git.vshn.net/api/v4/projects/368/merge_requests?state=opened&source_branch=tf/lbaas/${cluster_id}")
if [ "${push}" -eq 0 ]; then
  mr_url="No changes, skipping push and MR creation"
elif [ "${open_mrs}" == "[]" ]; then
  # create MR
  mr_url=$(curl -XPOST -sH "Authorization: Bearer ${HIERADATA_REPO_TOKEN}" \
    -H"Content-type: application/json" \
    "https://git.vshn.net/api/v4/projects/368/merge_requests" \
    -d \
    "{
      \"id\": 368,
      \"source_branch\": \"tf/lbaas/${cluster_id}\",
      \"target_branch\": \"master\",
      \"title\": \"${commit_message}\",
      \"remove_source_branch\": true
    }" | jq -r '.web_url')
else
  mr_url=$(echo "${open_mrs}" | jq -r '.[0].web_url')
fi

echo "${mr_url}" > /tf/.mr_url.txt
