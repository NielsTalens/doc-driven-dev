#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

if [[ -z "${BRANCH_NAME:-}" ]]; then
  echo -e "${RED}✗ BRANCH_NAME not set${NC}"
  exit 1
fi

echo -e "${BLUE}🔍 Analyzing changes from ${BRANCH_NAME} to main...${NC}"

# Get changed files in product-definitions
get_changed_files() {
  git diff --name-only origin/main...HEAD -- product-definitions/ 2>/dev/null | grep -E '\.md$' || true
}

# Get the actual diff for a file
get_file_diff() {
  local filepath=$1
  git diff origin/main...HEAD -- "$filepath" 2>/dev/null || echo ""
}

# Get headings from file
get_headings() {
  local filepath=$1
  if [[ -f "$filepath" ]]; then
    grep -nE '^#{2,6} ' "$filepath" | sed -E 's/^([0-9]+):\s*#+\s*/- /'
  fi
}

# Analyze changes with ChatGPT
analyze_changes() {
  local changed_files=$1
  local file_count=$(echo "$changed_files" | grep -c . || echo 0)

  if [[ $file_count -eq 0 ]]; then
    echo "No product-definitions changes detected"
    return 1
  fi

  local all_changes=""
  local file_summaries=""

  while IFS= read -r file; do
    if [[ -z "$file" ]]; then
      continue
    fi

    local diff=$(get_file_diff "$file")
    if [[ -z "$diff" ]]; then
      continue
    fi

    local headings=$(get_headings "$file")

    file_summaries+="### Changes in \`$file\`\n"
    file_summaries+="$diff\n\n"

    all_changes+="File: $file\n$diff\n\n"
  done <<< "$changed_files"

  if [[ -z "$all_changes" ]]; then
    echo "No substantial changes found"
    return 1
  fi

  echo -e "${BLUE}  → Analyzing all changes with ChatGPT...${NC}" >&2

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
- Availability of tools that are needed to create business value
- Seamless need-to-have secure connectivity
- Balanced user experience & risk mitigation
- Up-and-running on the first day
- Reduction of cognitive load

CRITICAL ANALYSIS RULES:
- Features that ADD friction, delays, or manual steps CONFLICT with our strategy
- Features that INCREASE time-to-productivity CONFLICT with business goals
- Features that require multiple approvals or waiting periods INCREASE cognitive load
- \"Balanced user experience & risk mitigation\" means USABLE security, not bureaucratic barriers

Here are the changes in this pull request:

$all_changes

Task:
Analyze ALL changes together and provide:
- subject (3-7 words): A concise, descriptive title that summarizes the changes
- summary (2-3 sentences): High-level overview of what changed across all files
- goal (1-2 sentences): Primary objectives of these changes from user perspective
- strategicAlignment (2-3 sentences): How these changes align with or conflict with strategic pillars. Be critical - identify conflicts clearly.
- problemsSolved (1-2 sentences): Which problems these changes actually solve
- userImpact (1-2 sentences): How users will benefit or be affected
- recommendation (1-2 sentences): Should this be merged, revised, or rejected based on strategic fit

Return VALID JSON with these fields:
{
  "subject": "...",
  "summary": "...",
  "goal": "...",
  "strategicAlignment": "...",
  "problemsSolved": "...",
  "userImpact": "...",
  "recommendation": "..."
}

CRITICAL: Return ONLY the JSON object. No markdown, no code fences, no extra text."

  local payload=$(jq -n \
    --arg model "gpt-3.5-turbo" \
    --arg prompt "$prompt" \
    '{
      model: $model,
      messages: [{role: "user", content: $prompt}],
      temperature: 0.7,
      max_tokens: 800
    }')

  local response=$(curl -s -X POST https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$payload")

  if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
    local error_msg=$(echo "$response" | jq -r '.error.message')
    echo -e "${RED}✗ ChatGPT API Error: $error_msg${NC}" >&2
    return 1
  fi

  local content=$(echo "$response" | jq -r '.choices[0].message.content')
  content=$(echo "$content" | sed -E 's/^```json\s*//g' | sed -E 's/^```\s*//g' | sed -E 's/```\s*$//g')

  if echo "$content" | jq '.' >/dev/null 2>&1; then
    echo "$content"
  else
    echo -e "${RED}✗ ChatGPT returned invalid JSON${NC}" >&2
    return 1
  fi
}

# Check if PR already exists
check_existing_pr() {
  local response=$(curl -s -X GET \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/pulls?head=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1):${BRANCH_NAME}&base=main&state=open" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json")

  local pr_count=$(echo "$response" | jq '. | length')

  if [[ "$pr_count" -gt 0 ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# Create PR
create_pr() {
  local analysis=$1

  local subject=$(echo "$analysis" | jq -r '.subject')
  local summary=$(echo "$analysis" | jq -r '.summary')
  local goal=$(echo "$analysis" | jq -r '.goal')
  local strategic_alignment=$(echo "$analysis" | jq -r '.strategicAlignment')
  local problems_solved=$(echo "$analysis" | jq -r '.problemsSolved')
  local user_impact=$(echo "$analysis" | jq -r '.userImpact')
  local recommendation=$(echo "$analysis" | jq -r '.recommendation')

  # Determine label based on strategic alignment
  local label="strategy: unclear"
  if echo "$strategic_alignment" | grep -qiE "(CONFLICT|conflicts with|does not align)"; then
    label="strategy: conflicts"
  elif echo "$strategic_alignment" | grep -qiE "(supports|aligns with|contributes to|enables)"; then
    label="strategy: aligned"
  elif echo "$strategic_alignment" | grep -qiE "(partial|mixed)"; then
    label="strategy: partial"
  fi

  local pr_body="## Summary
$summary

## Goal
$goal

## Strategic Alignment
$strategic_alignment

## Problems Solved
$problems_solved

## User Impact
$user_impact

## Recommendation
$recommendation

---
*This analysis was automatically generated based on SuperCli's product strategy and vision.*"

  local title="$subject"

  # Use GitHub CLI to create PR (works with GITHUB_TOKEN)
  echo -e "${BLUE}Creating PR with gh CLI...${NC}" >&2

  local pr_output=$(echo "$pr_body" | gh pr create \
    --title "$title" \
    --body-file - \
    --base main \
    --head "$BRANCH_NAME" 2>&1)

  if [[ $? -eq 0 && "$pr_output" =~ https:// ]]; then
    # Extract PR number from URL
    local pr_number=$(echo "$pr_output" | grep -oE '[0-9]+$')
    echo -e "${GREEN}✓ Created PR #$pr_number: $title${NC}"
    echo -e "${BLUE}  URL: $pr_output${NC}"

    # Add label separately
    add_label "$pr_number" "$label"

    return 0
  else
    echo -e "${RED}✗ Failed to create PR: $pr_output${NC}"
    return 1
  fi
}

# Add label to PR
add_label() {
  local pr_number=$1
  local label=$2

  if [[ -z "$label" || -z "$pr_number" ]]; then
    return 0
  fi

  # Use gh to add label
  gh pr edit "$pr_number" --add-label "$label" 2>/dev/null || echo -e "${YELLOW}  ⚠ Could not add label '$label'${NC}" >&2

  local payload=$(jq -n \
    --arg label "$label" \
    '{
      labels: [$label]
    }')

  curl -s -X POST \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/${pr_number}/labels" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "$payload" >/dev/null

  echo -e "${GREEN}  ✓ Added label '${label}' to PR${NC}"
}

# Main execution
main() {
  # Check if PR already exists
  local pr_exists=$(check_existing_pr)

  if [[ "$pr_exists" == "true" ]]; then
    echo -e "${YELLOW}⚠ PR already exists for ${BRANCH_NAME} → main${NC}"
    echo "Skipping PR creation"
    exit 0
  fi

  local changed_files=$(get_changed_files)

  local analysis=$(analyze_changes "$changed_files")

  if [[ -z "$analysis" ]]; then
    echo -e "${YELLOW}⚠ No changes to analyze${NC}"
    exit 0
  fi

  echo -e "${BLUE}Analysis result:${NC}"
  echo "$analysis" | jq '.'

  create_pr "$analysis"
}

main "$@"
