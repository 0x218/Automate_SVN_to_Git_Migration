#!/bin/bash

#==========================================================================================================
#	Script name: 	listGitLabRepository.sh
#	Description: 	This script will list all the repositories under your GitLab account.
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
#	Script output:	create repos.json (serve a cache) and print your repository url and project anme.
#	
#==========================================================================================================

GITLAB_URL="https://gitlab.com"
GITLAB_USER="sa.renjith"
GITLAB_TOKEN="YOUR_GITLAB_TOKEN_HERE"

GITLAB_API="$GITLAB_URL/api/v4/users/$GITLAB_USER/projects"
OUTPUT_FILE="repos.json"

#fetch repo from GitHub
curl -s --header "PRIVATE-TOKEN:$GITLAB_TOKEN" "$GITLAB_API" > "$OUTPUT_FILE"

#parse and fetch from cache
cat "$OUTPUT_FILE" | jq -r '.[] | "\(.web_url)          \(.name)"'