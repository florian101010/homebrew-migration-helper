#!/usr/bin/env zsh
set -euo pipefail

# Dependencies: curl, jq

# --- Default Configuration ---
DEFAULT_APP_DIRS=("/Applications" "$HOME/Applications")
API_URL="https://formulae.brew.sh/api/cask.json"
DEFAULT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/find-missing-casks"
DEFAULT_CACHE_TTL_SECONDS=$((24 * 60 * 60)) # Cache API data for 1 day
# --- End Default Configuration ---

# --- Script Variables ---
APP_DIRS=() # Initialize empty, will be populated by defaults or args
CACHE_DIR=""
CACHE_FILE=""
CACHE_TTL_SECONDS=0
FORCE_FETCH=false
# --- End Script Variables ---

# --- Usage Function ---
usage() {
  cat << EOF
Usage: $(basename "$0") [-d <dir>] [-c <cache_dir>] [-t <ttl_seconds>] [-f] [-h]

Scans specified directories for manually installed macOS applications (.app)
that have a corresponding verified Homebrew Cask available.

Options:
  -d <dir>         Add a directory to scan for applications. Can be used multiple times.
                   (Default: /Applications and ~/Applications)
  -c <cache_dir>   Specify the directory to store cached API data.
                   (Default: \$XDG_CACHE_HOME/find-missing-casks or ~/.cache/find-missing-casks)
  -t <ttl_seconds> Set the cache Time-To-Live in seconds.
                   (Default: 86400 seconds = 24 hours)
  -f               Force fetch new API data, ignoring existing cache TTL.
  -h               Display this help message and exit.
EOF
  exit 0
}

# --- Argument Parsing ---
while getopts ":hd:c:t:f" opt; do
  case ${opt} in
    h )
      usage
      ;;
    d )
      # Check if directory exists and is readable
      if [[ -d "$OPTARG" && -r "$OPTARG" ]]; then
        APP_DIRS+=("$OPTARG")
      else
        echo "Warning: Directory '$OPTARG' specified with -d does not exist or is not readable. Skipping." >&2
      fi
      ;;
    c )
      CACHE_DIR="$OPTARG"
      ;;
    t )
      if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
        CACHE_TTL_SECONDS=$OPTARG
      else
        echo "Error: Invalid TTL specified with -t. Must be a non-negative integer." >&2
        exit 1
      fi
      ;;
    f )
      FORCE_FETCH=true
      ;;
    \? )
      echo "Invalid Option: -$OPTARG" 1>&2
      usage # Exit after showing usage for invalid option
      ;;
    : )
      echo "Invalid Option: -$OPTARG requires an argument" 1>&2
      usage # Exit after showing usage for missing argument
      ;;
  esac
done
shift $((OPTIND -1))

# --- Apply Defaults if Options Not Provided ---
if [[ ${#APP_DIRS[@]} -eq 0 ]]; then
  APP_DIRS=("${DEFAULT_APP_DIRS[@]}")
fi
if [[ -z "$CACHE_DIR" ]]; then
  CACHE_DIR="$DEFAULT_CACHE_DIR"
fi
# Set cache file path based on final cache dir
CACHE_FILE="$CACHE_DIR/cask_api_data.json"

if [[ $CACHE_TTL_SECONDS -eq 0 ]]; then
  CACHE_TTL_SECONDS=$DEFAULT_CACHE_TTL_SECONDS
fi

# --- Dependency Checks ---
# Check dependencies (moved after arg parsing in case paths change, though unlikely for jq/curl)
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
  local needs_fetch=$FORCE_FETCH # Start with force_fetch flag
  local current_time=$(date +%s)
  local file_mod_time=0

  if [[ "$FORCE_FETCH" == "true" ]]; then
      echo "Forcing API data fetch due to -f flag..." >&2
  fi

  if [[ "$needs_fetch" == "false" ]]; then # Only check cache if not forcing fetch
      if [[ -f "$CACHE_FILE" ]]; then
          file_mod_time=$(stat -f %m "$CACHE_FILE") # macOS stat syntax
          if (( current_time - file_mod_time > CACHE_TTL_SECONDS )); then
              needs_fetch=true
              echo "Cache expired (> $CACHE_TTL_SECONDS seconds old), fetching fresh API data from $API_URL ..." >&2
          else
              echo "Using cached API data (less than $CACHE_TTL_SECONDS seconds old)..." >&2
          fi
      else
          needs_fetch=true
          echo "No cache file found. Fetching API data from $API_URL ..." >&2
      fi
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
  # --- Resolve App Path from 'brew info' ---
  # 'brew info' might give absolute paths, relative paths, or just filenames.
  # We need the canonical, absolute path to reliably check against system scan.
  abs_app_path=""
  # Resolve potential relative paths from brew info output
  if [[ "$app_path_raw" == /* ]]; then
    # Path is already absolute
    abs_app_path=$(readlink -f "$app_path_raw" || true) # Resolve symlinks, ignore errors
  else
    # Path might be relative, check common locations
    if [[ -e "/Applications/$app_path_raw" ]]; then
      abs_app_path=$(readlink -f "/Applications/$app_path_raw" || true)
    elif [[ -e "$HOME/Applications/$app_path_raw" ]]; then
      abs_app_path=$(readlink -f "$HOME/Applications/$app_path_raw" || true)
    elif [[ -e "/usr/local/Caskroom/$cask_token/latest/$app_path_raw" ]]; then
       # Check within the caskroom itself as a fallback (less common case)
       abs_app_path=$(readlink -f "/usr/local/Caskroom/$cask_token/latest/$app_path_raw" || true)
    fi
    # If still not found, abs_app_path remains empty
  fi

  # --- Clean and Store Path ---
  # Clean up the resolved path (trim whitespace, remove potential surrounding quotes)
  trimmed_abs_app_path=${abs_app_path## ##}; trimmed_abs_app_path=${trimmed_abs_app_path%% ##}
  if [[ -n "$trimmed_abs_app_path" && "$trimmed_abs_app_path" != "/" ]]; then # Ensure it's a valid, non-root path
      unquoted_path=${trimmed_abs_app_path#\"}; unquoted_path=${unquoted_path%\"}
      if [[ -n "$unquoted_path" ]]; then
          # Add the canonical path and its managing cask token to the map
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
    # --- JQ Query: Extract App Filename, Token, Homepage from API Data ---
    # Iterate through each cask object in the top-level array
    .[] |
    # Store token and homepage for later use
    .token as $token | .homepage as $hp |
    # Iterate through artifacts, suppressing errors if `artifacts` array is missing
    .artifacts[]? as $artifact |
    # Try to extract the app path string from different known artifact structures:
    (
        # 1. Artifact is an array, first element is a string ending in .app
        #    Example: "artifacts": [["Example.app", {"some": "options"}]]
        ($artifact | select(type == "array" and (.[0]? | type == "string" and endswith(".app"))) | .[0]) //
        # 2. Artifact is an object with an "app" key, whose first element is a string ending in .app
        #    Example: "artifacts": [{"app": ["Example.app"]}]
        ($artifact | select(type == "object" and .app?) | .app[0]?) //
        # 3. Fallback if neither structure matches (results in null)
        null
    ) |
    # Filter out nulls and ensure the result is a string ending in .app
    select(type == "string" and endswith(".app")) |
    # Extract the filename (basename) from the potentially full path
    (split("/") | .[-1]) as $app_filename |
    # Ensure the extracted filename is not empty (handles edge cases)
    select($app_filename) |
    # Output: token, app_filename, homepage (tab-separated) for shell processing
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