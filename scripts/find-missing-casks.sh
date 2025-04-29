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
VERBOSE=false
QUIET=false
INTERACTIVE=false
# --- End Script Variables ---

# --- Colors ---
# Check if stdout is a terminal and supports colors
if [[ -t 1 ]]; then
    COLOR_RESET="\e[0m"
    COLOR_BOLD="\e[1m"
    COLOR_DIM="\e[2m"
    COLOR_APP_NAME="\e[1;36m" # Bold Cyan
    COLOR_CASK_TOKEN="\e[0;33m" # Yellow
    COLOR_HOMEPAGE="\e[2;37m" # Dim White/Gray
    COLOR_COMMAND="\e[0;32m" # Green
    COLOR_HEADER="\e[1;37m" # Bold White
    COLOR_PROMPT="\e[1;37m" # Bold White for prompts
    COLOR_ERROR="\e[1;31m" # Bold Red
else
    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_DIM=""
    COLOR_APP_NAME=""
    COLOR_CASK_TOKEN=""
    COLOR_HOMEPAGE=""
    COLOR_COMMAND=""
    COLOR_HEADER=""
    COLOR_PROMPT=""
    COLOR_ERROR=""
fi
# --- End Colors ---

# --- Logging Function ---
# Prints informational messages to stderr, suppressed if QUIET is true
log_info() {
    if [[ "$QUIET" == "false" ]]; then
            # Add \n back to add blank line after status messages
            echo -e "$@\n" >&2
        fi
    }
# --- End Logging Function ---

# --- Usage Function ---
usage() {
  local exit_code=${1:-0} # Default exit code 0 if no argument provided
  # Print usage message to stderr if exiting due to an error
  local output_stream=1 # stdout
  if [[ $exit_code -ne 0 ]]; then
    output_stream=2 # stderr
  fi

  cat >&$output_stream << EOF
Usage: $(basename "$0") [-d <dir>] [-c <cache_dir>] [-t <ttl_seconds>] [-f] [-v] [-q] [-i] [-h]

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
  -v               Verbose mode: Print more detailed execution information and skipped apps.
  -q               Quiet mode: Suppress informational messages (stderr), only show final list or errors.
  -i               Interactive mode: Prompt before suggesting installation for each found app.
  -h               Display this help message and exit successfully.
EOF
  exit "$exit_code"
}

# --- Argument Parsing ---
# Note: -v, -q, -i are simple flags; others require arguments (indicated by ':')
while getopts ":hd:c:t:fvqi" opt; do
  case ${opt} in
    h )
      usage
      ;;
    d )
      # Check if directory exists and is readable
      if [[ -d "$OPTARG" && -r "$OPTARG" ]]; then
        # Resolve to absolute path to handle relative inputs consistently
        abs_dir=$(cd "$OPTARG"; pwd)
        APP_DIRS+=("$abs_dir")
      else
        echo "${COLOR_ERROR}Warning:${COLOR_RESET} Directory '$OPTARG' specified with -d does not exist or is not readable. Skipping." >&2
      fi
      ;;
    c )
      CACHE_DIR="$OPTARG"
      ;;
    t )
      if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
        CACHE_TTL_SECONDS=$OPTARG
      else
        echo "${COLOR_ERROR}Error:${COLOR_RESET} Invalid TTL specified with -t. Must be a non-negative integer." >&2
        exit 1
      fi
      ;;
    f )
      FORCE_FETCH=true
      ;;
    v )
      VERBOSE=true
      ;;
    q )
      QUIET=true
      ;;
    i )
      INTERACTIVE=true
      ;;
    \? )
      echo "${COLOR_ERROR}Invalid Option:${COLOR_RESET} -$OPTARG" 1>&2
      usage 1 # Exit with code 1 for invalid option
      ;;
    : )
      echo "${COLOR_ERROR}Invalid Option:${COLOR_RESET} -$OPTARG requires an argument" 1>&2
      usage 1 # Exit with code 1 for missing argument
      ;;
  esac
done
shift $((OPTIND -1))

# --- Apply Defaults if Options Not Provided ---
if [[ ${#APP_DIRS[@]} -eq 0 ]]; then
  APP_DIRS=("${DEFAULT_APP_DIRS[@]}")
fi
# Ensure unique directories
typeset -U APP_DIRS # Zsh specific: Keep only unique elements

if [[ -z "$CACHE_DIR" ]]; then
  CACHE_DIR="$DEFAULT_CACHE_DIR"
fi
# Set cache file path based on final cache dir
CACHE_FILE="$CACHE_DIR/cask_api_data.json"

if [[ $CACHE_TTL_SECONDS -eq 0 ]]; then
  CACHE_TTL_SECONDS=$DEFAULT_CACHE_TTL_SECONDS
fi

# Quiet mode implies non-interactive
if [[ "$QUIET" == "true" ]]; then
    INTERACTIVE=false
    VERBOSE=false # Quiet overrides verbose
fi

# --- Dependency Checks ---
# Check dependencies (moved after arg parsing in case paths change, though unlikely for jq/curl)
if ! command -v jq &> /dev/null; then
  echo "${COLOR_ERROR}Error:${COLOR_RESET} jq is required but not installed. Please install it (e.g., 'brew install jq')." >&2
  exit 1
fi
if ! command -v curl &> /dev/null; then
  echo "${COLOR_ERROR}Error:${COLOR_RESET} curl is required but not installed. Please install it (e.g., 'brew install curl')." >&2
  exit 1
fi
if ! command -v brew &> /dev/null; then
    echo "${COLOR_ERROR}Error:${COLOR_RESET} brew command not found. Please ensure Homebrew is installed correctly." >&2
    exit 1
fi


# --- Function to get API data (with caching) ---
get_api_data() {
  mkdir -p "$CACHE_DIR"
  local needs_fetch=$FORCE_FETCH # Start with force_fetch flag
  local current_time=$(date +%s)
  local file_mod_time=0

  if [[ "$FORCE_FETCH" == "true" ]]; then
      log_info "⏳ ${COLOR_DIM}Forcing API data fetch (-f)...${COLOR_RESET}"
  fi

  if [[ "$needs_fetch" == "false" ]]; then # Only check cache if not forcing fetch
      if [[ -f "$CACHE_FILE" ]]; then
          file_mod_time=$(stat -f %m "$CACHE_FILE") # macOS stat syntax
          if (( current_time - file_mod_time > CACHE_TTL_SECONDS )); then
              needs_fetch=true
              log_info "${COLOR_DIM}Cache expired (> $CACHE_TTL_SECONDS seconds old), fetching fresh API data from $API_URL ...${COLOR_RESET}"
          else
              log_info "💾 ${COLOR_DIM}Using cached API data (less than $CACHE_TTL_SECONDS seconds old)...${COLOR_RESET}"
          fi
      else
          needs_fetch=true
          log_info "☁️ ${COLOR_DIM}No cache file found. Fetching API data from $API_URL ...${COLOR_RESET}"
      fi
  fi

  if "$needs_fetch"; then
    # Ensure fetch message is printed if needed, avoiding duplication if cache expired/missing
    if [[ "$FORCE_FETCH" == "false" ]]; then # Only print if not already forced
        log_info "☁️ ${COLOR_DIM}Fetching API data from $API_URL ...${COLOR_RESET}"
    fi
    local temp_file=$(mktemp "$CACHE_DIR/cask_api_data.json.XXXXXX")
    # Use -f (--fail) to make curl exit non-zero on server errors (4xx, 5xx)
    if ! curl --fail --silent --location "$API_URL" -o "$temp_file"; then
        # Error messages should always go to stderr, regardless of quiet mode
        echo "${COLOR_ERROR}Error:${COLOR_RESET} Failed to download API data from $API_URL" >&2
        rm -f "$temp_file"
        # Provide context if falling back is impossible
        if [[ ! -f "$CACHE_FILE" ]]; then echo "${COLOR_ERROR}Error:${COLOR_RESET} No existing cache file to fall back on." >&2; fi
        exit 1
    else
        if jq empty "$temp_file" > /dev/null 2>&1; then
            mv "$temp_file" "$CACHE_FILE"
            log_info "${COLOR_DIM}API data updated successfully.${COLOR_RESET}"
        else
            echo "${COLOR_ERROR}Error:${COLOR_RESET} Downloaded API data is not valid JSON. Discarding." >&2
            rm -f "$temp_file"
            if [[ ! -f "$CACHE_FILE" ]]; then
                 echo "${COLOR_ERROR}Error:${COLOR_RESET} No existing cache file to fall back on after invalid download." >&2
                 exit 1
            else
                 log_info "${COLOR_DIM}Warning: Failed to update cache with invalid JSON. Using previous cache.${COLOR_RESET}"
            fi
        fi
    fi
  fi
  # Final check for valid cache file remains critical
  if [[ ! -f "$CACHE_FILE" ]] || ! jq empty "$CACHE_FILE" > /dev/null 2>&1; then
      echo "${COLOR_ERROR}Error:${COLOR_RESET} Cannot proceed without valid API data cache ($CACHE_FILE)." >&2
      exit 1
  fi
}

# --- Main Script ---

# 0. Get API Data (cached)
get_api_data

# 1. Identify Apps Managed by Homebrew (using brew info --installed)
log_info "📦 ${COLOR_DIM}Gathering information about installed casks...${COLOR_RESET}"
typeset -A installed_app_paths # Map: Full App Path -> Cask Token
local installed_cask_count=0 # Counter for verbose output

# Temporarily disable exit on error for the brew/jq pipeline
set +e
brew_info_output=$(brew info --json=v2 --installed)
brew_info_exit_code=$?
set -e

if [[ $brew_info_exit_code -ne 0 ]]; then
    echo "${COLOR_ERROR}Error:${COLOR_RESET} 'brew info --json=v2 --installed' failed with exit code $brew_info_exit_code." >&2
    # Optionally print brew output if available? Might be large.
    exit 1
fi

# Process the output
# Use process substitution <(...) to avoid subshell issues with the associative array
# Use noglob prefix to prevent zsh from interpreting jq query characters
# Use more defensive jq query with '?' to handle potentially missing/null fields
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
    elif [[ -n "$cask_token" && -e "/usr/local/Caskroom/$cask_token/latest/$app_path_raw" ]]; then # Check cask_token is not empty
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
      if [[ -n "$unquoted_path" && -n "$cask_token" ]]; then # Ensure both path and token are valid
          # Add the canonical path and its managing cask token to the map
          installed_app_paths["$unquoted_path"]="$cask_token"
          ((installed_cask_count++))
          if [[ "$VERBOSE" == "true" ]]; then
              log_info "  ${COLOR_DIM}- Found installed cask '$cask_token' managing path: $unquoted_path${COLOR_RESET}"
          fi
      fi
  fi
# Sanitize brew output using perl to remove problematic control characters before piping to jq
done < <(printf "%s" "$brew_info_output" | perl -pe 's/[\x00-\x08\x0B\x0C\x0E-\x1F]//g' | jq -r '
  .casks[]? # Iterate safely over casks
  | .token? as $token # Safely get token
  | select($token) # Ensure token is not null
  | .artifacts[]? as $artifact # Safely iterate artifacts
  | ( # Try to extract app path
      if type == "array" and (.[0]? | type == "string" and endswith(".app")) then .[0]
      elif type == "object" and .app? and (.app[0]? | type == "string" and endswith(".app")) then .app[0]
      else empty
      end
    ) as $app_path # Assign result (potential null)
  | select($app_path) # Ensure app_path is not null/empty
  | $token + "\t" + $app_path # Output token and path
')


if [[ "$VERBOSE" == "true" ]]; then
    log_info "${COLOR_DIM}Identified $installed_cask_count managed application paths from installed casks.${COLOR_RESET}"
fi

# 2. Create Lookup Map from API Data: App Filename -> "Token\tHomepage"
log_info "⚙️  ${COLOR_DIM}Processing API data into lookup map...${COLOR_RESET}"
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
log_info "🗺️  ${COLOR_DIM}API map created with ${#api_app_details_map} entries.${COLOR_RESET}"


# 3. Find All Apps on System
log_info "🔍 ${COLOR_DIM}Scanning application directories: ${(j:, :)APP_DIRS}${COLOR_RESET}" # Show which dirs are scanned
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
report_lines=()     # Array to store formatted output lines for sorting
processed_apps=()   # Track processed app basenames (lowercase) to avoid duplicates
# Counters for verbose summary
skipped_managed_count=0
skipped_processed_count=0
skipped_no_cask_count=0
apps_to_install_interactively=() # Store details for interactive mode

for app_path in "${found_app_paths[@]}"; do
    # 4a. Check if this exact path is managed by an *installed* cask
    is_managed="false"
    for key in "${(@k)installed_app_paths}"; do
        unquoted_key=${key#\"}; unquoted_key=${unquoted_key%\"}
        if [[ "$app_path" == "$unquoted_key" ]]; then
            is_managed="true"; break
            fi
        done
        if [[ "$is_managed" == "true" ]]; then
            ((skipped_managed_count++)) # Keep original ((...)) here as it didn't seem to cause issues
            if [[ "$VERBOSE" == "true" ]]; then
            log_info "  ${COLOR_DIM}- Skipping (already managed): $app_path (by cask: ${installed_app_paths[$app_path]})${COLOR_RESET}"
        fi
        continue # Skip if managed
    fi

    # 4b. App not managed. Check if its filename exists in the API data map.
    app_filename=$(basename "$app_path") # e.g., LuLu.app

    lc_app_filename=${(L)app_filename}
    if [[ " ${processed_apps[*]} " =~ " ${lc_app_filename} " ]]; then
        skipped_processed_count=$((skipped_processed_count + 1)) # Use $((...)) arithmetic expansion
        if [[ "$VERBOSE" == "true" ]]; then
             log_info "  ${COLOR_DIM}- Skipping (duplicate basename): $app_filename from path $app_path${COLOR_RESET}"
        fi
        continue # Already processed this app basename
    fi
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
            # Safely access array elements, providing empty defaults if they don't exist
            actual_cask_token=${details_array[1]:-} # Default to empty if index 1 is unset
            homepage=${details_array[2]:-}          # Default to empty if index 2 is unset
            # Ensure we actually got a token before breaking
            if [[ -n "$actual_cask_token" ]]; then
                break # Found a match with a token
            fi
        fi
    done

    # 4d. Report if found in API data
    if [[ -n "$actual_cask_token" ]]; then
        # Format the output line with colors, emojis, and command, store in array
        local app_name_display="${app_filename%.app}" # Remove .app suffix
        local line=""
        # App Name Header
        line+="${COLOR_BOLD}${COLOR_APP_NAME}${app_name_display}${COLOR_RESET}\n"
        # Details (indented, consistent spacing)
        line+="  📦 ${COLOR_DIM}Cask:${COLOR_RESET}      ${COLOR_CASK_TOKEN}${actual_cask_token}${COLOR_RESET}\n"
        line+="  🔗 ${COLOR_DIM}Homepage:${COLOR_RESET}  ${COLOR_HOMEPAGE}${homepage}${COLOR_RESET}\n"
        line+="  ▶️  ${COLOR_DIM}Install:${COLOR_RESET}   ${COLOR_COMMAND}brew install --cask ${actual_cask_token}${COLOR_RESET}\n\n" # Add TWO newlines here for separation
        report_lines+=("$line")
        # Store details for interactive mode if needed
        if [[ "$INTERACTIVE" == "true" ]]; then
            apps_to_install_interactively+=("${app_name_display}\t${actual_cask_token}")
        fi
    else
         # App filename not found in API map
         skipped_no_cask_count=$((skipped_no_cask_count + 1)) # Use $((...)) arithmetic expansion
         if [[ "$VERBOSE" == "true" ]]; then
             log_info "  ${COLOR_DIM}- Skipping (no verified cask found): $app_filename from path $app_path${COLOR_RESET}"
         fi
    fi
 done

# --- Print Sorted Report ---
echo # Add a newline before the report

if [[ ${#report_lines[@]} -eq 0 ]]; then
    # Only print this if not in quiet mode
    if [[ "$QUIET" == "false" ]]; then
        echo "${COLOR_HEADER}✅ No manually installed applications found with corresponding Homebrew Casks.${COLOR_RESET}"
    fi
else
    # Print header unless in quiet mode
    if [[ "$QUIET" == "false" ]]; then
        echo "\n${COLOR_HEADER}🔎 Found Manually Installed Apps with Available Homebrew Casks:${COLOR_RESET}"
        echo "${COLOR_DIM}   (Apps listed below are not currently managed by Homebrew Cask)${COLOR_RESET}" # Simplified subtitle
        echo "${COLOR_HEADER}===================================================================${COLOR_RESET}"
    fi

    # Sort the report lines alphabetically (case-insensitive using 'on')
    sorted_report_lines=("${(on)report_lines}")

    # Print each sorted line (which now includes its own trailing newlines for separation)
    for line in "${sorted_report_lines[@]}"; do
        print -n -- "$line" # Use print -n to print exactly what's in $line without adding an extra newline
    done

    # Print footer unless in quiet mode
    if [[ "$QUIET" == "false" ]]; then
        echo "${COLOR_HEADER}===================================================================${COLOR_RESET}"
        # Add blank line before Next Steps
        echo "\n💡 ${COLOR_BOLD}Next Steps:${COLOR_RESET}"
        echo # Add blank line *after* the header
        echo "   1. ${COLOR_BOLD}Verify:${COLOR_RESET} Check the 🔗 Homepage for each app to ensure the cask is correct."
        echo "   2. ${COLOR_BOLD}Decide:${COLOR_RESET} Choose whether to migrate the app to Homebrew management."
        echo "   3. ${COLOR_BOLD}Migrate (Optional):${COLOR_RESET} If migrating, ${COLOR_BOLD}uninstall the manual version first,${COLOR_RESET}"
        echo "      then run the ▶️  Install command provided (e.g., ${COLOR_COMMAND}brew install --cask ...${COLOR_RESET})."
        echo "   (Use the ${COLOR_BOLD}-i${COLOR_RESET} flag for interactive installation prompts)."
    fi
fi

# Add Summary Count (always printed to stderr unless quiet)
echo "" # Add explicit blank line before Summary header (stderr)
log_info "${COLOR_HEADER}📊 Summary${COLOR_RESET}" # log_info will add another blank line after this
log_info "${COLOR_BOLD}   Found ${#report_lines[@]} potential cask migration(s).${COLOR_RESET}"
if [[ "$VERBOSE" == "true" ]]; then
    # Ensure counts are printed even if 0, for clarity in verbose mode, add extra indent
    log_info "${COLOR_DIM}     - Skipped (Managed):   ${skipped_managed_count:-0}"
    log_info "${COLOR_DIM}     - Skipped (Duplicate): ${skipped_processed_count:-0}"
    log_info "${COLOR_DIM}     - Skipped (No Cask):   ${skipped_no_cask_count:-0}${COLOR_RESET}"
fi

# --- Interactive Installation ---
if [[ "$INTERACTIVE" == "true" && ${#apps_to_install_interactively[@]} -gt 0 ]]; then
    echo "\n${COLOR_HEADER}--- Interactive Installation ---${COLOR_RESET}"
    for app_details in "${apps_to_install_interactively[@]}"; do
        local app_name cask_token
        # Split the stored details string by tab
        app_name="${app_details%%$'\t'*}"
        cask_token="${app_details#*$'\t'}"

        # Ask user for confirmation
        # Use vared for interactive input in Zsh
        local reply
        print -n "${COLOR_PROMPT}Install cask '${COLOR_CASK_TOKEN}${cask_token}${COLOR_PROMPT}' for '${COLOR_APP_NAME}${app_name}${COLOR_PROMPT}'? [y/N]: ${COLOR_RESET}"
        vared -c reply
        # Default to No if user just presses Enter
        reply=${reply:-n}

        if [[ "$reply" =~ ^[Yy]$ ]]; then
            echo "${COLOR_DIM}Running: brew install --cask $cask_token${COLOR_RESET}"
            # Execute the command - consider potential errors
            if brew install --cask "$cask_token"; then
                echo "${COLOR_COMMAND}Successfully installed $cask_token.${COLOR_RESET}"
            else
                echo "${COLOR_ERROR}Error installing $cask_token. Please check brew output.${COLOR_RESET}"
            fi
        else
            echo "${COLOR_DIM}Skipping installation for $app_name.${COLOR_RESET}"
        fi
    done
    echo "\n${COLOR_HEADER}--- Interactive Installation Complete ---${COLOR_RESET}"
fi

exit 0 # Explicitly exit with success code if script completes