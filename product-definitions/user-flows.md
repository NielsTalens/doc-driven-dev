# First-day onboarding — SuperCli

## Summary
A new engineer receives their device, launches SuperCli and is guided through everything needed to start contributing. SuperCli automates tool and language installation, applies company and team configuration, and verifies a working development environment — the engineer is up and running before lunch.

## Actor
- New engineer (first day)

## Preconditions
- Device powered and connected to the internet
- Company identity (SSO) account provisioned
- Basic network access to company artifact/repo services

## Primary Flow (happy path)

1. Unbox and power on device
	- Engineer connects to the network and opens a terminal.
	- Command: `supercli start` (or `supercli onboard`).

2. Welcome & context
	- SuperCli displays a short welcome message, the estimated time (e.g., ~60–90 minutes), and an overview of steps.
	- Option to run a quick tour or proceed directly.

3. Authenticate
	- SuperCli opens the browser for SSO login or performs an in-terminal device-code flow.
	- On success, SuperCli verifies role and team membership.

4. Team selection & profile fetch
	- If the user belongs to multiple teams, SuperCli prompts to select the active team.
	- SuperCli fetches the team's policy profile: required languages, tooling, default versions, approved extensions, and secrets/access patterns.

5. System checks & permissions
	- SuperCli runs a non-destructive system audit (disk, package manager availability, shell, PATH) and prompts for elevation when needed.
	- Shows clear explanation before applying changes.

6. Toolchain installation
	- Installs / configures required runtimes and managers per team profile (example: Node + nvm, Python + pyenv, Go versions).
	- Installs essential developer tools (git, docker, kubectl, terraform, language servers) with sensible defaults.
	- Uses safe, idempotent installers; re-runs are safe.

7. Apply company and team configuration
	- Sets global git config, generates or imports SSH keys, and optionally connects to company secrets manager or credential helper.
	- Installs editor (e.g., VS Code) settings and recommended extensions, linter/formatter configuration, and pre-commit hooks.

8. Import team workspace & dotfiles
	- Offers to import team dotfiles, workspace templates, and workspace-level devcontainer / remote configuration.
	- Clones a sample repo or a team starter project and applies local settings.

9. Verify environment
	- Runs a verification suite: build, lint, and a smoke test of the sample app.
	- Presents a concise checklist with green/red indicators and clear remediation steps when something fails.

10. Learning & short-cuts
	- Provides an interactive cheat-sheet: common `supercli` commands, how to open support channels, and links to onboarding docs.
	- Option to schedule a short pairing session with a teammate.

11. Completion
	- Confirms final state and tells the engineer they are ready to contribute — ideally before lunch.

## Alternate flows

- Network offline: SuperCli offers an offline mode that applies local configs and caches; it queues network installs until connectivity is restored.
- Access denied: If SSO or team access is blocked, SuperCli explains how to request access and provides a temporary sandbox mode with safe, limited permissions.
- Custom tool choices: Engineers can opt-out of specific installs or choose alternate versions; SuperCli records these choices into a personal profile for future runs.

## Postconditions
- Developer machine has required runtimes, tools, and editor configured.
- SSH key and git config are set; developer can clone and run team projects.
- A verification checklist shows pass/fail states for essential items.

## Success criteria (example metrics)
- Time-to-first-run: engineer runs the sample app within the target window (e.g., 90 minutes).
- Checklist: 90–100% of automated checks pass on the first run.
- Developer sentiment: new-hire reports confidence and reduced onboarding friction.

## UI copy examples (short)
- Welcome: "Welcome to SuperCli — we’ll get your dev environment ready in ~60–90 minutes."
- Progress step: "Installing Node 18.x (nvm) — this may take a few minutes."
- Success: "All set — you can now run `npm start` in the cloned starter repo. Need help? Join #dev-onboarding."

## Notes for implementers
- Keep all changes idempotent and reversible.
- Prefer safe defaults, but surface choices clearly.
- Log steps and provide easy re-run and rollback commands: `supercli status`, `supercli repair`, `supercli reset`.

---

This user flow is focused on minimizing cognitive load and making the first-day experience predictable, fast and trustable so engineers can start delivering value quickly.
