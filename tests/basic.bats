#!/usr/bin/env bats

# Basic tests for find-missing-casks.sh

# Load test helpers (optional, but good practice for more complex tests)
# load 'test_helper/bats-support/load'
# load 'test_helper/bats-assert/load'

setup() {
  # Ensure the script is executable for testing direct execution if needed
  # Path is relative to project root where 'bats' is run
  chmod +x scripts/find-missing-casks.sh
  # You might need to mock dependencies like brew, curl, jq here for isolated tests
  # For now, we assume they exist or test scenarios where they aren't strictly needed (like -h)
}

@test "Script shows help message with -h and exits successfully" {
  # Run the script with zsh and the -h flag
  # Path is relative to project root where 'bats' is run
  run zsh scripts/find-missing-casks.sh -h
  # Assert that the exit status is 0 (success)
  [ "$status" -eq 0 ]
  # Assert that the output contains the usage string
  [[ "$output" == *"Usage: find-missing-casks.sh"* ]]
}

@test "Script accepts -q option without error" {
  # Run the script with zsh and the -q flag
  # Note: This test assumes brew/curl/jq exist, as the script checks them early.
  # A more robust test would mock these dependencies.
  run zsh scripts/find-missing-casks.sh -q
  # Assert that the exit status is 0 (success)
  # We don't assert output here as it depends heavily on the environment/cache/installed apps
  [ "$status" -eq 0 ]
}

@test "Script accepts -v option without error" {
  # Run the script with zsh and the -v flag
  # Note: This test assumes brew/curl/jq exist.
  run zsh scripts/find-missing-casks.sh -v
  # Assert that the exit status is 0 (success)
  # We don't assert specific verbose output here without mocking.
  [ "$status" -eq 0 ]
}

@test "Script exits with error and shows usage on invalid option" {
  # Run the script with an invalid option (-x)
  run zsh scripts/find-missing-casks.sh -x
  # Assert that the exit status is 1 (error)
  [ "$status" -eq 1 ]
  # Assert that stderr (captured in $output when status is non-zero) contains the error message
  [[ "$output" == *"Invalid Option: -x"* ]]
  # Assert that stderr also contains the usage information
  [[ "$output" == *"Usage: find-missing-casks.sh"* ]]
}

# Add more tests here...
# Example: Test default run (might require mocking brew/curl/jq)
# @test "Script runs with default options without error (requires mocks)" {
#   run zsh ../scripts/find-missing-casks.sh
#   [ "$status" -eq 0 ]
# }

# Example: Test an option
# @test "Script accepts -q option" {
#   run zsh ../scripts/find-missing-casks.sh -q
#   [ "$status" -eq 0 ]
#   # Assert something specific about quiet mode if possible
# }