#!/bin/bash

#==========================================================================================================
#	Script name: 	git_svn_fetch.sh
#	Description: 	This script migrates an SVN repository to a local Git repository, preserving histry for
#					standard layouts.
#
#
#	Developed by:	Renjith (sa.renjith@gmail.com)
#	
#	Usage:			./git_svn_fetch.sh
#	Prerequisites:	
#				1) 	svn_project_folder_List.txt.  Create this file and list all the project names under -
#						the subversion URL that you are planning to fetch.  You can get -
#						this by running the command: svn list <Your SVN URL> | sed 's:/$::'
#
#				2)	SVN command line installed
#				3)	Git command line tool installed
#				4)	Access to SVN repository
#				5)	SVN URL
#				6)	List of SVN folders that needs to be migrated (in svn_project_folder_List.txt)
#				7)	svn_committerList.txt file composed of SVN autors, in the format: 
#						username=username	<username@email-domain.com>
#						Example:
#						sa.renjith=sa.renjith	<sa.renjith@gmail.com>
#					Note:You can geneate the list using: svn log YOUR_SVN_URL --quiet | grep -E '^r[0-9]+' | awk '{print #3}' | sort | uniq > svn_committerList.txt 
#
#	Script input:	None
#	Script output:	A Git repository of svn project with SVN history (for SVN trunk, branches, tags)
#	
#==========================================================================================================

FOLDER_LIST="folderList.txt"
SVN_HOST_URL="https://YOUR-SVN-SERVER/YOUR-APPLICATION"
SVN_PATH_URL="PATH/To/SVN/REPOSITORY"
SVN_BASE_URL="${SVN_HOST_URL}/${SVN_PATH_URL}"
AUTHORS_FILE="../commiterList.txt"


HAS_CUSTOM_TAGS=false
CUSTOM_TAG1=false  #add as many CUSTOM_TAGx you have in your repository and write you own CUSTOM_TAG handler by referring CUSTOM_TAG1 code 

# GitHub file size limit is 100MB. Use Git LFS if it exceeds.
FILE_SIZE_LIMIT="100M"

handle_largefiles(){
	echo "Searching for files larger than ${FILE_SIZE_LIMIT}..."
	large_files=$(find . -type f -size +"${FILE_SIZE_LIMIT}" -print | sed 's|^\./||' | sort | uniq)
	
	if [[ -n "$large_files" ]]; then
		echo "Initiliziing Git LFS"
		git lfs install > /dev/null 

		echo "Following files exceed ${FILE_SIZE_LIMIT} and will be migrated to Git LFS:"
		echo "$large_files"
		echo

		# Track each large file with Git LFS.
		while IFS= read -r file; do
			git lfs track "$file"
			echo "LFS tracked: $file"
		done <<< "$large_files"

		# Add .gitattributes file changes to Git.
		git add .gitattributes
		git commit -m "Moved large files to Git LFS"

		echo "Rewriting Git history to convert large files to Git LFS..."
		# Prepare a comma-separated list of file paths for git lfs migrate.
		include_list=$(echo "$large_files" | paste -sd, -)
		git lfs migrate import --include="$include_list" --everything
	else
		echo "No large files found."
	fi
	
}

if [[ ! -f $FOLDER_LIST ]]; then
	echo "Error: File $FOLDER_LIST not found!"
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
	
	echo "initializing git"
	####NOTE: if you add a flag --prefix=svn/, files will be created under refs/remotes/svn/*.  -
	###	   If not, it will be created under :refs/remotes/orgin/*.  
	###	   Hence this script (the sed stanzas) need to be adjusted based on your usage.
	echo "non-standard svn layout"
	git svn init --trunk=trunk --branches=branches/* --tags=tags/* --no-metadata "$SVN_URL" || 
	{ 
		echo "Error: Could not initialize Git repository in $FOLDER_NAME.  Skipping..."; 
		cd ..; 
		continue; 
	}
	
	echo "Linking svn committer\'s file name"
	git config svn.authorsfile "$AUTHORS_FILE" || 
	{ 	
		echo "Error: Could not set svn.authorsfile ${AUTHORS_FILE}.  Skipping..."; 
		cd ..; 
		continue; 
	}
	
	###NOTE: If your extra tags needs to be fetched, one way is to update it in your .git/config file.
	###Example, I have custom tag named "deployTags".  Then my HAS_CUSTOM_TAG must be true and write the tag details ingot .git/config file.
	if [ "$HAS_CUSTOM_TAGS" = true ]; then
		##Note: Assuming my CUSTOM_TAG1 is "deployTags"
		GIT_CONFIG_STANZA="fetch = ${SVN_PATH_URL}/${FOLDER_NAME}/deployTags/*:refs/remotes/origin/deployTags/*"
		echo "Updating .git/config file with $GIT_CONFIG_STANZA"
		git config --add svn-remote.svn.fetch "$GIT_CONFIG_STANZA"
	fi
	
	echo "Retreiving revision number"
	FIRST_REVISION=$(svn log --stop-on-copy "$SVN_URL" | grep -E '^r[0-9]+' | tail -1 | awk '{print $1}' | sed 's/r//')
	FINAL_REVISION=$(svn info $SVN_URL | grep "Revision" | awk '{print $2}')
	
	CHECKPOINT1=$FIRST_REVISION
	#CHECKPOINT1=300000
	CHUNK_SIZE=10000
	
	###NOTE: CLONE = git svn init AND git svn fetch.  
	###EXAMPLE: git svn clone "$SVN_URL" --trunk=trunk --branches=branches/* --tags=tags/* -A authors.txt -r 330000:HEAD .
	
	while [ "$CHECKPOINT1" -lt "$FINAL_REVISION" ]; do
		CHECKPOINT2=$((CHECKPOINT1 + CHUNK_SIZE))
		
		if [ "$CHECKPOINT2" -gt "$FINAL_REVISION" ]; then
			CHECKPOINT2=$FINAL_REVISION
		fi
		
		echo "Fecthing data for ${FOLDER_NAME} from rev ${CHECKPOINT1} to ${CHECKPOINT2}"
		git svn fetch -r "$CHECKPOINT1":"$CHECKPOINT2" > /dev/null || 
		{ 
			echo "Error: git svn failed for $FOLDER_NAME."; 
			cd ..; 
			continue; 
		}
		CHECKPOINT1=$(($CHECKPOINT2 + 1))
	done
		
	echo "Converting tags to git tags"
	for t in `git branch -a | grep 'tags/' | sed s_remotes/origin/tags/__`; do 
		git tag $t origin/tags/$t
		git branch -d -r origin/tags/$t
	done
	
	##convert custom_tag (if any) into branch
	if [ "$CUSTOM_TAG1" = true ]; then
		##Note: Assuming my CUSTOM_TAG1 is "deployTags"
		echo "Converting deployTags to git tags"
		for dT in `git branch -a | grep 'tags/' | sed s_remotes/origin/deployTags/__`; do 
			git tag $dT origin/deployTags/$dT
			git branch -d -r origin/deployTags/$dT
		done
	fi
	
	echo "Converting brances to git branches"
	for b in `git branch -r | sed s_origin/__`; do 
		git branch $b origin/$b
		git branch -D -r origin/$b
	done
	
	echo "Renaming 'master' branch to 'main'"
	git branch -m master main

	echo "Cleaning up"
	#delete the trunk branch as it is already copied into master
	git branch -d trunk
	
	handle_large_files
	
	git config --remove-section svn-remote.svn
	git config --remove-section svn
	rm -fr .git/svn .git/{logs,}/refs/remote/svn

	cd ..
done < "$FOLDER_LIST"

echo "Parsed all folders."
