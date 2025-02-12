#!/bin/bash

#==========================================================================================================
#	Script name: 	migrate_GitLab_mirror_to_GitHub.sh
#	Description: 	This script creates GitHub 'mirror" repository and push this mirror repo into -
#					remote GitHub server.
#
#
#	Developed by:	Renjith (sa.renjith@gmail.com)
#	
#	Usage:			./migrate_GitLab_mirror_to_GitHub.sh
#	Prerequisites:	
#					Git command line tool installed
#					Access to GitHub and GitLab
#					List of local GitLab repositries that needs to be mirrored.
#
#	Script input:	tokens.conf in your current directory that will have token information.
#	Script output:	A remote GitHub repository with the data that is in GitLab repository.
#	
#==========================================================================================================

##NOTE:-----------------------------------------------------------------------------------------------------
##Ensure you have tokens.conf in your current directory and having soemthing like GITLAB_TOKEN=<your Gitlab_token>
#####Example:
#########GITLAB_TOKEN_0x218="glpat-JDFL-eDdjgdPrdaMerx4Xhfz2T8w"
######### GITHUB_TOKEN_0x218="github_pat_13245jadsfYlager_Vasefadfglkagadg-a34k3gJ4QDrDagadgl23AS"

source "./tokens.conf" ##now all the rows are stored in source.

#GITLAB_TOKEN_VAR="GITLAB_TOKEN_0x218"   ##GITLAB_TOKEN_VAR stores string "GITLAB_TOKEN_0x218"
GITHUB_TOKEN_VAR="GITHUB_TOKEN_0x218_MYORG1"  ##You need the token generated from GitHub-Organization

#GITLAB_TOKEN="${!GITLAB_TOKEN_VAR}" #indirect refence; get the value of GITLAB_TOKEN_0x218 from tokens.conf
GITHUB_TOKEN="${!GITHUB_TOKEN_VAR}"

if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "Error: Github token is not set in tokens.conf.  Exiting"
	exit 1
fi

#echo "GitLab token: $GITLAB_TOKEN"
#echo "GitHub token: $GITHUB_TOKEN"
##---------------------------------------------------------------------------------------------------------

# Set variables
GITLAB_URL="https://gitlab.com/sa.renjith/carmanufacturer"
PROJECT_NAME=$(basename "$GITLAB_URL")
GITLAB_REPO="https://gitlab.com/sa.renjith/${PROJECT_NAME}.git"

GITHUB_ORG="MyTest1Org"
GITHUB_API="https://api.github.com/orgs/${GITHUB_ORG}/repos"
GITHUB_URL="https://github.com/${GITHUB_ORG}/${PROJECT_NAME}.git"
GITHUB_URL_WITH_TOKEN="https://$GITHUB_TOKEN@github.com/${GITHUB_ORG}/${PROJECT_NAME}.git"

#echo "GitHub URL: $GITHUB_URL"
#echo "GitHub API: $GITHUB_API"
#echo "GitHub with token $GITHUB_URL_WITH_TOKEN"

echo "Cloning Gitlab repo (mirror/ bare repo)"
git clone --mirror "$GITLAB_REPO"
cd "${PROJECT_NAME}.git" || exit 1

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

# Add GitHub as a remote repository
echo "Link GitHub remote repository to origin"
git remote add github "$GITHUB_URL_WITH_TOKEN"

echo "Push all branches and tags to GitHub"
git push --mirror github

# Cleanup
cd ..
#rm -rf "${PROJECT_NAME}.git"
echo "Migration completed successfully!"

