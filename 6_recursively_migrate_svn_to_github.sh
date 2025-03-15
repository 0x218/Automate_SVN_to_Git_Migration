#!/bin/bash

COMMITTER_FILE="svn_committerList.txt"
SVN_TO_GIT_FOLDER_LIST="folderList.txt"

SVN_HOST_URL="https://YOUR-GITLAB-SERVER/APPLICATION"
SVN_PATH_URL="PATH/To/GITHUB/REPOSITORY"
SVN_BASE_URL="${SVN_HOST_URL}/${SVN_PATH_URL}"

GIT_TOKEN_FILE="./tokens.conf"
GITHUB_ORG="YOUR-GITHUB-ORGANIZATION-NAME"
GITHUB_API="https://api.github.com/orgs/${GITHUB_ORG}/repos"
GITHUB_BASE_URL="https://github.com/${GITHUB_ORG}"


YAML_FILE_NAME="vitals.yaml"

#==========================================================================================================

log_begin_function(){
	local LOG_MSG=$1
	echo ""
	echo ">>>>>>>>>>${LOG_MSG}>>>>>>>>>>"
}

log_end_function(){
	local LOG_MSG=$1
	echo "<<<<<<<<<<${LOG_MSG}<<<<<<<<<<"
	echo ""
}

#==========================================================================================================
generate_committer_file() {
	log_begin_function "Executing generate_committer_file"
	
	SVN_URL="https://YOUR-GITLAB-SERVER/APPLICATION/PATH/To/GITHUB/REPOSITORY"

	#output file with committer list

	#temperory file to store output
	TEMP_FILE=$(mktemp)

	echo "Fetching SVN committers from $SVN_URL ..."
	svn log "$SVN_URL" --quiet | grep -E '^r[0-9]+' | awk '{print $3}' | sort | uniq > "$TEMP_FILE"

	echo "generating committer file"
> "$COMMITTER_FILE" #empty/create file

	while read -r COMMITTER; do
		if [ -n "$COMMITTER" ]; then
			echo "$COMMITTER = $COMMITTER <${COMMITTER}@email-domain.com>" >> "$COMMITTER_FILE"
		fi
	done < "$TEMP_FILE"

	rm -f "$TEMP_FILE"
	
	log_end_function "Committer file generated successfully"
}
#==========================================================================================================

write_additional_tags() {
	log_begin_function "Executing write_additional_tags"
	
	local GIT_CONFIG_STANZA=$1
	echo "Updating .git/config file with $GIT_CONFIG_STANZA"
	git config --add svn-remote.svn.tags "$GIT_CONFIG_STANZA"
	
	log_end_function "Updated git config file successfully"
}
		
svnfetch_all(){
	log_begin_function "Executing svnfetch_all"
	
	local FIRST_REVISION=$1
	local HEAD_REVISION=$2
	local LOG_FILE=$3
	
	git svn fetch -r "$FIRST_REVISION":HEAD >> "$LOG_FILE" 2>&1 ||   
	{ 
		echo "Error: SVN fetch failed.  Exiting..."; 
		cd ..; 
		return 301; 
	}
	
	log_end_function "SVN fetch completed successfully"
	return 0;
}	
	
svnfetch_incremental(){
	log_begin_function "Executing svnfetch_incremental"
	
	local FIRST_REVISION=$1
	local HEAD_REVISION=$2
	local LOG_FILE=$3
	
	while [ "$FIRST_REVISION" -lt "$HEAD_REVISION" ]; do
		SECOND_REVISION=$((FIRST_REVISION + 10000))
		if [ "$SECOND_REVISION" -gt "$HEAD_REVISION" ]; then
			SECOND_REVISION=$HEAD_REVISION
		fi
		echo "Fecthing SVN data for ${SVN_FOLDER_NAME} from revision# ${FIRST_REVISION} to ${SECOND_REVISION}"
		git svn fetch -r "$FIRST_REVISION":"$SECOND_REVISION" >> "$LOG_FILE" 2>&1 ||   
		{ 
			echo "Error: SVN fetch failed.  Exiting..."; 
			cd ..; 
			return 401; 
		}
		
		FIRST_REVISION=$((SECOND_REVISION + 1))
	done
	
	log_end_function "SVN incremental fetch completed successfully"
	return 0;
}
		

convert_remote_origin_tags_to_local_branches() {
	log_begin_function "Executing convert_remote_origin_tags_to_local_branches"
	
	local TAG_NAME=$1
	
	for t in `git branch -a | grep 'tags/' | sed s_remotes/origin/${TAG_NAME}/__`; do 
		git tag $t origin/${TAG_NAME}/$t
		git branch -d -r origin/${TAG_NAME}/$t
	done

	log_end_function "Successfully converted SVN tags into Git branches"
}
		
		
fetch_from_svn() {
	log_begin_function "Executing fetch_from_svn"
	
	local SVN_FOLDER_NAME=$1
	
	SVN_URL="${SVN_BASE_URL}/${SVN_FOLDER_NAME}"
	
	#move into folder
	cd "$SVN_FOLDER_NAME" || 
	{ 
		echo "Error: Could not cd into $SVN_FOLDER_NAME.  Exiting..."; 
		return 101;  ##error
	}
	##echo "Current directory: $(pwd)"
		
	echo "initializing git with standard svn layout"
	
	####To fetch proper svn repository, use below command:
	#git svn init --trunk=trunk --branches=branches/* --tags=tags/* --no-metadata "$SVN_URL" || 
	
	###To fetch folders inside trunk use below command:
	git svn init --trunk="${SVN_PATH_URL}/${SVN_FOLDER_NAME}" "$SVN_HOST_URL" --no-metadata ||   
	{ 
		echo "Error: Could not initialize Git repository in $SVN_FOLDER_NAME.  Exiting..."; 
		cd ..; 
		return 102; 
	}
	
	#-----------------------------------------------------------------------------
	echo "Linking svn committer's file name"
	git config svn.authorsfile "$SVN_AUTHORS_FILE" || 
	{ 	
		echo "Error: Could not set svn.authorsfile $SVN_AUTHORS_FILE.  Exiting..."; 
		cd ..; 
		return 103; 
	}
	
	#-----------------------------------------------------------------------------
	#echo "Writing additional tag information in git config file"
	#write_additional_tags "fetch = ${SVN_PATH_URL}/${SVN_FOLDER_NAME}/deployTags/*:refs/remotes/origin/deployTags_prod/*"
	####write_additional_tags "fetch = ${SVN_PATH_URL}/${SVN_FOLDER_NAME}/deploytags/*:refs/remotes/origin/deploytags_uat/*"
	
	#-----------------------------------------------------------------------------
	echo "Retreiving revision number"
	FIRST_REVISION=$(svn log --stop-on-copy "$SVN_URL" | grep -E '^r[0-9]+' | tail -1 | awk '{print $1}' | sed 's/r//')
	HEAD_REVISION=$(svn info "$SVN_URL" | grep "Revision:" | awk '{print $2}')
	
	#-----------------------------------------------------------------------------
	echo "Fecthing SVN data for ${SVN_FOLDER_NAME} from revision# ${FIRST_REVISION}"
	LOG_FILE="../${SVN_FOLDER_NAME}_fetch.log"
	
	##fetch all at once...
	#svnfetch_all "$FIRST_REVISION" "$HEAD_REVISION" "LOG_FILE"
	
	##incremental fetch...
	svnfetch_incremental "$FIRST_REVISION" "$HEAD_REVISION" "$LOG_FILE"
	
	status=$?
	if [ $status -ne 0 ]; then
		echo "Error: SVN fetch error $status... Exiting."
		return 104;
	fi
		
	#-----------------------------------------------------------------------------
	echo "Converting tags to git tags"
	####SYNTAX: convert_remotetags_to_localbranches "<tag name ex: deployTags>"
	convert_remote_origin_tags_to_local_branches "tags"
	
	##echo "Converting deployTags_PROD to git tags"
	##convert_remote_origin_tags_to_local_branches "deployTags"
	
	##echo "Converting deploytags_UAT to git tags"
	##convert_remote_origin_tags_to_local_branches "deploytags"
	
	#-----------------------------------------------------------------------------
	echo "Converting branches to git branches"
	for b in `git branch -r | sed s_origin/__`; do 
		git branch $b origin/$b
		git branch -D -r origin/$b
	done
	
	#-----------------------------------------------------------------------------
	echo "Cleaning up"
	#delete the trunk brach as it is already copied into master
	git branch -D trunk
	
	git config --remove-section svn-remote.svn
	git config --remove-section svn
	rm -fr .gti/svn .git/{logs,}/refs/remote/svn

	##go back to previous folder
	cd ..

	log_end_function "Successfully parsed all SVN folders"
	return 0;
}
#==========================================================================================================

create_commit_yaml_file() {
	log_begin_function "Executing create_commit_yaml_file"
	
	cat <<EOL > $YAML_FILE_NAME
version:2
account:
	-id: AppId_13592
component:code
EOL

	echo "Committing the yaml file"
	git add $YAML_FILE_NAME
	git commit -m "Created $YAML_FILE_NAME file"
	
	log_end_function "Successfully created and committed $YAML_FILE_NAME"
	return 0;
}

create_commit_readme_file() {
	log_begin_function "Executing create_default_readme_file"
	local SVN_FOLDER_NAME=$1
	local GITHUB_URL=$2
	
	
	cat <<EOF > README.md
# Project name
$SVN_FOLDER_NAME


## Description 
TODO:

## Features
 - Feature 1
	TODO:
	
 - Feature 2
 	TODO:
 
 
## Installation
\`\`\`sh
# Clone the repository
git clone ${GITHUB_URL}

## Change into project directory
cd $SVN_FOLDER_NAME

#Install dependencies
TODO: 

\`\`\`

## Usage
\`\`\`sh
# Run the Project
TODO: <run command>
\`\`\`

## Contributing
1. Fork the repository
2. Create a new branch (\`git checkout -b feature-branch\`)
3. Commit your changes (\`git commit -m 'short comment about your solution'\`)
4. Push to the branch (\`git ush origin feature-branch\`)
5. Create a Pull request

## License
This project is licensed under [LICENSE](LICENSE).
EOF

	echo "Readme.md has been created successfully."
	
	echo "Committing the readme.md file"
	git add "README.md"
	git commit -m "Created a default README.md file"
	
	log_end_function "Succesfully created adn commited readme file"
	return 0;
}

move_local_gitrepo_to_remote_github(){
	log_begin_function "Executing move_local_gitrepo_to_remote_github"
	
	local SVN_FOLDER_NAME=$1
	
	source "$GIT_TOKEN_FILE" ##now all the rows are stored in source.
	GITHUB_TOKEN_VAR="GITHUB_TOKEN_SARENJITH_GMAIL" ##extract string GITHUB_TOKEN_SARENJITH_GMAIL
	GITHUB_TOKEN="${!GITHUB_TOKEN_VAR}"  ##extract value of GITHUB_TOKEN_SARENJITH_GMAIL

	if [[ -z "$GITHUB_TOKEN" ]]; then
		echo "Error: Github token is not set in tokens.conf.  Exiting"
		return 201;
	fi
	
	cd "$SVN_FOLDER_NAME" || 
	{ 
		echo "Error: Could not cd into $SVN_FOLDER_NAME.  Exiting..."; 
		return 202;  ##error
	}
	echo "Current directory: $(pwd)"
	
	#echo "GitHub token: $GITHUB_TOKEN"	

	###GitHub project category
	###DEST_PROJECT_NAME_CATEGORY="<solution name>-<application name>-"  
	###example:DEST_PROJECT_NAME_CATEGORY="Toyota-Electric-dev"
	DEST_PROJECT_NAME_CATEGORY="poc-"

	#for uniformity replace - and space in repository name with _
	TMP_DEST_PROJECT_NAME=$(echo "$SVN_FOLDER_NAME" | sed 's/[- ]/_/g')
	
	#build GitHub repository name
	DEST_PROJECT_NAME="${DEST_PROJECT_NAME_CATEGORY}${TMP_DEST_PROJECT_NAME}"

	GITHUB_URL="https://github.com/${GITHUB_ORG}/${DEST_PROJECT_NAME}.git"
	GITHUB_URL_WITH_TOKEN="https://$GITHUB_TOKEN@github.com/${GITHUB_ORG}/${DEST_PROJECT_NAME}.git"
	#echo "URL with token: $GITHUB_URL_WITH_TOKEN"
	#echo "GitHub URL: $GITHUB_URL"
	#echo "GitHub API: $GITHUB_API"
	#echo "GitHub with token $GITHUB_URL_WITH_TOKEN"

	#delete_unwanted_branches
	echo "deleting duplicate and unwanted branches..."
	##delete orgin/remote/master branch (if present), as it is duplicate of local 'master'
	git branch -D -r origin/master
	
	##delete orgin/remote/main branch (if present), as it is duplicate of local 'main'
	git branch -D -r origin/main
	
	echo "Converting remote branches to local..."
	for br in $(git branch -r | sed 's/origin\///'); do
		echo "Creating local banch $br and deleting origin/$br"
		git branch $br origin/$br
		git branch -D -r origin/$br
	done

	echo "Renaming 'master' branch to 'main' branch."
	git branch -m master main
	
	echo "Create GitHub remote project"
	GIT_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" -d "{\"name\": \"$DEST_PROJECT_NAME\", \"visibility\": \"internal\"}" "$GITHUB_API")

	# Check if the repository was created successfully
	if echo "$GIT_RESPONSE" | grep -q '"id":'; then
		echo "GitHub repository created successfully."
	else
		echo "Failed to create GitHub repository. Response: $GIT_RESPONSE"
		return 203;
	fi

	echo "Remove gitlab remote reference"
	git remote remove origin

	echo "Creating yaml file in main branch"
	git checkout main

	##create and commit YAML file
	create_commit_yaml_file
	
	##create and commmit default readme file
	create_commit_readme_file "$SVN_FOLDER_NAME" "$GITHUB_URL"
	
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

	cd ..
	
	log_end_function "Successfully migrated SVN $SOURCE_PROJECT_NAME into GitHub"
	return 0;
}

#==========================================================================================================
cleanup_git_folders() {
	log_begin_function_function "Executing cleanup_git_folders"
	
	local SVN_FOLDER_NAME=$1
	
	##echo "Deleting mirror gitlab project"
	##renjith: rm -rf "${SOURCE_PROJECT_NAME}.git"
	
	##echo "Deleting mirror-feteched gitlab project"
	##renjith: rm -rf "${SOURCE_PROJECT_NAME}_normal"
	
	echo "Delete folder $SVN_FOLDER_NAME"
	rm -rf "${SVN_FOLDER_NAME}"
	
	log_end_function "Successfully cleaned $SVN_FOLDER_NAME"
	return 0;
}
#==========================================================================================================


main() {
	echo ">>>------Starting main()------>>>"
	
	echo "------main: generating committer file------"
	generate_committer_file
	
	if [[ ! -f $SVN_TO_GIT_FOLDER_LIST ]]; then
		echo "Error: File `$SVN_TO_GIT_FOLDER_LIST` not found!"
		exit 1
	fi

	while IFS= read -r SVN_FOLDER_NAME || [[ -n "$SVN_FOLDER_NAME" ]]; do
		SVN_FOLDER_NAME=$(echo "$SVN_FOLDER_NAME" | tr -d '\r' | xargs)
		if [[ -z "$SVN_FOLDER_NAME" ]]; then
			echo "Error: Error parsing create directory $SVN_FOLDER_NAME.   Skipping..."
			continue
		fi

		echo ">>>**********Processing SVN folder: $SVN_FOLDER_NAME**********>>>"
		mkdir -p "$SVN_FOLDER_NAME"
		if [[ $? -ne 0 ]]; then
			echo "Error: Could not create directory $SVN_FOLDER_NAME.   Skipping..."
			continue
		fi
		
		echo "------main: fetching information of $SVN_FOLDER_NAME from the svn------"
		fetch_from_svn "$SVN_FOLDER_NAME"
		status=$?
		if [ $status -ne 0 ]; then
			echo "Error: Fetch from svn failed with $status... Continuing with next in the list."
			continue
		fi
			
		echo "------main: Uploading project to GitHub------"
		move_local_gitrepo_to_remote_github "$SVN_FOLDER_NAME"
		status=$?
		if [ $status -ne 0 ]; then
			echo "Error: Failed to move to GitHub with $status... Continuing with next in the list."
			continue
		fi
		
		#delete git migrated folder
		echo "------main: Deleting git folders------"
		#renjith commented for test: cleanup_git_folders "$SVN_FOLDER_NAME"
		
		echo "<<<**********SVN to GitHub migration completed for $SVN_FOLDER_NAME**********<<<"
	done < "$SVN_TO_GIT_FOLDER_LIST"
	
	echo "<<<------End of main()------<<<"
}

##execute the main function...
main