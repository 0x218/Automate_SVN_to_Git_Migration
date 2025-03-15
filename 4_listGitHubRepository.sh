#!/bin/bash

#==========================================================================================================
#	Script name: 	listGitHubRepository.sh
#	Description: 	This script will list all the repositories under your GitHub account.
#
#
#	Developed by:	Renjith (sa.renjith@gmail.com)
#	
#	Usage:			./listGitHubRepository.sh
#	Prerequisites:	
#					Git command line tool installed
#					Access to Git repository (Token)
#					jq CLI
#
#	Script input:	None
#	Script output:	create repos.json (serve a cache) and print your repository url and project anme.
#	
#==========================================================================================================

source "./tokens.conf" ##now all the rows are stored in source.

GITLAB_TOKEN_VAR="GITLAB_TOKEN_SARENJITH_GMAIL"   ##GITLAB_TOKEN_VAR stores string "GITLAB_TOKEN_SARENJITH_GMAIL"

GITLAB_TOKEN="${!GITLAB_TOKEN_VAR}" #indirect refence; get teh value of GITLAB_TOKEN_SARENJITH_GMAIL from tokens.conf

if [[ -z "$GITLAB_TOKEN" ]]; then
	echo "Error: Token is not set in tokens.conf.  Exiting"
	exit 1
fi
#echo "Github token: $GITHUB_TOKEN"

GITHUB_USERNAME="0x218"
GITHUB_API="https://api.github.com/user/repos"
OUTPUT_FILE="repos.json"

#fetch repo from GitHub
curl -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" "$GITHUB_API" > "$OUTPUT_FILE"

#parse and fetch from cache
cat "$OUTPUT_FILE" | jq -r '.[] | "\(.html_url) \(.name)"'