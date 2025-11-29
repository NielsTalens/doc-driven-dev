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
    echo "Using commit range: $BEFORE_SHA..$AFTER_SHA"
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

# Read file content
get_file_content() {
  if [[ -f "$1" ]]; then
    cat "$1"
  fi
}

# Call ChatGPT API
process_with_chatgpt() {
  local filename=$1
  local content=$2
  local subject=$(extract_subject "$filename")

  echo -e "${BLUE}  → Extracting essence for: $subject${NC}"

  local prompt="You are a product manager analyzing product documentation changes.

File: $filename
Subject: $subject

Content:
$content

Extract the following information in JSON format:
1. goal: A clear, concise goal statement (1 sentences)
2. context: Background and why this matters (2-3 sentences)
3. userFlow: A key part of the user flow related to this subject (2-3 sentences)

Return ONLY valid JSON, no markdown formatting."

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
  echo "$content" | jq '.' 2>/dev/null || echo "$content"
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

  local query="
    mutation {
      addProjectV2ItemById(input: {
        projectId: \"$GITHUB_PROJECT_ID\"
        contentId: \"$issue_number\"
      }) {
        item {
          id
        }
      }
    }
  "

  local payload=$(jq -n --arg query "$query" '{query: $query}')

  local response=$(curl -s -X POST https://api.github.com/graphql \
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

  echo "Found $file_count changed file(s)"

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

    local content=$(get_file_content "$file")
    if [[ -z "$content" ]]; then
      echo -e "${RED}  ✗ Could not read file${NC}"
      continue
    fi

    # Process with ChatGPT
    local extracted=$(process_with_chatgpt "$file" "$content")

    if [[ -z "$extracted" ]]; then
      echo -e "${RED}  ✗ Failed to extract content${NC}"
      continue
    fi

    local goal=$(echo "$extracted" | jq -r '.goal // "No goal extracted"')
    local context=$(echo "$extracted" | jq -r '.context // "No context extracted"')
    local user_flow=$(echo "$extracted" | jq -r '.userFlow // "No user flow extracted"')
    local subject=$(extract_subject "$file")

    # Create issue
    if create_issue "$subject" "$goal" "$context" "$user_flow"; then
      # Extract issue number and add to project
      local last_issue=$(tail -1 /tmp/created_issues.jsonl | jq -r '.issueNumber')
      add_to_project "$last_issue"
    fi
  done <<< "$changed_files"

  local created_count=$(wc -l < /tmp/created_issues.jsonl 2>/dev/null || echo 0)
  echo -e "\n${GREEN}✅ Created $created_count issue(s)${NC}"
}

main "$@"
