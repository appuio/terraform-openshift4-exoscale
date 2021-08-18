#!/bin/sh

readonly cluster_id="$1"
readonly mr_url_file="$2"
readonly branch="tf/lbaas/${cluster_id}"

cd appuio_hieradata || exit 1

git config user.name "${GIT_AUTHOR_NAME}"
git config user.email "${GIT_AUTHOR_EMAIL}"

# Checkout feature branch
# 1. try to check out as tracking branch from origin
# 2. checkout as new branch
# 3. checkout existing local branch
# For existing local branch, amend existing commit
if ! git checkout -t origin/"${branch}"; then
  if ! git checkout -b "${branch}"; then
    git checkout "${branch}"
  fi
fi

git add "lbaas/${cluster_id}.yaml"

status=$(git status --porcelain)
echo "'${status}'"

commit_message="Update LBaaS hieradata for ${cluster_id}"
push=1
if [ "${status}"  = "M  lbaas/${cluster_id}.yaml" ]; then
  git commit -m"${commit_message}"
elif [ "${status}" != "" ]; then
  # assume new hieradata
  commit_message="Create LBaaS hieradata for ${cluster_id}"
  git commit -m "${commit_message}"
else
  push=0
fi

if [ "${push}" -eq 1 ]; then
  # Push branch to origin and set upstream
  git push origin "${branch}"
fi

# Always set branch's upstream to origin/master.
#
# If we would set the branch's upstream to the pushed branch, subsequent
# terraform runs break if the upstream branch has been merged or deleted.
#
# If we only set the upstream when pushing, subsequent terraform runs break if
# there's been no changes in the hieradata.
git branch -u origin/master

# Create MR if none exists yet
open_mrs=$(curl -sH "Authorization: Bearer ${HIERADATA_REPO_TOKEN}" \
  "https://git.vshn.net/api/v4/projects/368/merge_requests?state=opened&source_branch=tf/lbaas/${cluster_id}")
if [ "${push}" -eq 0 ]; then
  mr_url="No changes, skipping push and MR creation"
elif [ "${open_mrs}" = "[]" ]; then
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

echo "${mr_url}" > "${mr_url_file}"
