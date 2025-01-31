<h1> <p align="center"> <span style='font-weight:bold;align=center'>Migrating your SVN project into Git</span></p></h1>
There are three scripts you need to use to migrate any number of projects from your SVN repository into git.

# Pre-requisites
You must be able to execute svn commands.
You must have git command line tool installed.


# Script execution order
 1. 1_generate_committer_file.sh.  It generates an output file that consist of list of svn committer names.  Modify this script with your SVN url.  The output file name is svn_committerList.txt.  This output file name will be used by the second script.

2. 2_git_svn_fetch.sh.  Reads the svn_project_folder_List.txt and converts corresponding svn repositories into git repositories.
  This script assumes you have already filled in the name of svn projects in svn_project_folder_List.txt.
  You can do customization inside this script, including fetching additional tags.  The default logic assumes you are running this script against svn repository that has a standard SVN layout.

3. 3b_push_to_remote_github.sh.  Reads local_repo_list.txt and creates remote repositories based on the names documented in this file (which will be the same name of local repositories), push local repositories into remote repositories.
   By default this script performs an SSH connection, but you can reconfigure this script to use HTTPS connection.


   
