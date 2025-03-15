#!/bin/bash

#==========================================================================================================
#	Script name: 	checkout_svn_repo.sh
#	Description: 	This script checkout (not clone) SVN repository.  Base URL is hardcoded, the folders are -
#				fetched from FolderList.txt
#
#
#	Developed by:	Renjith (sa.renjith@gmail.com)
#	
#	Usage:			./checkout_svn_repo.sh
#	Prerequisites:	
#				1) 	FolderList.txt.  Create this file and list all the project names under -
#						the subversion URL that you are planning to clone.  
#				2)	SVN command line installed
#				3)	Access to SVN repository
#				4)	SVN URL
#				5)	List of SVN folders that needs to be cloned (listed in FolderList.txt)
#
#	Script input:	None
#	Script output:	A svn checkout local repository 
#	
#==========================================================================================================

BASE_SVN_URL="https://YOUR-SVN-SERVER/YOUR-APPLICATION/PATH/To/REPOSITORY"
FOLDER_LIST="FolderList.txt"

while IFS= read -r FOLDER_NAME || [ -n "$FOLDER_NAME" ]; do
	FOLDER_NAME=$(echo "$FOLDER_NAME" | tr -d '\r' | xargs)
	
	SVN_URL="${BASE_SVN_URL}/${FOLDER_NAME}"
	echo "Checking out ${FOLDER_NAME}"
	svn checkout "$SVN_URL" "./${FOLDER_NAME}"
	echo "Successfully checked out ${SVN_URL}"
done < "$FOLDER_LIST"
