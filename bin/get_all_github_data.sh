#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/echos"

# Define jq alias using cygpath to handle Windows paths
JQ_WIN_PATH="${PRGS}/jqs/current/jq-win64.exe"
JQ_UNIX_PATH=$(cygpath -u "$JQ_WIN_PATH")

# Function alias for jq
jq() {
    "$JQ_UNIX_PATH" "$@"
}

# Check if jq exists and is executable
if [[ ! -x "$JQ_UNIX_PATH" ]]; then
    error "jq executable not found at: '${JQ_UNIX_PATH}'ERROR_BASH_FAILED"
    fatal "Please make sure %PRGS%/jqs/current/jq-win64.exe exists and is executable.ERROR_BASH_FAILED" 10
fi

# --- Check environment variables ---
MISSING_VARS=false

# All echos must be on stderr
ECHOS_STDERR=1

# Function to check mandatory variables
check_mandatory_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    local var_desc="$2"
    
    if [[ -z "$var_value" ]]; then
        error "Missing mandatory environment variable $var_name ($var_desc)"
        MISSING_VARS=true
    else
        ok "Using $var_name: $var_value ($var_desc)"
        if [[ -z "$ECHOS_STDERR" ]]; then
            echo "Using $var_name: $var_value ($var_desc)" >&2
        fi
    fi
}

# Function to display optional variables
show_optional_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    local default_value="$2"
    local var_desc="$3"
    
    if [[ -z "$var_value" ]]; then
        warning "Optional $var_name not set, using default: $default_value ($var_desc)"
    else
        ok "Using $var_name: $var_value ($var_desc)"
    fi
}

# Check mandatory variables
check_mandatory_var "OWNER" "GitHub repository owner/organization"
check_mandatory_var "REPO" "GitHub repository name"

# Display optional variables with defaults
ENDPOINT="${ENDPOINT:-tags}"
show_optional_var "ENDPOINT" "tags" "API endpoint (tags or releases)"

YOUR_PAT="${YOUR_PAT:-}"
if [[ -z "$YOUR_PAT" ]]; then
    warning "Optional YOUR_PAT not set, using unauthenticated requests (lower rate limits)"
else
    ok "Using YOUR_PAT: [REDACTED] (GitHub Personal Access Token)"
fi

PER_PAGE="${PER_PAGE:-100}"
show_optional_var "PER_PAGE" "100" "Items per page (max 100)"

PATTERN="${PATTERN:-}"
if [[ -z "$PATTERN" ]]; then
    warning "Optional PATTERN not set, will fetch all items"
else
    ok "Using PATTERN: '${PATTERN}' (Only return items starting with this pattern)"
fi

# Exit if mandatory variables are missing
if [[ "$MISSING_VARS" = true ]]; then
    fatal "Exiting due to missing mandatory environment variablesERROR_BASH_FAILED" 11
fi

# --- Configuration ---
# Initial URL with configurable per_page
CURRENT_URL="https://api.github.com/repos/$OWNER/$REPO/$ENDPOINT?per_page=$PER_PAGE"

# Array to store all collected JSON objects (strings)
ALL_PAGES_JSON=()

# Array to store accumulated matches across pages
ALL_MATCHES=()

task "Must fetch $ENDPOINT for $OWNER/$REPO..."
[[ -n "$PATTERN" ]] && task "Must filter for pattern: $PATTERN"

while [ -n "$CURRENT_URL" ]; do
    info "  Fetching: $CURRENT_URL"

    # Build curl command with headers
    CURL_OPTS=(-s -i -H "Accept: application/vnd.github.v3+json")
    
    # Add authorization header only if PAT is provided
    [[ -n "$YOUR_PAT" ]] && CURL_OPTS+=(-H "Authorization: Bearer $YOUR_PAT")
    
    # Make the curl request
    response=$(curl "${CURL_OPTS[@]}" "$CURRENT_URL")

    # --- Extract Body and Headers ---
    # More robust way to extract JSON body - find the first '['
    body=$(echo "$response" | awk '/^\[/{p=1} p')
    link_header=$(echo "$response" | grep -i '^Link:' | head -n 1)

    # Validate JSON response
    if ! echo "$body" | jq -e . >/dev/null; then
        info "$body"
        fatal "Failed to fetch valid JSON from '${CURRENT_URL}'ERROR_BASH_FAILED" 12
    fi

    # If pattern is set, check for matches in this page
    if [[ -n "$PATTERN" ]]; then
        # Extract field name based on endpoint (name for tags, tag_name for releases)
        FIELD_NAME=$([ "$ENDPOINT" = "tags" ] && echo "name" || echo "tag_name")
        
        # Get all items and matching items
        all_items=$(echo "${body}" | jq -r --arg field "$FIELD_NAME" '.[] | .[$field]')
        matches=$(echo "$body" | jq -r --arg pat "$PATTERN" --arg field "$FIELD_NAME" \
            '.[] | .[$field] | select(startswith($pat))')
        
        if [[ -n "$matches" ]]; then
            # Add current matches to accumulated matches
            while IFS= read -r match; do
                ALL_MATCHES+=("$match")
            done <<< "$matches"
            
            # Check if there are non-matching items after the last match
            last_match=$(echo "$matches" | tail -n1)
            last_item=$(echo "$all_items" | tail -n1)
            
            if [[ "$last_match" != "$last_item" ]]; then
                # Non-matching items exist after matches - print all accumulated and exit
                info "Found matches followed by non-matching items - printing all matches"
                printf "%s\n" "${ALL_MATCHES[@]}"
                exit 0
            else
                # All matches are at end of page, continue to next page
                info "All matches at end of page, checking next page..."
            fi
        elif [[ ${#ALL_MATCHES[@]} -gt 0 ]]; then
            # We have accumulated matches but this page has none
            # Print accumulated matches and exit
            info "No more matches on current page, printing accumulated matches"
            printf "%s\n" "${ALL_MATCHES[@]}"
            exit 0
        fi
    else
        # No pattern, collect page for later processing
        ALL_PAGES_JSON+=("$body")
    fi

    # --- Find the "next" URL ---
    NEXT_URL=$(echo "$link_header" | grep -oP '(?<=<)[^>]+(?=>; rel="next")' | head -n 1)
    CURRENT_URL="$NEXT_URL" # Set for the next iteration
done

# If we reach here with pattern and accumulated matches, print them
if [[ -n "$PATTERN" && ${#ALL_MATCHES[@]} -gt 0 ]]; then
    info "Reached end of pages, printing all accumulated matches"
    printf "%s\n" "${ALL_MATCHES[@]}"
    exit 0
elif [[ -n "$PATTERN" ]]; then
    ok "No matches found for pattern: $PATTERN"
    exit 0
fi

# --- Combine All JSON Pages ---
if [ ${#ALL_PAGES_JSON[@]} -gt 0 ]; then
    # Output combined results to stdout
    printf "%s\n" "${ALL_PAGES_JSON[@]}" | jq -s 'flatten'
else
    echo "[]" # Output an empty JSON array if no data was fetched
fi

ok "All Done."