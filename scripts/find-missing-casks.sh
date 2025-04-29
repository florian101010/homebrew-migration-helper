#!/usr/bin/env zsh
set -euo pipefail

# Dependencies: curl, jq

# --- Configuration ---
APP_DIRS=("/Applications" "$HOME/Applications")
API_URL="https://formulae.brew.sh/api/cask.json"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/find-missing-casks"
CACHE_FILE="$CACHE_DIR/cask_api_data.json"
CACHE_TTL_SECONDS=$((24 * 60 * 60)) # Cache API data for 1 day
# --- End Configuration ---

# Check dependencies
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed. Please install it (e.g., 'brew install jq')." >&2
  exit 1
fi
if ! command -v curl &> /dev/null; then
  echo "Error: curl is required but not installed. Please install it (e.g., 'brew install curl')." >&2
  exit 1
fi

# --- Function to get API data (with caching) ---
get_api_data() {
  mkdir -p "$CACHE_DIR"
  local needs_fetch=false
  if [[ -f "$CACHE_FILE" ]]; then
    if find "$CACHE_DIR" -name "$(basename "$CACHE_FILE")" -type f -mtime +0 | grep -q .; then
        needs_fetch=true
        echo "Cache expired (>1 day old), fetching fresh API data from $API_URL ..." >&2
    else
        echo "Using cached API data (less than 1 day old)..." >&2
    fi
  else
    needs_fetch=true
    echo "Fetching API data from $API_URL ..." >&2
  fi

  if "$needs_fetch"; then
    local temp_file=$(mktemp "$CACHE_DIR/cask_api_data.json.XXXXXX")
    if ! curl --fail --silent --location "$API_URL" -o "$temp_file"; then
        echo "Error: Failed to download API data from $API_URL" >&2
        rm -f "$temp_file"
        if [[ -f "$CACHE_FILE" ]]; then echo "Error occurred during update. Exiting." >&2; fi
        exit 1
    else
        if jq empty "$temp_file" > /dev/null 2>&1; then
            mv "$temp_file" "$CACHE_FILE"
            echo "API data updated successfully." >&2
        else
            echo "Error: Downloaded API data is not valid JSON. Discarding." >&2
            rm -f "$temp_file"
            if [[ ! -f "$CACHE_FILE" ]]; then exit 1; fi
        fi
    fi
  fi
  if [[ ! -f "$CACHE_FILE" ]] || ! jq empty "$CACHE_FILE" > /dev/null 2>&1; then
      echo "Error: Cannot proceed without valid API data cache ($CACHE_FILE)." >&2
      exit 1
  fi
}

# --- Main Script ---

# 0. Get API Data (cached)
get_api_data

# 1. Identify Apps Managed by Homebrew (using brew info --installed)
echo "Gathering information about installed casks..." >&2
typeset -A installed_app_paths # Map: Full App Path -> Cask Token
while IFS=$'\t' read -r cask_token app_path_raw; do
  abs_app_path=""
  if [[ "$app_path_raw" == /* ]]; then
    abs_app_path=$(readlink -f "$app_path_raw" || true)
  else
    if [[ -e "/Applications/$app_path_raw" ]]; then
      abs_app_path=$(readlink -f "/Applications/$app_path_raw" || true)
    elif [[ -e "$HOME/Applications/$app_path_raw" ]]; then
      abs_app_path=$(readlink -f "$HOME/Applications/$app_path_raw" || true)
    elif [[ -e "/usr/local/Caskroom/$cask_token/latest/$app_path_raw" ]]; then
       abs_app_path=$(readlink -f "/usr/local/Caskroom/$cask_token/latest/$app_path_raw" || true)
    fi
  fi
  trimmed_abs_app_path=${abs_app_path## ##}; trimmed_abs_app_path=${trimmed_abs_app_path%% ##}
  if [[ -n "$trimmed_abs_app_path" && "$trimmed_abs_app_path" != "/" ]]; then
      unquoted_path=${trimmed_abs_app_path#\"}; unquoted_path=${unquoted_path%\"}
      if [[ -n "$unquoted_path" ]]; then
          installed_app_paths["$unquoted_path"]="$cask_token"
      fi
  fi
done < <(brew info --json=v2 --installed | jq -r '
  .casks[] | .token as $token | .artifacts[] | (
      if type == "array" and (.[0]? | type == "string" and endswith(".app")) then .[0]
      elif type == "object" and .app? and (.app[0]? | type == "string" and endswith(".app")) then .app[0]
      else empty
      end
  ) as $app_path | select($app_path) | $token + "\t" + $app_path
')

# 2. Create Lookup Map from API Data: App Filename -> "Token\tHomepage"
echo "Processing API data..." >&2
typeset -A api_app_details_map # Map: App Filename -> "Token\tHomepage"
while IFS=$'\t' read -r token app_name homepage; do # Read homepage too
    trimmed_app_name=${app_name## ##}; trimmed_app_name=${trimmed_app_name%% ##}
    unquoted_app_name=${trimmed_app_name#\"}; unquoted_app_name=${unquoted_app_name%\"}
    if [[ -n "$unquoted_app_name" ]]; then
        # Store token and homepage, tab-separated
        api_app_details_map["$unquoted_app_name"]="$token\t$homepage"
    fi
 done < <(jq -r '
    .[] | .token as $token | .homepage as $hp | .artifacts[]? as $artifact |
    # Extract potential app path string using // for fallbacks
    (
        ($artifact | select(type == "array" and (.[0]? | type == "string" and endswith(".app"))) | .[0]) //
        ($artifact | select(type == "object" and .app?) | .app[0]?) //
        null # Fallback value if no structure matches
    ) |
    # Ensure it is a valid string ending in .app
    select(type == "string" and endswith(".app")) |
    # Extract basename
    (split("/") | .[-1]) as $app_filename |
    # Ensure basename is not empty and format output
    select($app_filename) |
    $token + "\t" + $app_filename + "\t" + $hp
' "$CACHE_FILE")
echo "API map created with ${#api_app_details_map} entries." >&2


# 3. Find All Apps on System
echo "Scanning application directories..." >&2
found_app_paths=() # List of full paths to .app files found
for dir in "${APP_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    while IFS= read -r -d $'\0' app; do
      abs_app_path=$(readlink -f "$app" || true)
      trimmed_found_path=${abs_app_path## ##}; trimmed_found_path=${trimmed_found_path%% ##}
      if [[ -n "$trimmed_found_path" && "$trimmed_found_path" != "/" ]]; then
           unquoted_path=${trimmed_found_path#\"}; unquoted_path=${unquoted_path%\"}
           if [[ -n "$unquoted_path" ]]; then
               found_app_paths+=("$unquoted_path")
           fi
      fi
    done < <(find "$dir" -maxdepth 1 -name '*.app' -print0)
  fi
done

# 4. Compare and Report
echo
echo "Apps installable via Homebrew Cask but not currently managed:"
echo "(Verified against Homebrew API data)"
echo "-------------------------------------------------------------"
processed_apps=() # Track processed app basenames (lowercase) to avoid duplicates

for app_path in "${found_app_paths[@]}"; do
    # 4a. Check if this exact path is managed by an *installed* cask
    is_managed="false"
    for key in "${(@k)installed_app_paths}"; do
        unquoted_key=${key#\"}; unquoted_key=${unquoted_key%\"}
        if [[ "$app_path" == "$unquoted_key" ]]; then
            is_managed="true"; break
        fi
    done
    if [[ "$is_managed" == "true" ]]; then continue; fi # Skip if managed

    # 4b. App not managed. Check if its filename exists in the API data map.
    app_filename=$(basename "$app_path") # e.g., LuLu.app

    lc_app_filename=${(L)app_filename}
    if [[ " ${processed_apps[*]} " =~ " ${lc_app_filename} " ]]; then continue; fi
    processed_apps+=("$lc_app_filename")

    # 4c. Look up the app filename in the API map using explicit iteration
    actual_cask_token=""
    homepage=""
    for key in "${(@k)api_app_details_map}"; do
        # Remove potential surrounding quotes from the key before comparing
        unquoted_key=${key#\"}
        unquoted_key=${unquoted_key%\"}

        if [[ "$app_filename" == "$unquoted_key" ]]; then
            # Extract token and homepage from map value using zsh parameter expansion
            local details_string="${api_app_details_map[$key]}"
            local details_array=("${(@s:\t:)details_string}") # Split by tab
            actual_cask_token=${details_array[1]}
            homepage=${details_array[2]}
            break # Found a match
        fi
    done

    # 4d. Report if found in API data
    if [[ -n "$actual_cask_token" ]]; then
        # Corrected printf format string
        printf "  • %-35s (cask: %s | homepage: %s)\n" "${app_filename%.app}" "$actual_cask_token" "$homepage"
    fi
 done

echo "-------------------------------------------------------------"
echo "Note: List shows apps found on your system that are not managed"
echo "      by an installed Homebrew cask, but for which a verified"
echo "      cask exists in the Homebrew repository. Check homepage to confirm."