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
#	Script input:	tokens.conf: Token will be read from this file.
#			local_repo_list.txt: Repository name will be read from this file.
#	Script output:	A remote Git repository with the data that is in local repository.
#	
#==========================================================================================================


##NOTE:-----------------------------------------------------------------------------------------------------
##Ensure you have tokens.conf in your current directory and having soemthing like GITLAB_TOKEN=<your Gitlab_token>
#####Example:
######### GITLAB_TOKEN_0x218="glpat-JDFL-eDdjgdPrdaMerx4Xhfz2T8w"
######### GITHUB_TOKEN_0x218="github_pat_13245jadsfYlager_Vasefadfglkagadg-a34k3gJ4QDrDagadgl23AS"

source "./tokens.conf" ##now all the rows are stored in source.

GITHUB_TOKEN_VAR="GITHUB_TOKEN_0x218"   ##GITLAB_TOKEN_VAR stores string "GITHUB_TOKEN_0x218"

GITHUB_TOKEN="${!GITHUB_TOKEN_VAR}" #indirect refence; get teh value of GITLAB_TOKEN_SARENJITH_GMAIL from tokens.conf

if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "Error: Token is not set in tokens.conf.  Exiting"
	exit 1
fi

#echo "GitLab token: $GITLAB_TOKEN"
#echo "GitHub token: $GITHUB_TOKEN"
##---------------------------------------------------------------------------------------------------------



GITHUB_USER="sa.renjith@gmail.com"

# REPLACE GITHHUB_ORG with your organization name.  Put "" if creating under your personal account
GITHUB_ORG="MyTest1Org"

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
