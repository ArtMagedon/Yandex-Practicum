SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_DIR="$(dirname "$SCRIPT_PATH")"

cd "$REPO_DIR" || {
    echo "ERROR: Cannot access repository directory."
    exit 1
}

echo "Checking repository..."
echo "Repository: $REPO_DIR"

if [ ! -d ".git" ]; then
    echo "ERROR: This directory is not a Git repository."
    exit 1
fi

BRANCH=$(git branch --show-current)

if [ -z "$BRANCH" ]; then
    echo "ERROR: Cannot determine the current Git branch."
    exit 1
fi

echo "Branch: $BRANCH"
echo "Checking remote repository..."

if ! git fetch origin "$BRANCH"; then
    echo "ERROR: Failed to fetch remote repository."
    echo "Possible reasons:"
    echo "- No Internet connection."
    echo "- Remote repository is unavailable."
    echo "- Authentication failed."
    echo "- Remote repository is not configured correctly."
    exit 1
fi

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$BRANCH")

LOCAL_CHANGES=$(git status --porcelain)

# Check uncommitted local changes
if [ -n "$LOCAL_CHANGES" ]; then
    echo "Local changes detected."

    # Check whether remote has new commits
    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "ERROR: Both local and remote changes are present."
        echo "Automatic synchronization is not possible."
        echo "Please resolve the differences manually."
        exit 1
    fi

	echo "Adding local changes..."

	git add -A

	CHANGED_FILES=$(git diff --cached --name-status)
	FILE_COUNT=$(git diff --cached --name-only | wc -l)

	if [ "$FILE_COUNT" -eq 1 ]; then
		STATUS=$(echo "$CHANGED_FILES" | awk '{print $1}')
		FILE=$(echo "$CHANGED_FILES" | cut -f2-)

		case "$STATUS" in
		    A)
		        COMMIT_MESSAGE="Added: $FILE"
		        ;;
		    M)
		        COMMIT_MESSAGE="Modified: $FILE"
		        ;;
		    D)
		        COMMIT_MESSAGE="Deleted: $FILE"
		        ;;
		    R*)
		        COMMIT_MESSAGE="Renamed: $FILE"
		        ;;
		    *)
		        COMMIT_MESSAGE="Changed: $FILE"
		        ;;
		esac
	else
		COMMIT_MESSAGE="Update directory"
	fi

	echo "Commit message: $COMMIT_MESSAGE"

	if git commit -m "$COMMIT_MESSAGE"; then
		echo "Local changes committed."
	else
		echo "ERROR: Failed to create commit."
		exit 1
	fi

    echo "Uploading changes to remote repository..."

    if git push origin "$BRANCH"; then
        echo "Repository successfully updated in the remote repository."
    else
        echo "ERROR: Failed to upload changes."
        echo "Possible reasons:"
        echo "- Authentication failed."
        echo "- Remote repository is unavailable."
        echo "- Remote branch has changed."
        exit 1
    fi

    exit 0
fi

# Check committed local changes
if [ "$LOCAL" != "$REMOTE" ]; then
    AHEAD=$(git rev-list --count "origin/$BRANCH..$BRANCH")
    BEHIND=$(git rev-list --count "$BRANCH..origin/$BRANCH")

    if [ "$AHEAD" -gt 0 ] && [ "$BEHIND" -eq 0 ]; then
        echo "Local commits are ahead of the remote repository."
        echo "Uploading changes..."

        if git push origin "$BRANCH"; then
            echo "Repository successfully updated in the remote repository."
        else
            echo "ERROR: Failed to upload changes."
            exit 1
        fi

        exit 0
    fi

    if [ "$AHEAD" -eq 0 ] && [ "$BEHIND" -gt 0 ]; then
        echo "Remote repository contains new changes."
        echo "Downloading changes..."

        if git pull --ff-only origin "$BRANCH"; then
            echo "Repository successfully updated from the remote repository."
        else
            echo "ERROR: Failed to download changes."
            exit 1
        fi

        exit 0
    fi

    echo "ERROR: Local and remote repositories have diverged."
    echo "Local commits: $AHEAD"
    echo "Remote commits: $BEHIND"
    echo "Please resolve the differences manually."
    exit 1
fi

echo "Repository is up to date. No changes available."