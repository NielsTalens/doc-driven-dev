#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Validate environment variables
if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo -e "${RED}✗ OPENAI_API_KEY not set${NC}"
  exit 1
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo -e "${RED}✗ GITHUB_TOKEN not set${NC}"
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  echo -e "${RED}✗ GITHUB_REPOSITORY not set${NC}"
  exit 1
fi

# Get changed files in product-definitions
get_changed_files() {
  # If the workflow provided a BEFORE/AFTER SHA range (push event), use that
  if [[ -n "${BEFORE_SHA:-}" && -n "${AFTER_SHA:-}" && "${BEFORE_SHA}" != "0000000000000000000000000000000000000000" ]]; then
    echo "Using commit range: $BEFORE_SHA..$AFTER_SHA" >&2
    git diff --name-only "$BEFORE_SHA" "$AFTER_SHA" -- product-definitions/ 2>/dev/null | grep -E '\.md$' || true
    return
  fi

  # Try to get diff from last commit (best-effort when run locally or without event payload)
  if git rev-parse --verify HEAD >/dev/null 2>&1 && git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
    git diff --name-only HEAD~1 HEAD -- product-definitions/ 2>/dev/null | grep -E '\.md$' || true
    return
  fi

  # Fallback for initial push or detached env - list all markdown files
  git ls-files product-definitions/ | grep -E '\.md$' || true
}

# Extract subject from filename (e.g., "04 - product-description.md" -> "product description")
extract_subject() {
  local filename=$1
  local basename=$(basename "$filename" .md)
  # Remove leading numbers and hyphens, replace remaining hyphens with spaces
  echo "$basename" | sed -E 's/^[0-9]+\s*-\s*//' | sed 's/-/ /g'
}

# Get the actual diff (changed lines) for a file
get_file_diff() {
  local filepath=$1

  # Use the same SHA range as get_changed_files
  if [[ -n "${BEFORE_SHA:-}" && -n "${AFTER_SHA:-}" && "${BEFORE_SHA}" != "0000000000000000000000000000000000000000" ]]; then
    git diff "$BEFORE_SHA" "$AFTER_SHA" -- "$filepath" 2>/dev/null || echo ""
  elif git rev-parse --verify HEAD >/dev/null 2>&1 && git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
    git diff HEAD~1 HEAD -- "$filepath" 2>/dev/null || echo ""
  else
    # Fallback: show entire file as new content
    if [[ -f "$filepath" ]]; then
      echo "--- /dev/null"
      echo "+++ $filepath"
      cat "$filepath" | sed 's/^/+/'
    fi
  fi
}

# Read file content (keep for context if needed)
get_file_content() {
  if [[ -f "$1" ]]; then
    cat "$1"
  fi
}

# Call ChatGPT API
process_with_chatgpt() {
  local filename=$1
  local diff=$2
  local subject=$(extract_subject "$filename")

  echo -e "${BLUE}  → Extracting essence for: $subject${NC}" >&2

  local prompt="You are a product manager analyzing product documentation changes.

File: $filename
Subject: $subject

Here are the CHANGES made to this file (git diff format):
$diff

Based ONLY on the lines that were added or modified (marked with + in the diff), per logical subject, extract the following information and return it as VALID JSON with exactly these three fields:
- goal: A clear, concise goal statement (1 sentence)
- context: Background and why this matters (2-3 sentences)
- userFlow: A key part of the user flow related to this subject (2-3 sentences)

Focus only on what was CHANGED, not the entire document.

CRITICAL: Return ONLY a single JSON object. No markdown, no code blocks, no explanations. Just the raw JSON object starting with { and ending with }."

  local payload=$(jq -n \
    --arg model "gpt-3.5-turbo" \
    --arg prompt "$prompt" \
    '{
      model: $model,
      messages: [{role: "user", content: $prompt}],
      temperature: 0.7,
      max_tokens: 500
    }')

  local response=$(curl -s -X POST https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$payload")

  # Check for API errors
  if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
    local error_msg=$(echo "$response" | jq -r '.error.message')
    echo -e "${RED}  ✗ ChatGPT API Error: $error_msg${NC}"
    return 1
  fi

  # Extract and parse the response
  local content=$(echo "$response" | jq -r '.choices[0].message.content')

  # DEBUG: Output raw response
  echo "=== RAW ChatGPT RESPONSE ===" >&2
  echo "$content" >&2
  echo "=== END RAW RESPONSE ===" >&2

  # Strip markdown code blocks if present (```json ... ```)
  content=$(echo "$content" | sed -E 's/^```json\s*//g' | sed -E 's/^```\s*//g' | sed -E 's/```\s*$//g')

  # DEBUG: Output after stripping
  echo "=== AFTER STRIPPING ===" >&2
  echo "$content" >&2
  echo "=== END AFTER STRIPPING ===" >&2

  # Validate it's proper JSON
  if echo "$content" | jq '.' >/dev/null 2>&1; then
    echo "$content"
  else
    echo -e "${RED}  ✗ ChatGPT returned invalid JSON${NC}" >&2
    echo "$content" >&2
    return 1
  fi
}

# Create GitHub issue
create_issue() {
  local subject=$1
  local goal=$2
  local context=$3
  local user_flow=$4

  local issue_body="## Overview
**Subject:** $subject

## Goal
$goal

## Context
$context

## User Flow
$user_flow

---
*Auto-generated from product-definitions changes*"

  local payload=$(jq -n \
    --arg title "[Product Update] $subject" \
    --arg body "$issue_body" \
    '{
      title: $title,
      body: $body,
      labels: ["product-definition", "auto-generated"]
    }')

  local owner_repo=$(echo "$GITHUB_REPOSITORY" | tr '/' '\n')
  local owner=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
  local repo=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)

  local response=$(curl -s -X POST "https://api.github.com/repos/$GITHUB_REPOSITORY/issues" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "$payload")

  # Check for API errors
  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    local issue_number=$(echo "$response" | jq -r '.number')
    local issue_url=$(echo "$response" | jq -r '.html_url')
    echo -e "${GREEN}✓ Created issue #$issue_number: $subject${NC}"

    # Save issue info for project assignment
    echo "{\"issueNumber\": $issue_number, \"issueUrl\": \"$issue_url\"}" >> /tmp/created_issues.jsonl

    return 0
  else
    local error_msg=$(echo "$response" | jq -r '.message // .error // "Unknown error"')
    echo -e "${RED}✗ Failed to create issue: $error_msg${NC}"
    return 1
  fi
}

# Add issue to project using GraphQL
add_to_project() {
  local issue_number=$1

  if [[ -z "${GITHUB_PROJECT_ID:-}" ]]; then
    echo "  ⚠ GITHUB_PROJECT_ID not set, skipping project assignment"
    return 0
  fi

  # First, get the issue's node ID from the issue number
  local owner=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
  local repo=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)

  local query="query {
    repository(owner: \"$owner\", name: \"$repo\") {
      issue(number: $issue_number) {
        id
      }
    }
  }"

  local payload=$(jq -n --arg query "$query" '{query: $query}')

  local response=$(curl -s -X POST https://api.github.com/graphql \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -d "$payload")

  local issue_node_id=$(echo "$response" | jq -r '.data.repository.issue.id // empty')

  if [[ -z "$issue_node_id" ]]; then
    echo "  ⚠ Could not get issue node ID for #$issue_number"
    return 0
  fi

  # Now add the issue to the project using the node ID
  query="
    mutation {
      addProjectV2ItemById(input: {
        projectId: \"$GITHUB_PROJECT_ID\"
        contentId: \"$issue_node_id\"
      }) {
        item {
          id
        }
      }
    }
  "

  payload=$(jq -n --arg query "$query" '{query: $query}')

  response=$(curl -s -X POST https://api.github.com/graphql \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -d "$payload")

  if echo "$response" | jq -e '.errors' >/dev/null 2>&1; then
    local error_msg=$(echo "$response" | jq -r '.errors[0].message')
    echo "  ⚠ Warning adding to project: $error_msg"
  else
    echo -e "${GREEN}  ✓ Added issue #$issue_number to project${NC}"
  fi
}

# Main execution
main() {
  echo -e "${BLUE}🔍 Detecting changes in product-definitions...${NC}"

  local changed_files=$(get_changed_files)
  local file_count=$(echo "$changed_files" | grep -c . || echo 0)

  echo "Found $file_count changed file(s): $changed_files"

  if [[ $file_count -eq 0 ]]; then
    echo "No changes detected in product-definitions"
    exit 0
  fi

  # Clear previous runs
  > /tmp/created_issues.jsonl

  while IFS= read -r file; do
    if [[ -z "$file" ]]; then
      continue
    fi

    echo -e "\n${BLUE}📄 Processing: $file${NC}"

    # Get the diff (what changed) instead of full file
    local diff=$(get_file_diff "$file")
    if [[ -z "$diff" ]]; then
      echo -e "${RED}  ✗ Could not get diff for file${NC}"
      continue
    fi

    # Process with ChatGPT
    local extracted=$(process_with_chatgpt "$file" "$diff")

    if [[ -z "$extracted" ]]; then
      echo -e "${RED}  ✗ Failed to extract content${NC}"
      continue
    fi

    # DEBUG: Show what we're parsing
    echo "=== EXTRACTED JSON ===" >&2
    echo "$extracted" >&2
    echo "=== END EXTRACTED JSON ===" >&2

    local goal=$(echo "$extracted" | jq -r '.goal // "No goal extracted"')
    local context=$(echo "$extracted" | jq -r '.context // "No context extracted"')
    local user_flow=$(echo "$extracted" | jq -r '.userFlow // "No user flow extracted"')
    local subject=$(extract_subject "$file")

    # Create issue
    create_issue "$subject" "$goal" "$context" "$user_flow"
  done <<< "$changed_files"

  local created_count=$(wc -l < /tmp/created_issues.jsonl 2>/dev/null || echo 0)
  echo -e "\n${GREEN}✅ Created $created_count issue(s)${NC}"
}

main "$@"
