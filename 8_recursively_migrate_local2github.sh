GIT_FOLDER_LIST="folderList.txt" 
YAML_FILE_NAME="vitals.yaml"
DEST_PROJECT_NAME_CATEGORY="poc-"

GITHUB_TOKEN="ghp_"
GITHUB_ORG="YOUR-GITHUB-ORGANIZATION-NAME"

GITHUB_API="https://api.github.com/orgs/${GITHUB_ORG}/repos"
GITHUB_BASE_URL="https://github.com/${GITHUB_ORG}"


create_commit_yaml_file() {
	echo "Executing create_commit_yaml_file"
	
	cat <<EOL > $YAML_FILE_NAME
version:2
account:
	-id: APPID_135792
component:code
EOL

	echo "Committing the yaml file"
	git add $YAML_FILE_NAME
	git commit -m "Created $YAML_FILE_NAME file"
	
	echo "Successfully created and committed $YAML_FILE_NAME"
	return 0;
}

create_commit_readme_file() {
	log_begin_function "Executing create_default_readme_file"
	local SVN_FOLDER_NAME=$1
	local GITHUB_URL=$2
	
	
	cat <<EOF > README.md
## Project name
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
This project is licensed under the [LICENSE](LICENSE).
EOF

	echo "Readme.md has been created successfully."
	
	echo "Committing the readme.md file"
	git add "README.md"
	git commit -m "Created a default README.md file"
	
	log_end_function "Succesfully created and commited readme file"
	return 0;
}
push_ruleset(){
	local FULL_PROJECT_NAME=$1
	local RULESET_FILENAME=$2
	
	echo "Applying ruleset on $FULL_PROJECT_NAME"
	GITHUB_API_RULESET="https://api.github.com/repos/${GITHUB_ORG}/${FULL_PROJECT_NAME}/rulesets"
	
	curl -X POST -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" -d @"$RULESET_FILENAME" "$GITHUB_API_RULESET" >/dev/null 2>&1
}

main() {
	echo ">>>------Starting main()------>>>"
	
	while IFS= read -r SVN_FOLDER_NAME || [[ -n "$SVN_FOLDER_NAME" ]]; do
		SVN_FOLDER_NAME=$(echo "$SVN_FOLDER_NAME" | tr -d '\r' | xargs)
		if [[ -z "$SVN_FOLDER_NAME" ]]; then
			echo "Error: Error parsing create directory $SVN_FOLDER_NAME.   Skipping..."
			continue
		fi

		echo "------main: Uploading project to GitHub------"
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
		
		git init .
		git add .
		git commit -m 'initial code commit'
		
		#Renaming 'master' branch to 'main' branch
		git branch -m master main
	
		#for uniformity replace - and space in repository name with _
		TMP_DEST_PROJECT_NAME=$(echo "$SVN_FOLDER_NAME" | sed 's/[- ]/_/g')

		#build GitHub repository name
		DEST_PROJECT_NAME="${DEST_PROJECT_NAME_CATEGORY}${TMP_DEST_PROJECT_NAME}"
		
		GITHUB_URL="https://github.com/${GITHUB_ORG}/${DEST_PROJECT_NAME}.git"
		GITHUB_URL_WITH_TOKEN="https://$GITHUB_TOKEN@github.com/${GITHUB_ORG}/${DEST_PROJECT_NAME}.git"
		
		echo "Create GitHub remote project"
		GIT_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" -d "{\"name\": \"$DEST_PROJECT_NAME\", \"visibility\": \"internal\"}" "$GITHUB_API")

		# Check if the repository was created successfully
		if echo "$GIT_RESPONSE" | grep -q '"id":'; then
			echo "GitHub repository created successfully."
		else
			echo "Failed to create GitHub repository. Response: $GIT_RESPONSE"
			return 203;
		fi
	
		##create and commit YAML file
		create_commit_yaml_file
		
		##create and commmit default readme file
		create_commit_readme_file "$SVN_FOLDER_NAME" "$GITHUB_URL"
		
		echo "Link GitHub remote repository to origin"
		git remote add origin "$GITHUB_URL_WITH_TOKEN"
	
		git checkout -b "dev"
		git checkout -b "release"
		
		push_ruleset "$DEST_PROJECT_NAME" "../dev_branch_ruleset.json"
		push_ruleset "$DEST_PROJECT_NAME" "../release_branch_ruleset.json"
	
		echo "Push all branches and tags to GitHub"
		#git push origin main --force
		git push --all -u origin
	
		cd ..
		
		echo "<<<**********SVN to GitHub migration completed for $SVN_FOLDER_NAME**********<<<"
	done < "$GIT_FOLDER_LIST"
	
	echo "<<<------End of main()------<<<"
}

##execute the main function...
main