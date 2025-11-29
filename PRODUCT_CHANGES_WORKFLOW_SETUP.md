# Product Changes to Sprint Backlog Setup Guide

## Overview
This GitHub Actions workflow automatically detects changes in the `product-definitions/` folder, processes them with the ChatGPT API to extract key information, and creates issues in your GitHub Project's Sprint Backlog.

## What It Does
1. **Detects changes** in `product-definitions/` when code is pushed to main
2. **Processes each changed file** with ChatGPT API to extract:
   - Goal: Clear objective statement
   - Context: Why this matters
   - User Flow: Key interaction pattern
3. **Creates one issue per subject** in your GitHub repository
4. **Adds issues to your GitHub Project** (Sprint Backlog)

## Setup Instructions

### 1. Create GitHub Secrets

Go to your repository settings → Secrets and variables → Actions, and add:

#### `OPENAI_API_KEY`
- Get your API key from [OpenAI API](https://platform.openai.com/api-keys)
- Must have GPT-3.5-turbo or GPT-4 access

#### `PROJECT_ID`
- Get your GitHub Project (v2) ID:
  1. Go to your repository → Projects
  2. Click on your Sprint Backlog project
  3. In the URL, find the project ID: `https://github.com/users/YOUR_USERNAME/projects/PROJECT_ID`
  4. Use that number (e.g., `123`)

### 2. Verify File Structure
The workflow expects markdown files in `product-definitions/` with naming like:
- `01 - product-vision.md`
- `04 - product-description.md`
- `user-flows.md`

The subject is extracted from the filename (removes leading numbers and hyphens).

### 3. Commit and Push
The workflow runs automatically when you:
- Push to the `main` branch
- Change any `.md` files in `product-definitions/`

### 4. Monitor Workflow
Check workflow runs at: `.github/workflows/product-changes-to-issues.yml`

## How It Works

### File Processing
```
product-definitions/04 - product-description.md
                        ↓
                   Extract subject: "product description"
                        ↓
                   Read file content
                        ↓
                   Send to ChatGPT API
                        ↓
              Extract: goal, context, userFlow
                        ↓
                   Create GitHub Issue
                        ↓
                   Add to Project
```

### Issue Format
Each created issue contains:
```markdown
## Overview
**Subject:** [extracted from filename]

## Goal
[1-2 sentence goal statement]

## Context
[2-3 sentences of background]

## User Flow
[2-3 sentences describing key interaction]
```

## Environment Variables (Auto-provided by GitHub Actions)
- `GITHUB_TOKEN`: Automatically provided
- `GITHUB_REPOSITORY`: Automatically provided (format: `owner/repo`)

## Troubleshooting

### Issues Not Created
- Check workflow logs in Actions tab
- Verify `OPENAI_API_KEY` is set and valid
- Ensure files end with `.md`

### Issues Not Added to Project
- Verify `GITHUB_PROJECT_ID` is correct
- Check that your GitHub Project exists
- Project must be a GitHub Project (v2)

### ChatGPT API Errors
- Verify API key has sufficient credits
- Check that model `gpt-3.5-turbo` is available
- Review API rate limits

## Cost Considerations
- Each changed file costs ~$0.001 USD (GPT-3.5-turbo)
- GPT-4 can be used by changing `model` in `process-changes.js`

## Customization

### Change ChatGPT Model
Edit `.github/scripts/process-changes.js`, line ~85:
```javascript
model: 'gpt-4' // or 'gpt-4-turbo-preview'
```

### Adjust Issue Labels
Edit `.github/scripts/process-changes.js`, line ~165:
```javascript
labels: ['custom-label-1', 'custom-label-2']
```

### Filter Specific Files
Edit `.github/workflows/product-changes-to-issues.yml`:
```yaml
paths:
  - 'product-definitions/04*.md' # Only numbered files
```

## First Run
On the first run after setup, the workflow may not detect changes. Push another change to `product-definitions/` to trigger it.
