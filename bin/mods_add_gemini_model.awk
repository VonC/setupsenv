#!/usr/bin/awk -f

# This script adds a 'gemini-2.5-flash' model to the google models section
# right after the 'models:' line, if it's not already present.

BEGIN {
    found_models = 0
    added_gemini_flash = 0
}

/^[[:space:]]*google:/ {
    print
    in_google_section = 1
    next
}

in_google_section && /^[[:space:]]*models:/ {
    print
    found_models = 1
    next
}

/^[[:space:]]*gemini-2.5-flash:/ {
    added_gemini_flash = 1
    print
    next
}

# https://ai.google.dev/gemini-api/docs/models
found_models && !added_gemini_flash && /^[[:space:]]*gemini-[0-9]/ {
    print "      gemini-2.5-flash-preview-05-20:"
    print "        aliases: [\"2.5-flash\"]"
    print "        max-input-chars: 1048576"
    added_gemini_flash = 1
    print
    next
}

{ print }

END {
    if (found_models == 0 || added_gemini_flash == 0) {
        exit 1
    }
}