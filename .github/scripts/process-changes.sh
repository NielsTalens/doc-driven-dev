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

# Utility: list headings in a file (for subject context)
get_headings() {
  local filepath=$1
  if [[ -f "$filepath" ]]; then
    # Output headings as bullet list (levels 2-6)
    grep -nE '^#{2,6} ' "$filepath" | sed -E 's/^([0-9]+):\s*#+\s*/- /'
  fi
}

# Call ChatGPT API for a single diff hunk
process_with_chatgpt() {
  local filename=$1
  local diff=$2
  local headings=$3

  echo -e "${BLUE}  → Extracting essence for change in $filename${NC}" >&2

  local prompt="You are a product manager analyzing product documentation changes. You are very user experience focused and always think from the perspective of end users.

STRATEGIC CONTEXT:
SuperCli's mission is to empower development teams to build exceptional, user-centric applications faster by eliminating workflow friction.

Core Strategic Pillars:
1. Reduce Cognitive Load - Automate workflows, consolidate tools, let developers focus on meaningful problems
2. Accelerate Development Velocity - Minimize setup/boilerplate time through intelligent automation
3. Improve Developer Experience (DevEx) - Design natural, feedback-rich interactions with power-user capabilities
4. Enable User-Centric Development - Remove obstacles to building applications users love

Business Goals:
- Reduce time-to-productivity (4 hours for new employees, 1 hour for laptop switch)
- Improve DevEx rating by 10%
- Decline of workarounds by 75%

Problems we are solving:
- Availability of tools that are needed to create business value.
- Seamless need-to-have secure connectivity.
- Balanced user experience & risk mitigation.
- Up-and-running on the first day.
- Reduction of cognitive load.

CRITICAL ANALYSIS RULES:
- Features that ADD friction, delays, or manual steps CONFLICT with our strategy (even if they claim security/compliance benefits)
- Features that INCREASE time-to-productivity CONFLICT with business goals
- Features that require multiple approvals or waiting periods INCREASE cognitive load (conflicts with pillar #1)
- Features that slow down developers CONFLICT with Accelerate Development Velocity (pillar #2)
- \"Balanced user experience & risk mitigation\" means USABLE security, not bureaucratic barriers
- If a feature helps risk mitigation but HARMS user experience, it does NOT solve our problem
- Be critical: Does this feature actually reduce friction or just add process?

File: $filename

Headings in file (for context):
$headings

Here is ONE change hunk for this file (unified diff):
$diff

Task:
- Based ONLY on added/modified lines (those starting with '+'), extract:
  - goal (1 sentence): The primary objective or feature being described from the user's perspective. Describe the main purpose.
  - context (2-3 sentences): Why this matters and background. what problem does it solve. What steps are needed to solve the problems
  - userFlow: How users interact with or benefit from this. Describe the user interaction regarding this subject.
  - strategicAlignment (1-2 sentences): Critically analyze if this change TRULY supports our strategic pillars and business goals. Consider whether it adds or removes friction. If it conflicts with our strategy (e.g., adds delays, complexity, or bureaucracy), state: \"CONFLICTS with strategic pillars - adds friction/delays that harm DevEx and productivity.\" If genuinely aligned, explain how. If unclear, state: \"No clear strategic alignment or business goals identified.\"
  - problemsToSolve (1-2 sentences): Critically assess which problems this ACTUALLY solves. Consider the user impact and the listed Problems we are solving. If it adds barriers that harm the user experience side of 'balanced UX & risk mitigation', it does NOT solve our problem. If it conflicts, state: \"DOES NOY SOLEVE LISTED PROBLEMS - increases friction and cognitive load.\" If genuinely helpful, explain which problem and how.

- Create a concise, meaningful subject (3-5 words) that summarizes what changed based on the goal and context. Do NOT use generic headings from the file structure; invent a specific subject that describes THIS change uniquely.

Return VALID JSON with EXACTLY these fields:
  { \"subject\": \"<specific, descriptive subject based on goal and context>\", \"goal\": \"...\", \"context\": \"...\", \"userFlow\": \"...\", \"strategicAlignment\": \"...\", \"problemsToSolve\": \"...\" }

CRITICAL: Return ONLY the JSON object. No markdown, no code fences, no extra text."

  local payload=$(jq -n \
    --arg model "gpt-3.5-turbo" \
    --arg prompt "$prompt" \
    '{
      model: $model,
      messages: [{role: "user", content: $prompt}],
      temperature: 0.7,
      max_tokens: 600
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

  # Strip markdown code blocks if present (```json ... ```)
  content=$(echo "$content" | sed -E 's/^```json\s*//g' | sed -E 's/^```\s*//g' | sed -E 's/```\s*$//g')

  # Validate it's proper JSON
  if echo "$content" | jq '.' >/dev/null 2>&1; then
    echo "$content"
  else
    echo -e "${RED}  ✗ ChatGPT returned invalid JSON${NC}" >&2
    echo "$content" >&2
    return 1
  fi
}

# Determine alignment label from strategic alignment text
get_alignment_label() {
  local strategic_alignment=$1

  # Check for conflict indicators
  if echo "$strategic_alignment" | grep -qiE "(CONFLICT|conflicts with|does not align|contradicts|opposes)"; then
    echo "strategy: conflicts"
    return 0
  fi

  # Check for unclear/no alignment
  if echo "$strategic_alignment" | grep -qiE "(No clear strategic alignment|unclear|cannot determine|not identified)"; then
    echo "strategy: unclear"
    return 0
  fi

  # Check for partial alignment
  if echo "$strategic_alignment" | grep -qiE "(partial|mixed|some alignment|partially)"; then
    echo "strategy: partial"
    return 0
  fi

  # Check for positive alignment indicators
  if echo "$strategic_alignment" | grep -qiE "(supports|aligns with|contributes to|enables|accelerates|reduces)"; then
    echo "strategy: aligned"
    return 0
  fi

  # Default to unclear if we can't determine
  echo "strategy: unclear"
}

# Add alignment label to issue
add_alignment_label() {
  local issue_number=$1
  local label=$2

  if [[ -z "$label" ]]; then
    echo -e "${YELLOW}⚠ No label to add${NC}" >&2
    return 0
  fi

  local payload=$(jq -n \
    --arg label "$label" \
    '{
      labels: [$label]
    }')

  echo -e "${BLUE}  → Adding label '${label}' to issue #${issue_number}${NC}" >&2

  local response=$(curl -s -X POST \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/${issue_number}/labels" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "$payload")

  # Debug output
  echo "=== LABEL RESPONSE ===" >&2
  echo "$response" >&2
  echo "=== END LABEL RESPONSE ===" >&2

  if echo "$response" | jq -e '.[0].id' >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ Added label '${label}' to issue #${issue_number}${NC}"
    return 0
  else
    local error_msg=$(echo "$response" | jq -r '.message // .error // "Unknown error"')
    echo -e "${RED}  ✗ Failed to add label: $error_msg${NC}" >&2
    echo -e "${YELLOW}  ⚠ Continuing without label...${NC}" >&2
    return 0  # Don't fail the whole workflow just for labeling
  fi
}

# Create GitHub issue
create_issue() {
  local subject=$1
  local goal=$2
  local context=$3
  local user_flow=$4
  local strategic_alignment=$5
  local problems_to_solve=$6

  local issue_body="## Goal
$goal

## Context
$context

## User Flow
$user_flow

## Strategic Alignment
$strategic_alignment

## Problems to Solve
$problems_to_solve"


  local payload=$(jq -n \
    --arg title "$subject" \
    --arg body "$issue_body" \
    '{
      title: $title,
      body: $body,
      labels: ["product-definition"]
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

    # Return issue number for labeling
    echo "$issue_number"
    return 0
  else
    local error_msg=$(echo "$response" | jq -r '.message // .error // "Unknown error"')
    echo -e "${RED}✗ Failed to create issue: $error_msg${NC}"
    return 1
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

    # DEBUG: Show the diff content
    echo "=== DIFF CONTENT ===" >&2
    echo "$diff" >&2
    echo "=== END DIFF ===" >&2

    # Build headings list for subject context
    local headings=$(get_headings "$file")

    # Split diff into hunks and process each hunk to create one issue per change
    local hunks_file
    hunks_file=$(mktemp)
    echo "$diff" | awk 'BEGIN{first=1} /^@@ /{ if(first){ first=0 } else { print "----HUNK----" } } { print }' > "$hunks_file"

    local current_hunk=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "----HUNK----" ]]; then
        if [[ -n "$current_hunk" ]] && echo "$current_hunk" | grep -qE '^[+][^+]'; then
          local extracted=$(process_with_chatgpt "$file" "$current_hunk" "$headings")
          if [[ -z "$extracted" ]]; then
            echo -e "${RED}  ✗ Failed to extract content for hunk${NC}"
          else
            echo "=== EXTRACTED JSON ===" >&2
            echo "$extracted" >&2
            echo "=== END EXTRACTED JSON ===" >&2
            local subject_from_ai=$(echo "$extracted" | jq -r '.subject // empty')
            local final_subject=${subject_from_ai:-"$(basename "$file" .md)"}
            local goal=$(echo "$extracted" | jq -r '.goal // "No goal extracted"')
            local context=$(echo "$extracted" | jq -r '.context // "No context extracted"')
            local user_flow=$(echo "$extracted" | jq -r '.userFlow // "No user flow extracted"')
            local strategic_alignment=$(echo "$extracted" | jq -r '.strategicAlignment // "No strategic alignment information available."')
            local problems_to_solve=$(echo "$extracted" | jq -r '.problemsToSolve // "No problems to solve information available."')
            local issue_number=$(create_issue "$final_subject" "$goal" "$context" "$user_flow" "$strategic_alignment" "$problems_to_solve")
            if [[ -n "$issue_number" ]]; then
              local alignment_label=$(get_alignment_label "$strategic_alignment")
              add_alignment_label "$issue_number" "$alignment_label"
            fi
          fi
        fi
        current_hunk=""
      else
        current_hunk+="$line"$'\n'
      fi
    done < "$hunks_file"

    # Process last hunk if any
    if [[ -n "$current_hunk" ]] && echo "$current_hunk" | grep -qE '^[+][^+]'; then
      local extracted=$(process_with_chatgpt "$file" "$current_hunk" "$headings")
      if [[ -z "$extracted" ]]; then
        echo -e "${RED}  ✗ Failed to extract content for hunk${NC}"
      else
        echo "=== EXTRACTED JSON ===" >&2
        echo "$extracted" >&2
        echo "=== END EXTRACTED JSON ===" >&2
        local subject_from_ai=$(echo "$extracted" | jq -r '.subject // empty')
        local final_subject=${subject_from_ai:-"$(basename "$file" .md)"}
        local goal=$(echo "$extracted" | jq -r '.goal // "No goal extracted"')
        local context=$(echo "$extracted" | jq -r '.context // "No context extracted"')
        local user_flow=$(echo "$extracted" | jq -r '.userFlow // "No user flow extracted"')
        local strategic_alignment=$(echo "$extracted" | jq -r '.strategicAlignment // "No strategic alignment information available."')
        local problems_to_solve=$(echo "$extracted" | jq -r '.problemsToSolve // "No problems to solve information available."')
        local issue_number=$(create_issue "$final_subject" "$goal" "$context" "$user_flow" "$strategic_alignment" "$problems_to_solve")
        if [[ -n "$issue_number" ]]; then
          local alignment_label=$(get_alignment_label "$strategic_alignment")
          add_alignment_label "$issue_number" "$alignment_label"
        fi
      fi
    fi

    rm -f "$hunks_file"
  done <<< "$changed_files"

  local created_count=$(wc -l < /tmp/created_issues.jsonl 2>/dev/null || echo 0)
  echo -e "\n${GREEN}✅ Created $created_count issue(s)${NC}"
}

main "$@"
