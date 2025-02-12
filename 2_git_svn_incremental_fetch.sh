#!/bin/bash

#==========================================================================================================
#	Script name: 	git_svn_incremental_fetch.sh
#	Description: 	This script migrates an SVN repository to a local Git repository, preserving history for
#					standard layouts.  This script follows a stage by stage migration - which makes it ideal 
#					to migrate extremely large SVN projects.  Instead of cloning everything together, it clones -
#					revision to revision.
#
#
#	Developed by:	Renjith (sa.renjith@gmail.com)
#	
#	Usage:			./git_svn_incremental_fetch.sh
#	Prerequisites:	
#					SVN command line installed
#					Git command line tool installed
#					Access to SVN repository
#					SVN URL
#					List of SVN folders that needs to be migrated
#					A text file composed of SVN autors, in the format: username=username	<username@mailserver.com>
#							example:
#						sa.renjith=sa.renjith	<sa.renjith@gmail.com9
#					You can geneate the list using: svn log YOUR_SVN_URL --quiet | grep -E '^r[0-9]+' | awk '{print #3}' | sort | uniq > output.txt
#
#
#	Script input:	None
#	Script output:	A Git repository with SVN history (for SVN trunk, branches, tags)
#	
#==========================================================================================================

#FOLDER_LIST="folderList.txt"
FOLDER_LIST="folderList_MPVMC1.txt"
SVN_HOST_URL="https://localhost.com/mysvnrepo"
SVN_PATH_URL="retail/clients"
SVN_BASE_URL="${SVN_HOST_URL}/${SVN_PATH_URL}"
AUTHORS_FILE="../svnCommiterList.txt"

STD_LAYOUT_SVN=true
EDIT_GIT_CONFIG=true
DEPLOY_TAGS=false

if [[ ! -f $FOLDER_LIST ]]; then
	echo "Error: File `$FOLDER_LIST` not found!"
	exit 1
fi


while IFS= read -r FOLDER_NAME || [[ -n "$FOLDER_NAME" ]]; do
	FOLDER_NAME=$(echo "$FOLDER_NAME" | tr -d '\r' | xargs)
	if [[ -z "$FOLDER_NAME" ]]; then
		continue
	fi

	echo "Processing folder: $FOLDER_NAME"
	mkdir -p "$FOLDER_NAME"
	if [[ $? -ne 0 ]]; then
		echo "Error: Could not create directory `$FOLDER_NAME`.   Skipping..."
		continue
	fi

	cd "$FOLDER_NAME" || 
	{ 
		echo "Error: Could not cd into `$FOLDER_NAME`.  Skipping..."; 
		continue; 
	}
	echo "Current directory: $(pwd)"
	
	SVN_URL="${SVN_BASE_URL}/${FOLDER_NAME}"
	
	echo "initializing git with standard svn layout"
	git svn init --trunk=trunk --branches=branches/* --tags=tags/* --no-metadata "$SVN_URL" ||   
	{ 
		echo "Error: Could not initialize Git repository in `$FOLDER_NAME`.  Skipping..."; 
		cd ..; 
		continue; 
	}
	
	echo "Linking svn committer\'s file name"
	git config svn.authorsfile "$AUTHORS_FILE" || 
	{ 	
		echo "Error: Could not set svn.authorsfile $AUTHORS_FILE.  Skipping..."; 
		cd ..; 
		continue; 
	}
	
	GIT_CONFIG_STANZA1="fetch = ${SVN_PATH_URL}/${FOLDER_NAME}/deployTags/*:refs/remotes/origin/deployTags_prod/*"
	GIT_CONFIG_STANZA2="fetch = ${SVN_PATH_URL}/${FOLDER_NAME}/deploytags/*:refs/remotes/origin/deploytags_uat/*"
	echo "Updating .git/config file with $GIT_CONFIG_STANZA1 and $GIT_CONFIG_STANZA2"
	git config --add svn-remote.svn.tags "$GIT_CONFIG_STANZA1"
	git config --add svn-remote.svn.tags "$GIT_CONFIG_STANZA2"
	
	echo "Retreiving revision number"
	#FIRST_REVISION=$(svn log --stop-on-copy "$SVN_URL" | grep -E '^r[0-9]+' | tail -1 | awk '{print $1}' | sed 's/r//')
	FIRST_REVISION=309175
	HEAD_REVISION=$(svn info "$SVN_URL" | grep "Revision:" | awk '{print $2}')

	echo "Fecthing SVN data for ${FOLDER_NAME} from revision# ${FIRST_REVISION}"
	LOG_FILE="../${FOLDER_NAME}_fetch.log"
	while [ "$FIRST_REVISION" -lt "$HEAD_REVISION" ]; do
		SECOND_REVISION=$((FIRST_REVISION + 10000))
		if [ "$SECOND_REVISION" -gt "$HEAD_REVISION" ]; then
			SECOND_REVISION=$HEAD_REVISION
		fi
		echo "Fecthing SVN data for ${FOLDER_NAME} from revision# ${FIRST_REVISION} to ${SECOND_REVISION}"
		git svn fetch -r "$FIRST_REVISION":"$SECOND_REVISION" # >> "$LOG_FILE" 2>&1
		FIRST_REVISION=$((SECOND_REVISION + 1))
	done
	
	echo "Converting tags to git tags"
	for t in `git branch -a | grep 'tags/' | sed s_remotes/origin/tags/__`; do 
		git tag $t origin/tags/$t
		git branch -d -r origin/tags/$t
	done
	
	echo "Converting deployTags_PROD to git tags"
	for dT in `git branch -a | grep 'tags/' | sed s_remotes/origin/deployTags_prod/__`; do 
		git tag $dT origin/deployTags_prod/$dT
		git branch -d -r origin/deployTags_prod/$dT
	done
	
	echo "Converting deploytags_UAT to git tags"
	for dT in `git branch -a | grep 'tags/' | sed s_remotes/origin/deploytags_uat/__`; do 
		git tag $dT origin/deploytags_uat/$dT
		git branch -d -r origin/deploytags_uat/$dT
	done

	echo "Converting brances to git branches"
	for b in `git branch -r | sed s_origin/__`; do 
		git branch $b origin/$b
		git branch -D -r origin/$b
	done
	
	echo "Cleaning up"
	#delete the trunk brach as it is already copied into master
	git branch -d trunk
	
	git config --remove-section svn-remote.svn
	git config --remove-section svn
	rm -fr .gti/svn .git/{logs,}/refs/remote/svn

	cd ..
done < "$FOLDER_LIST"

echo "Parsed all folders."
