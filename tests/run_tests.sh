#!/usr/bin/env zsh
set -euo pipefail

# Basic Test Runner for find-missing-casks.sh

# --- Test Setup ---
SCRIPT_DIR=$(dirname "$0:A")
PROJECT_ROOT="$SCRIPT_DIR/.."
SCRIPT_TO_TEST="$PROJECT_ROOT/scripts/find-missing-casks.sh"
TEST_TMP_DIR=$(mktemp -d -t find-missing-casks-tests.XXXXXX)

# Keep track of test results
tests_run=0
tests_failed=0

# --- Helper Functions ---

# Function to clean up test environment
cleanup() {
  echo "Cleaning up test directory: $TEST_TMP_DIR"
  rm -rf "$TEST_TMP_DIR"
  # TODO: Unmock commands if necessary
}
trap cleanup EXIT INT TERM

# Basic assertion function
assert_success() {
  local test_name="$1"
  local exit_code="$2"
  ((tests_run++))
  if [[ $exit_code -ne 0 ]]; then
    echo "❌ FAIL: $test_name (Exited with code $exit_code)"
    ((tests_failed++))
  else
    echo "✅ PASS: $test_name"
  fi
}

assert_fail() {
    local test_name="$1"
    local exit_code="$2"
    ((tests_run++))
    if [[ $exit_code -eq 0 ]]; then
        echo "❌ FAIL: $test_name (Expected non-zero exit code, got 0)"
        ((tests_failed++))
    else
        echo "✅ PASS: $test_name (Exited with code $exit_code)"
    fi
}

assert_output_contains() {
    local test_name="$1"
    local output="$2"
    local expected_substring="$3"
    ((tests_run++))
    if [[ "$output" != *"$expected_substring"* ]]; then
        echo "❌ FAIL: $test_name"
        echo "   Expected output to contain: '$expected_substring'"
        echo "   Actual output:"
        echo "$output" | sed 's/^/   | /' # Indent actual output
        ((tests_failed++))
    else
        echo "✅ PASS: $test_name"
    fi
}


# --- Mocking (Placeholder) ---
# TODO: Implement robust mocking for brew, curl, jq
# This might involve creating wrapper scripts in TEST_TMP_DIR/bin
# and adding that directory to the PATH for the duration of the test.
# Example:
# export PATH="$TEST_TMP_DIR/bin:$PATH"
# mkdir -p "$TEST_TMP_DIR/bin"
# echo '#!/bin/sh\necho "mock brew output"' > "$TEST_TMP_DIR/bin/brew"
# chmod +x "$TEST_TMP_DIR/bin/brew"


# --- Test Cases ---

echo "--- Running Tests ---"

# Test 1: Help flag exits successfully and shows usage
echo "\n[Test 1: Help Flag]"
echo "Running: $SCRIPT_TO_TEST -h"
# Temporarily disable exit on error to capture the exit code reliably
set +e
output_help=$("$SCRIPT_TO_TEST" -h 2>&1)
exit_code_help=$?
echo "Exit code captured: $exit_code_help"
assert_success "Script exits successfully with -h" $exit_code_help
set -e # Re-enable exit on error *after* the exit code assertion
# Only check output if the exit code was 0, as expected by usage()
if [[ $exit_code_help -eq 0 ]]; then
    assert_output_contains "Help output contains 'Usage:'" "$output_help" "Usage:"
    assert_output_contains "Help output contains '-d <dir>'" "$output_help" "-d <dir>"
else
    echo "Skipping output checks for Test 1 due to non-zero exit code."
fi


# Test 2: Invalid option exits with non-zero code
echo "\n[Test 2: Invalid Option]"
echo "Running: $SCRIPT_TO_TEST -z"
# Temporarily disable exit on error to capture the expected non-zero exit code
set +e
output_invalid=$("$SCRIPT_TO_TEST" -z 2>&1)
exit_code_invalid=$?
set -e # Re-enable exit on error
echo "Exit code captured: $exit_code_invalid"
assert_fail "Script exits with non-zero code for invalid option -z" $exit_code_invalid
# Only check output if the exit code was non-zero, as expected
if [[ $exit_code_invalid -ne 0 ]]; then
    assert_output_contains "Invalid option output contains 'Invalid Option:'" "$output_invalid" "Invalid Option:"
else
    echo "Skipping output check for Test 2 due to unexpected exit code 0."
fi


# --- More Test Cases (Placeholders - Require Mocking) ---

# echo "\n[Test 3: Basic run with mock data]"
# Setup mock brew, curl, jq, fake apps
# output=$( "$SCRIPT_TO_TEST" -d "$TEST_TMP_DIR/FakeApps" -c "$TEST_TMP_DIR/cache" )
# exit_code=$?
# assert_success "Basic run exits successfully" $exit_code
# assert_output_contains "Finds specific test app" "$output" "TestApp"


# --- Test Summary ---
echo "\n--- Test Summary ---"
if [[ $tests_failed -eq 0 ]]; then
  echo "✅ All $tests_run tests passed!"
  exit 0
else
  echo "❌ $tests_failed out of $tests_run tests failed."
  exit 1
fi