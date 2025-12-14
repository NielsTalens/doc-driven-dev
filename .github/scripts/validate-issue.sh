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

if [[ -z "${ISSUE_NUMBER:-}" ]]; then
  echo -e "${RED}✗ ISSUE_NUMBER not set${NC}"
  exit 1
fi

echo -e "${BLUE}🔍 Validating issue #${ISSUE_NUMBER} against strategy...${NC}"

# Analyze issue with ChatGPT
analyze_issue() {
  local title=$1
  local body=$2

  local prompt="You are a product strategist analyzing whether a feature request or issue aligns with the product strategy and vision.

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
- Features that ADD friction, delays, or manual steps CONFLICT with our strategy (even if they claim security/compliance benefits)
- Features that INCREASE time-to-productivity CONFLICT with business goals
- Features that require multiple approvals or waiting periods INCREASE cognitive load (conflicts with pillar #1)
- Features that slow down developers CONFLICT with Accelerate Development Velocity (pillar #2)
- \"Balanced user experience & risk mitigation\" means USABLE security, not bureaucratic barriers
- If a feature helps risk mitigation but HARMS user experience, it does NOT solve our problem
- Be critical: Does this feature actually reduce friction or just add process?

ISSUE TO ANALYZE:
Title: $title

Body:
$body

Task:
Analyze this issue and provide:
1. alignment (string): One of: \"ALIGNED\", \"PARTIAL\", \"CONFLICTS\", \"UNCLEAR\"
2. strategicPillars (array): Which pillars this supports or conflicts with. Use format: [\"pillar name: SUPPORTS/CONFLICTS\"]
3. businessGoals (array): Which business goals this impacts. Use format: [\"goal: SUPPORTS/CONFLICTS/NEUTRAL\"]
4. problemsSolved (array): Which problems this addresses. Use format: [\"problem: SOLVES/WORSENS/NEUTRAL\"]
5. reasoning (2-3 sentences): Explain your assessment, focusing on whether this adds or removes friction
6. recommendation (1-2 sentences): Should this be pursued, reconsidered, or rejected based on strategic fit

Return VALID JSON with EXACTLY these fields:
{
  \"alignment\": \"ALIGNED|PARTIAL|CONFLICTS|UNCLEAR\",
  \"strategicPillars\": [],
  \"businessGoals\": [],
  \"problemsSolved\": [],
  \"reasoning\": \"...\",
  \"recommendation\": \"...\"
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

  # Check for API errors
  if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
    local error_msg=$(echo "$response" | jq -r '.error.message')
    echo -e "${RED}✗ ChatGPT API Error: $error_msg${NC}" >&2
    return 1
  fi

  # Extract and parse the response
  local content=$(echo "$response" | jq -r '.choices[0].message.content')

  # Strip markdown code blocks if present
  content=$(echo "$content" | sed -E 's/^```json\s*//g' | sed -E 's/^```\s*//g' | sed -E 's/```\s*$//g')

  # Validate it's proper JSON
  if echo "$content" | jq '.' >/dev/null 2>&1; then
    echo "$content"
  else
    echo -e "${RED}✗ ChatGPT returned invalid JSON${NC}" >&2
    echo "$content" >&2
    return 1
  fi
}

# Post comment to issue
post_comment() {
  local issue_number=$1
  local analysis=$2

  # Extract fields from analysis
  local alignment=$(echo "$analysis" | jq -r '.alignment')
  local pillars=$(echo "$analysis" | jq -r '.strategicPillars[]' | sed 's/^/- /' | tr '\n' '\n')
  local goals=$(echo "$analysis" | jq -r '.businessGoals[]' | sed 's/^/- /' | tr '\n' '\n')
  local problems=$(echo "$analysis" | jq -r '.problemsSolved[]' | sed 's/^/- /' | tr '\n' '\n')
  local reasoning=$(echo "$analysis" | jq -r '.reasoning')
  local recommendation=$(echo "$analysis" | jq -r '.recommendation')

  # Choose emoji based on alignment
  local emoji="❓"
  local status_color=""
  case "$alignment" in
    "ALIGNED")
      emoji="✅"
      status_color="**Status: ALIGNED** ✅"
      ;;
    "PARTIAL")
      emoji="⚠️"
      status_color="**Status: PARTIALLY ALIGNED** ⚠️"
      ;;
    "CONFLICTS")
      emoji="❌"
      status_color="**Status: CONFLICTS WITH STRATEGY** ❌"
      ;;
    "UNCLEAR")
      emoji="❓"
      status_color="**Status: UNCLEAR ALIGNMENT** ❓"
      ;;
  esac

  # Build comment body
  local comment_body="## ${emoji} Strategic Alignment Analysis

${status_color}

### Strategic Pillars
${pillars}

### Business Goals Impact
${goals}

### Problems Addressed
${problems}

### Analysis
${reasoning}

### Recommendation
${recommendation}

---
*This analysis was automatically generated based on SuperCli's product strategy and vision.*"

  local payload=$(jq -n \
    --arg body "$comment_body" \
    '{
      body: $body
    }')

  local response=$(curl -s -X POST \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/${issue_number}/comments" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "$payload")

  if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Posted strategic alignment comment to issue #${issue_number}${NC}"
    return 0
  else
    local error_msg=$(echo "$response" | jq -r '.message // .error // "Unknown error"')
    echo -e "${RED}✗ Failed to post comment: $error_msg${NC}" >&2
    return 1
  fi
}

# Main execution
main() {
  echo "Issue Title: $ISSUE_TITLE"
  echo "Issue Number: $ISSUE_NUMBER"

  local analysis=$(analyze_issue "$ISSUE_TITLE" "$ISSUE_BODY")

  if [[ -z "$analysis" ]]; then
    echo -e "${RED}✗ Failed to analyze issue${NC}"
    exit 1
  fi

  echo -e "${BLUE}Analysis result:${NC}"
  echo "$analysis" | jq '.'

  post_comment "$ISSUE_NUMBER" "$analysis"
}

main "$@"
