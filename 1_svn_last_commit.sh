#!/bin/bash

#==========================================================================================================
#	Script name: 	svn_last_commit.sh
#	Description: 	This script traverse into a svn repository and list the recent commit date
#
#
#	Developed by:	Renjith (sa.renjith@gmail.com)
#	
#	Usage:			./svn_last_commit.sh
#	Prerequisites:	
#					svn command line tool installed
#					Access to subversion repository
#					List of svn repositries that needs to be parsed.
#
#	Script input:	svn repository name will be read from REPO_LIST_FILE variable.
#	Script output:	Prints latest commit date of repository.
#	
#==========================================================================================================

REPO_LIST_FILE="folderList.txt"
CONSOLIDATED_SUMMARY_FILE="svn_consolidated.txt"
> "$CONSOLIDATED_SUMMARY_FILE"


if [[ ! -f "$REPO_LIST_FILE" ]]; then
	echo "Error: File `$REPO_LIST_FILE` not found!"
	exit 1
fi

while IFS= read -r svn_full_url; do
	#echo "URL before truncating: $svn_full_url"
	
	#Clear the carriage return.
	SVN_URL=$(echo "$svn_full_url" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r' )
	
	REPO_NAME=$(basename "$SVN_URL")
	#echo "Repo name: $REPO_NAME"
	
	TEMP_FILE="${REPO_NAME}_commit.log"
	#echo "Time stamp file: $TEMP_FILE"
	
	echo "Writing ${REPO_NAME}'s files with commit dates into $TEMP_FILE"
	svn list -v -R "$SVN_URL" | sort -k 2,2 | while read -r line; do
		commit_date=$(echo "$line" | awk '{print $2, $3}')
		file_path=$(echo "$line" | awk '{print $N}')
		echo "$commit_date $file_path" >> "$TEMP_FILE"
	done

	latest_commit=$(sort -r -k1,1 -k2,2 "$TEMP_FILE" | head -n 1)
	if [ -z "$latest_commit" ]; then
		echo "Error: No commit dates found."
		continue
	else
		echo "Latest commit date: $latest_commit"
		echo "$REPO_NAME: $latest_commit" >> "$CONSOLIDATED_SUMMARY_FILE"
	fi
	echo ""
	rm "$TEMP_FILE"
	
done < "$REPO_LIST_FILE"

echo "Parsing completed on all the svn repositories!"
