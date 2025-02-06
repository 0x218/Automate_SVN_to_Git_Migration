#!/bin/bash

#==========================================================================================================
#	Script name: 	listGitLabRepository.sh
#	Description: 	This script will iterates through GitLab subgroups and list all the repositories.
#
#
#	Developed by:	Renjith (sa.renjith@gmail.com)
#	
#	Usage:			./listGitLabRepository.sh
#	Prerequisites:	
#					Git command line tool installed
#					Access to Git repository (Token)
#					jq CLI
#
#	Script input:	None
#	Script output:	Displays your repository url and the project anme.
#	
#==========================================================================================================


##NOTE:-----------------------------------------------------------------------------------------------------
##Ensure you have tokens.conf in your current directory and having soemthing like GITLAB_TOKEN=<your Gitlab_token>
#####Example:
######### GITLAB_TOKEN_Ox218="glpat-JDFL-eDdjgdPrdaMerx4Xhfz2T8w"

source "./tokens.conf" ##now all the rows are stored in source.

GITLAB_TOKEN_VAR="GITLAB_TOKEN_Ox218"   ##GITLAB_TOKEN_VAR stores string "GITLAB_TOKEN_Ox218"

GITLAB_TOKEN="${!GITLAB_TOKEN_VAR}" #indirect refence; get teh value of GITLAB_TOKEN_SARENJITH_GMAIL from tokens.conf

if [[ -z "$GITLAB_TOKEN" ]]; then
	echo "Error: Token is not set in tokens.conf.  Exiting"
	exit 1
fi

#echo "GitLab token: $GITLAB_TOKEN"
#echo "GitHub token: $GITHUB_TOKEN"
##---------------------------------------------------------------------------------------------------------



GITLAB_URL="https://gitlab.com/"
GITLAB_USER="sa.renjith"

GROUP_PATH="retail"

FETCH_FROM_USER=false

###########################################################################################################
## fetch projects from user account
#==========================================================================================================
get_useraccount_projects() {
	echo "fetching repo from GitHub user account"
	
	local gitlab_api="$GITLAB_URL/api/v4/users/$GITLAB_USER/projects"
	
	response=$(curl -s --header "PRIVATE-TOKEN:$GITLAB_TOKEN" "$gitlab_api")
	echo "$response" | jq -r '.[] | "\(.web_url)          \(.name)"'
	
	exit 1
}



###########################################################################################################
## fetch projects from a gitlab group profile
#==========================================================================================================
echo "fetching repo from GitHub group profile"

#fetch all projects in a given Group ID
get_projects_from_group_profile() {
    local group_id=$1
    local page=1
	
	# GitLab API URL to fetch projects of the group (including subgroups)
    GITLAB_API="$GITLAB_URL/api/v4/groups/$group_id/projects?include_subgroups=true&per_page=100"

    while true; do
        # Make the API request
        response=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API&page=$page")

        # Break if no more projects are found
        if [[ -z "$response" || $(jq length <<< "$response") -eq 0 ]]; then
			echo "Done listing with $group_id."
            break
        fi

        # Extract and print the project name and URL (using jq)
        echo "$response" | jq -r '.[] | "\(.http_url_to_repo) \(.name)"'

        # Move to the next page
        ((page++))
    done
}



##########################################################################################################
## main
#==========================================================================================================
if $FETCH_FROM_USER; then
	get_useraccount_projects
else
	########################################################################################
	#######GROUP_IDS=("3813" "10787" "76360" "53899" "8796" "4461" "6685" "7929" "76363")
	#######for group_id in "${GROUP_IDS[@]}"; do
	#######	get_projects_from_group_profile "$group_id"
	#######done
	#########################################################################################
	
	
	# Step 1: Get Parent Group ID
	ROOT_GROUP_ID=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_URL/api/v4/groups?search=$GROUP_PATH" | \
    jq -r ".[] | select(.full_path==\"$GROUP_PATH\") | .id")
	
	if [[ -z "$ROOT_GROUP_ID" ]]; then
		echo "Error: Group '$GROUP_PATH' not found!"
		exit 1
	fi
	
	echo "Group id is: $ROOT_GROUP_ID"

	# Step 2: Fetch Projects from the root (also recursively fetch subgroups and their projects)
	echo "Fetching projects from the root group: $GROUP_PATH"
	get_projects_from_group_profile "$ROOT_GROUP_ID"
fi





