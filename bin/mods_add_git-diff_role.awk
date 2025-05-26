#!/usr/bin/awk -f

# This script adds a 'git-diff' section to a YAML file
# right after the 'default:' role, if it's not already present.

BEGIN {
    found_default = 0
    added_git_diff = 0
}

/^[[:space:]]*"default":/ {
    print
    found_default = 1
    next
}

/^[[:space:]]*git-diff:/ {
    added_git_diff = 1
    print
    next
}

found_default && !added_git_diff && !/^[[:space:]]*git-diff:/ {
    print "  git-diff:"
    print "    - The next sections are a set of instruction, and then a set of git diff hunks."
    print "    - Your role is to analyzed the git diff hunks based on the instructions given."
    added_git_diff = 1
}

{ print }

END {
    if (found_default == 0 || added_git_diff == 0) {
        exit 1
    }
}