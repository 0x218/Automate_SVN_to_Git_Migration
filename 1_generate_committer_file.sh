#!/bin/bash

#==========================================================================================================
#	Script name: 	generate_committer_file.sh
#	Description: 	This script travers through subversion and generate svn_committerList.txt with 
#			committers name.
#
#
#	Developed by:	Renjith (sa.renjith@gmail.com)
#	
#	Usage:			./generate_committer_file.sh
#	Prerequisites:	
#					SVN command line installed
#					Access to SVN repository
#					SVN URL
#					List of SVN folders that needs to be migrated
#
#	Script input:	None
#	Script output:	svn_committerList.txt with committers name in it.
#			The output format will be:	userid=userid <userid@emaildomain.com>
#	  IMPORTANT NOTE: Before running this scritp, you must replace "emaildomain.com" in this script 
#			with your emaildomain name (ex: mycompany.com)
#	
#==========================================================================================================

#svn repository URL
SVN_URL="https://ENTER_YOUR_SUBVERSION_URL_HERE"

#output file with committer list
OUTPUT_FILE="svn_committerList.txt"

#temperory file to store output
TEMP_FILE=$(mktemp)

echo "Fetching SVN committers from $SVN_URL ..."
svn log "$SVN_URL" --quiet | grep -E '^r[0-9]+' | awk '{print $3}' | sort | uniq > "$TEMP_FILE"

echo "generating committer file"
> "$OUTPUT_FILE" #empty/create file

while read -r COMMITTER; do
	if [ -n "$COMMITTER" ]; then
		echo "$COMMITTER = $COMMITTER <${COMMITTER}@emaildomain.com>" >> "$OUTPUT_FILE"
	fi
done < "$TEMP_FILE"

rm -f "$TEMP_FILE"

echo "Committer file generated successfully"
