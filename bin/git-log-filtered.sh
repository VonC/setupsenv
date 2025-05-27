#!/bin/bash

# --- Check arguments early and define mode ---
SILENT_MODE=false
if [ $# -gt 0 ]; then
    SILENT_MODE=true
fi

# Function to conditionally echo messages
echo_info() {
    if [ "$SILENT_MODE" = false ]; then
        echo "$@"
    fi
}

# --- 1. Find the latest annotated tag that is an ancestor of HEAD ---
# This loop iterates through all tags sorted by creation date (newest first).
# It checks if each tag is an annotated tag and if the commit it points to
# is an ancestor of the current HEAD. The first such tag found is the latest.
LAST_ANNOTATED_TAG_COMMIT=$(
  git for-each-ref "refs/tags/*" \
    --sort="-taggerdate" \
    --format="%(refname:short) %(objecttype)" |
  while read -r tag_name tag_type; do
    if [ "$tag_type" = "tag" ]; then # 'tag' object type indicates an annotated tag
      # Resolve the annotated tag object to its associated commit hash
      tag_commit_hash=$(git rev-parse "$tag_name^{commit}")
      # Check if this commit is an ancestor of HEAD
      if git merge-base --is-ancestor "$tag_commit_hash" HEAD; then
        echo "$tag_commit_hash"
        break # Found the latest annotated tag that's an ancestor
      fi
    fi
  done
)

# --- 2. Construct the git log command with specified options ---

# Initialize an array to hold all git log options
GIT_LOG_OPTIONS=()

# Determine the commit range
if [ -z "$LAST_ANNOTATED_TAG_COMMIT" ]; then
    echo_info "No annotated tag found that is an ancestor of HEAD."
    echo_info "Listing all commits in the current history (from HEAD)."
    # If no tag, git log defaults to showing all commits from HEAD, so no specific range needed here.
else
    # Get the human-readable tag name for the echo message
    # We use rev-parse to ensure we're getting the name that points to the found commit
    TAG_NAME_FOR_DISPLAY=$(git describe --tags --abbrev=0 "${LAST_ANNOTATED_TAG_COMMIT}")

    echo_info "Listing commits from '${TAG_NAME_FOR_DISPLAY}' (excluded) to HEAD (included)..."
    GIT_LOG_OPTIONS+=("${LAST_ANNOTATED_TAG_COMMIT}..HEAD")
fi

# Add the option to ignore whitespace changes within hunks
GIT_LOG_OPTIONS+=("-w") # Short for --ignore-all-space, applies to diff output

# Add the exclusion criteria for commit message titles
# We use --grep and --invert-grep along with a regex to match the start of the line (title).
# ^(WIP|Draft|chore) matches titles starting with "WIP", "Draft", or "chore".
# --invert-grep inverts the match, effectively excluding these.
GIT_LOG_OPTIONS+=("--grep=^\(WIP\|Draft\|chore\|doc\)" "--invert-grep")

# --- NEW: Reverse the log order ---
GIT_LOG_OPTIONS+=("--reverse")

# --- Define output format options based on parameters ---
OUTPUT_OPTIONS=()

# Check if any parameters were passed to the script
if [ $# -gt 0 ]; then
    # Parameters exist, show only file names with changes
    OUTPUT_OPTIONS+=("--name-only" "--diff-filter=ACDMRTUXB" "--pretty=format:")
else
    # No parameters, show full patch
    OUTPUT_OPTIONS+=("-p")
fi

# --- 3. Execute the git log command ---
# The "${GIT_LOG_OPTIONS[@]}" expands the array into separate arguments
echo_info git log "${GIT_LOG_OPTIONS[@]}"
if [ "$SILENT_MODE" = false ]; then
  git log "${GIT_LOG_OPTIONS[@]}" --pretty="format:%s"
fi
git log "${GIT_LOG_OPTIONS[@]}" "${OUTPUT_OPTIONS[@]}"