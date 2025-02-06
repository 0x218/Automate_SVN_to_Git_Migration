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

##NOTE:-----------------------------------------------------------------------------------------------------
##Ensure you have tokens.conf in your current directory and having soemthing like GITLAB_TOKEN=<your Gitlab_token>
#####Example:
#########GITLAB_TOKEN_0x218="glpat-JDFL-eDdjgdPrdaMerx4Xhfz2T8w"
######### GITHUB_TOKEN_0x218="github_pat_13245jadsfYlager_Vasefadfglkagadg-a34k3gJ4QDrDagadgl23AS"

source "./tokens.conf" ##now all the rows are stored in source.

#GITLAB_TOKEN_VAR="GITLAB_TOKEN_0x218"   ##GITLAB_TOKEN_VAR stores string "GITLAB_TOKEN_0x218"
GITHUB_TOKEN_VAR="GITHUB_TOKEN_0x218_MYORG1" 

#GITLAB_TOKEN="${!GITLAB_TOKEN_VAR}" #indirect refence; get teh value of GITLAB_TOKEN_0x218 from tokens.conf
GITHUB_TOKEN="${!GITHUB_TOKEN_VAR}"

if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "Error: Github token is not set in tokens.conf.  Exiting"
	exit 1
fi

#echo "GitLab token: $GITLAB_TOKEN"
#echo "GitHub token: $GITHUB_TOKEN"
##---------------------------------------------------------------------------------------------------------

GITHUB_ORG="MyTest1Org"
GITHUB_API="https://api.github.com/orgs/${GITHUB_ORG}/repos"

##---------------------------------------------------------------------------------------------------------

INPUT_GITLAB_URL_FILE="recursively_migrate_GitLab_URLs.txt"

while IFS= read -r GITLAB_REPO || [[ -n "$GITLAB_REPO" ]]; do
	#echo "Line read $GITLAB_REPO"
	PROJECT_NAME=$(basename "$GITLAB_REPO")
	#echo "Project name: $PROJECT_NAME"
	#echo "GitLab repo name: $GITLAB_REPO"
	
	GITHUB_URL="https://github.com/${GITHUB_ORG}/${PROJECT_NAME}.git"
	GITHUB_URL_WITH_TOKEN="https://$GITHUB_TOKEN@github.com/${GITHUB_ORG}/${PROJECT_NAME}.git"
	#echo "URL with token: $GITHUB_URL_WITH_TOKEN"
	#echo "GitHub URL: $GITHUB_URL"
	#echo "GitHub API: $GITHUB_API"
	#echo "GitHub with token $GITHUB_URL_WITH_TOKEN"

	echo "Cloning Gitlab repo (mirror/ bare repo)"
	git clone --mirror "$GITLAB_REPO"
	cd "${PROJECT_NAME}.git" || { echo "Failed to enter mirror repo directory"; exit 1; }
	cd ..
	#echo "Current working directory: $(pwd)"

	echo "Creating normal repo from bare repo"
	git clone "${PROJECT_NAME}.git" "${PROJECT_NAME}_normal"
	cd "${PROJECT_NAME}_normal" || { echo "Failed to enter non-mirror repo directory"; exit 1; }
	git fetch --all --prune #fetch all brnaches.

	echo "Converting cloned repo's remote branches to local...."
	git branch -D -r origin/main ##delete origin/remote/main (it's duplicate)
	for br in $(git branch -r | sed 's/origin\///'); do
    	git branch $br origin/$br
		git branch -D -r origin/$br
	done

	echo "Create GitHub remote project"
	CREATE_REPO_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" -d "{\"name\": \"$PROJECT_NAME\", \"private\": true}" "$GITHUB_API")

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

cat <<EOL > testConf.yaml
version:1
account:
    -id: App1234
    -oId: oc354
component:code
EOL

	echo "Committing the yaml file"
	git add testConf.yaml
	git commit -m "Created testConf.yaml file"

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
	#git push origin main --force
	git push --all origin
	git push --tags origin

	# Cleanup
	cd ..
	rm -rf "${PROJECT_NAME}.git"
	echo "------ Successfully migrated $PROJECT_NAME ------"
done < "$INPUT_GITLAB_URL_FILE"
echo "================= Migration process completed! ================="


