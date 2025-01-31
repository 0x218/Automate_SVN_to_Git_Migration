#!/bin/bash
##WIP
#==========================================================================================================
#	Script name: 	push_to_remote_github.sh
#	Description: 	This script creates a git repository in the remote server, and push the local repository
#					into the remote server.
#
#
#	Developed by:	Renjith (sa.renjith@gmail.com)
#	
#	Usage:			./push_to_remote_git.sh
#	Prerequisites:	
#					Git command line tool installed
#					Access to Git repository
#					List of local Git repositries that needs to be pushed to remote.
#
#	Script input:	None|repository name will be read from REPO_LIST_FILE variable.
#	Script output:	A remote Git repository with the data that is in local repository.
#	
#==========================================================================================================

GITHUB_USER="sa.renjith@gmail.com"
GITHUB_ORG="REPLACE_WITH_YOUR_ORGANIZATION_NAME"   # put "" if creating under your personal account
GITHUB_TOKEN="github_pat_REPLACE_WITH_YOUR_PERSONAL_ACCESS_TOKEN"

# GitHub API URL
GITHUB_API_URL="https://api.github.com"

REPO_LIST_FILE="local_repo_list.txt"

if [[ ! -f "$REPO_LIST_FILE" ]]; then
	echo "Error: File `$REPO_LIST_FILE` not found!"
	exit 1
fi

# Determine if creating under an organization or personal account
if [[ -n "$GITHUB_ORG" ]]; then
    CREATE_REPO_URL="$GITHUB_API_URL/orgs/$GITHUB_ORG/repos"
else
    CREATE_REPO_URL="$GITHUB_API_URL/user/repos"
fi

echo "Repo URL is  $CREATE_REPO_URL"

while IFS= read -r local_repo_folder; do
	echo "Name of folder before truncating: $local_repo_folder"
	
	#Clear the carriage return.
	local_repo_folder=$(echo "$local_repo_folder" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r' )
	
	echo "Name of folder after truncate: $local_repo_folder"
	#read -n 1 -s -r #wait for a keypress
	
	PROJECT_NAME="$local_repo_folder"
	LOCAL_REPO_PATH="$local_repo_folder"
	DESCRIPTION="Replacement project created svn repo: $local_repo_folder"

	# Create a repository in GitHub
	echo "Creating remote repository $PROJECT_NAME"
	PROJECT_RESPONSE=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
    		-H "Accept: application/vnd.github.v3+json" \
    		-d "{\"name\": \"$PROJECT_NAME\", \"private\": true, \"auto_init\": true}" \
    		"$CREATE_REPO_URL")

	#echo "$PROJECT_RESPONSE"

	REMOTE_PROJECT_ID=$(echo $PROJECT_RESPONSE | jq '.id')
	SSH_PROJECT_URL=$(echo $PROJECT_RESPONSE | jq -r '.ssh_url')
	HTTPS_PROJECT_URL=$(echo "$PROJECT_RESPONSE" | jq -r '.clone_url')

	if [ -z "$REMOTE_PROJECT_ID" ]; then
		echo "Error: Failed to create project. Exiting."
		exit 1
	fi
	echo "Remote project created.  ID: $REMOTE_PROJECT_ID"
	echo "Repository URL: $SSH_PROJECT_URL"
	echo "HTTPS URL: $HTTPS_PROJECT_URL"

	#echo "press enter key to continue..."
	#read -n 1 -s -r #wait for a keypress

	cd "$LOCAL_REPO_PATH" || { echo "Error: Local repository path not found.  Exiting"; exit 1; }
	echo "Current folder: $(pwd)"

	#git init 
	#git add .
	#git commit -m "initial commit"
	
	echo "Pushing local to remote"
	#git remote add origin "$SSH_PROJECT_URL"
	git remote add origin "$HTTPS_PROJECT_URL"

	#########################################
	##NOTE: Rename 'master' to new local 'main'.
	#git checkout master
	#echo "Renaming local master branch to local main branch"
	#git branch -m master main ## rename master to main.
	
	git push origin main --force  ##force push main branch
	#########################################

	git push --set-upstream --all origin
	git push --tags

	echo "Upload complete for $local_repo_folder.  Press enter key to continue with next repo..."
	cd ..
	#read -n 1 -s -r #wait for a keypress

done < "$REPO_LIST_FILE"

echo "All the local repositories are now pushed to remote!"
