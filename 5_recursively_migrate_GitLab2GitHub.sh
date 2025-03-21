#!/bin/bash

#==========================================================================================================
#	Script name: 	recursively_migrate_GitLab2GitHub.sh
#	Description: 	This script creates GitHub repository from the mirror of GitLab repository.
#
#
#	Developed by:	Renjith (sa.renjith@gmail.com)
#	
#	Usage:			./recursively_migrate_GitLab2GitHub.sh
#	Prerequisites:	
#					Git command line tool installed
#					Access to GitHub and GitLab
#					List of local GitLab repositries that needs to be mirrored.
#
#	Script input:	
#				tokens.conf in your current directory that will have GitHub token information.
#				recursive_migrate_GitLab_URLs.txt that will contain the URLs from GitLab that will be migrated to GitHub.
#	Script output: GitLab cloned remote GitHub repository with the history.
#	
#==========================================================================================================

source "./tokens.conf" ##now all the rows are stored in source.
GITHUB_TOKEN_VAR="GITLAB_TOKEN_SARENJITH_GMAIL" 
GITHUB_TOKEN="${!GITHUB_TOKEN_VAR}"

if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "Error: Github token is not set in tokens.conf.  Exiting"
	exit 1
fi

#echo "GitLab token: $GITLAB_TOKEN"
#echo "GitHub token: $GITHUB_TOKEN"
##---------------------------------------------------------------------------------------------------------

GITHUB_ORG="YOUR-GITHUB-ORGANIZATION-NAME"
GITHUB_API="https://api.github.com/orgs/${GITHUB_ORG}/repos"

##---------------------------------------------------------------------------------------------------------

INPUT_FILE="recursively_migrate_GitLab_URLs.txt"

while IFS= read -r GITLAB_REPO || [[ -n "$GITLAB_REPO" ]]; do
	#echo "Line read $GITLAB_REPO"
	SOURCE_PROJECT_NAME=$(basename "$GITLAB_REPO")
	#echo "Project name: $SOURCE_PROJECT_NAME"
	#echo "GitLab repo name: $GITLAB_REPO"
	
	###GitHub project category
	###DEST_PROJECT_NAME_CATEGORY="<solution name>-<application name>-"  
	###example:DEST_PROJECT_NAME_CATEGORY="Toyota-Electric-"
	DEST_PROJECT_NAME_CATEGORY="poc-"

	#for uniformity replace - and space in repository name with _
	TMP_DEST_PROJECT_NAME=$(echo "$SVN_FOLDER_NAME" | sed 's/[- ]/_/g')

	#build GitHub repository name
	DEST_PROJECT_NAME="${DEST_PROJECT_NAME_CATEGORY}${TMP_DEST_PROJECT_NAME}"

	GITHUB_URL="https://github.com/${GITHUB_ORG}/${DEST_PROJECT_NAME}.git"
	GITHUB_URL_WITH_TOKEN="https://$GITHUB_TOKEN@github.com/${GITHUB_ORG}/${DEST_PROJECT_NAME}.git"
	#echo "URL with token: $GITHUB_URL_WITH_TOKEN"
	#echo "GitHub URL: $GITHUB_URL"
	#echo "GitHub API: $GITHUB_API"
	#echo "GitHub with token $GITHUB_URL_WITH_TOKEN"

	echo "Cloning Gitlab repo (mirror/ bare repo)"
	git clone --mirror "$GITLAB_REPO"
	cd "${SOURCE_PROJECT_NAME}.git" || { echo "Failed to enter mirror repo directory"; exit 1; }
	cd ..
	#echo "Current working directory: $(pwd)"

	echo "Creating normal repo from bare repo"
	git clone "${SOURCE_PROJECT_NAME}.git" "${SOURCE_PROJECT_NAME}_normal"
	cd "${SOURCE_PROJECT_NAME}_normal" || { echo "Failed to enter non-mirror repo directory"; exit 1; }
	git fetch --all --prune #fetch all brnaches.

	echo "Converting cloned repo's remote branches to local...."
	git branch -D -r origin/master ##delete origin/remote/master (it's duplicate)
	git branch -D -r origin/main ##delete origin/remote/main (it's duplicate)
	for br in $(git branch -r | sed 's/origin\///'); do
		echo "Creating local banch $br and deleting origin/$br"
    	git branch $br origin/$br
		git branch -D -r origin/$br
	done

	echo "Renaming 'master' branch to 'main' branch."
	git branch -m master main
	
	echo "Create GitHub remote project"
	CREATE_REPO_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" -d "{\"name\": \"$DEST_PROJECT_NAME\", \"visibility\": \"internal\"}" "$GITHUB_API")

	# Check if the repository was created successfully
	if echo "$CREATE_REPO_RESPONSE" | grep -q '"id":'; then
    	echo "GitHub repository created successfully."
	else
     	echo "Failed to create GitHub repository. Response: $CREATE_REPO_RESPONSE"
   	 	exit 1
	fi

	echo "Remove gitlab remote reference"
	git remote remove origin

	echo "Creating yaml file in main branch"
	git checkout main

cat <<EOL > vitals.yaml
version: 2
accounts:
    -id: Appid_13592
componentType: code
EOL

	echo "Committing the yaml file"
	git add vitals.yaml
	git commit -m "Created vitals.yaml file"

	# Add GitHub as a remote repository
	echo "Link GitHub remote repository to origin"
	git remote add origin "$GITHUB_URL_WITH_TOKEN"

	echo "Checkout all branches and setup tracking...."
	for branch in $(git branch -r | grep -v 'HEAD' | sed 's/origin\///'); do
   		git checkout -B "$branch" "origin/$branch"
    		git branch --set-upstream-to="origin/$branch" "$branch"
		echo "Constructed branch $branch ..."
	done

	echo "Push all branches and tags to GitHub"
	##git push origin main --force
	git push --all origin
	git push --tags origin

	# Cleanup
	cd ..
	echo "Deleting mirror gitlab project"
	rm -rf "${SOURCE_PROJECT_NAME}.git"
	
	echo "Deleting mirror-feteched gitlab project"
	rm -rf "${SOURCE_PROJECT_NAME}_normal"
	echo "------ Successfully migrated $SOURCE_PROJECT_NAME ------"
done < "$INPUT_FILE"
echo "================= Migration process completed! ================="


