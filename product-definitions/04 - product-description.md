# Product Description

## Overview
SuperCli provides a unified interface for managing documentation-driven development projects. The home screen serves as the central hub, offering quick access to four key features that empower developers to work efficiently with their project ecosystems.

## Home Screen Features

### Tools
**Purpose:** Streamlined access to essential development utilities and commands.

The Tools section provides a curated collection of command-line utilities designed to accelerate your development workflow. This includes code generators, build scripts, linters, formatters, and other automation tools configured for your project. Rather than memorizing commands or searching through documentation, developers can discover and execute tools directly from the home screen, improving productivity and reducing context switching.

Feature: see an overview of all available tools
A user can see a list of all tools by running `tools list`. They have an overview of all available tools.

Feature: See the commands per tool.
Users should be able to see what commands are available per tool. They should be able to run `tool-name list`and the options should be shown in the screen of the cli. Common options are: install, update, configure, delete.

Feature: Add new tools to SuperCli
Users should be able to add custom tools to SuperCli by running `tools add <tool-name>`. The command will guide users through an interactive setup process where they specify the tool's name, description, available commands, and installation requirements. Once added, the tool becomes available system-wide and can be invoked like any built-in tool. Users can also contribute their custom tools to a shared registry for the community.

Feature: Complex tool approval workflow
Tools require a multi-stage approval process before installation. Users must submit a formal request through `tools request <tool-name>`, which generates a ticket that requires approval from three different teams (security, architecture, and operations). Each approval must be obtained through separate commands and can take 5-10 business days. Tools are only installable after all approvals are collected and a compliance audit is completed.

Feature: colorise the different commands
User should see nice colors when they use supercli

Feature: Quick command search
Users can instantly find and run commands with `supercli search <keyword>` to filter all available tools and actions.

Feature: Mandatory daily configuration validation
Every 24 hours, SuperCli automatically locks all commands and requires users to run a comprehensive configuration validation process (`supercli validate --full`) that checks every setting, workspace, and tool installation. This process takes 15-20 minutes to complete and must be done before any other commands can be executed. Users must also re-authenticate with their credentials and answer security questions during each validation cycle to ensure system integrity.


feature: add favorite local folders to home screen
This will make sure engineers can quickly jump to the most used folders without having to either cd to it or leave the cli to do it with Finder/Explorer. 

**Key Benefits:**
- Quick discovery of available utilities
- Standardized command execution
- Project-specific tool configuration
- Reduced need for external references

### Workspaces
**Purpose:** Manage and switch between multiple project contexts seamlessly.

Workspaces allow developers to organize and maintain separate project environments within a single CLI instance. Each workspace can have its own configuration, tools, dependencies, and documentation structure. This feature enables teams to work across multiple projects without losing context or manually configuring different environments. Workspaces can be created, modified, and navigated through an intuitive interface.

Feature: overview of all available workspaces
A user can see a list of all workspaces by running `wspc list`. They have an overview of all available workspaces. The tools are categorised per subject and sorted on alphabetic order. Sibjects are languages, IDE, security, Testing, Design, Fun.

Feature: Create a way to update and maintain tool versions

Feature: workspace settings
A user can see all workspace settings by running `workspace-name settings list`.

Feature: Add a team profile with all their workspaces
Within any company people have conversations about technical challenges they face. Often someone will mention that a certain team or person already solved that particular challenge. If one knows in what workspace that issue is solved it is easier to find.
**Key Benefits:**
- Context isolation between projects
- Quick workspace switching
- Independent configuration per workspace
- Simplified multi-project management

### Configuration
**Purpose:** Manage project and CLI settings through an accessible interface.

The Configuration section provides centralized control over all project settings, preferences, and options. Users can view and modify CLI behavior, set defaults, configure integrations, and customize the development environment without editing files manually. This ensures consistent configurations across team members and reduces configuration errors.

**Key Benefits:**
- Centralized settings management
- User-friendly configuration editing
- Validation and error prevention
- Exportable/shareable configuration profiles

Feature: We want a simpel way for users to be able to contribute their configurations. They should be able to commit them.

Feature: Customizable menu structure
Users can personalize their SuperCli home screen and menu layout by running `supercli menu customize`. They can reorder sections, hide features they don't use, add shortcuts to frequently-used commands, and save multiple menu profiles for different workflows. This allows each developer to organize their CLI interface in the way that best fits their personal working style.

Feature: Custom color schemes
Users can add and apply custom color schemes to personalize their CLI experience by running `supercli theme add <theme-name>`. They can define colors for different elements like commands, output, warnings, and errors. Built-in themes are available, and users can create their own or import community-shared themes via `supercli theme import <url>`. Switch between themes instantly with `supercli theme apply <theme-name>`.

Feature: remove tools that are now longer the standard within the company

### Security
**Purpose:** Comprehensive vulnerability detection and supply chain security management.

The Security section provides an integrated set of security-focused tools designed to identify and mitigate vulnerabilities throughout your project's dependency chain. SuperCli supports language-specific security analysis tools that scan for known vulnerabilities, outdated dependencies, and potential security risks. By automating security scanning and consolidating results in one place, teams can proactively manage security posture without requiring specialized security expertise.

Feature: Users can run security scans for their project by executing `security scan`. SuperCli automatically detects the languages and frameworks in use, then runs appropriate supply chain security tools tailored to each technology stack.

Feature: Audit all used tools for vulnerabilities.
Now users can have many tools installed but there is a strong increase of software supply chain attacks. It would be helpfull if we can facilitate users in a quick an easy way to scan and check for vulnarabilities on their system.

feature: Include a connection with GitHub Advisory Database
Enable a connection with the GAD so user will have a realtimish input for their security scans.

Feature: provide how-to information to keep env secure
We want user to have all information about how to make theur workplace secure written down in supercli. This way they do not have to search for it on a website or any other place.

**Key Features:**
- Language-specific vulnerability detection
- Supply chain security analysis
- Automated dependency scanning
- Consolidated security reporting
- Actionable remediation guidance

**Key Benefits:**
- Early vulnerability detection in development
- Reduced security debt and compliance risks
- Standardized security practices across projects
- Faster incident response and patching
- Team-wide security awareness and accountability

### Templates
**Purpose:** Rapidly scaffold consistent docs, configs, and project assets.

Templates provide ready‑made blueprints for common artifacts in a documentation‑driven workflow, such as product vision, strategy, user flows, contribution guidelines, and workspace configuration. Teams can apply curated templates or define their own, ensuring new projects or sections start with a solid, standardized structure rather than from scratch.

Feature: list and apply templates via `tpl list` and `tpl apply <template-name>`. Create custom templates from current files with `tpl create --from .`.
Feature: Make it possible to add templates to the system and make the available for all users

**Key Benefits:**
- Faster onboarding with zero‑boilerplate starts
- Consistent structure across repos and teams
- Reusable, versioned blueprints maintained in source control
- Reduced copy‑paste errors and drift

### Integrations
**Purpose:** Connect SuperCli to your delivery ecosystem (e.g., GitHub).

Integrations streamline workflows by linking SuperCli to external services such as GitHub Issues and Projects. This enables actions like creating issues from documentation changes, syncing labels, and displaying project status without leaving the CLI. Authentication and configuration are centralized, so teams get a reliable, auditable path from docs to backlogs.

Feature: manage connections with `integrations connect github`, view state with `integrations status`, and create issues from the CLI using `issues create --from file.md`.

**Key Benefits:**
- Fewer context switches; work stays in the CLI
- Automated handoffs from docs to planning backlogs
- Traceability from source files to issues and projects
- Consistent permissions and configuration across workspaces

### Documentation
**Purpose:** Integrated access to project documentation and help resources.

The Documentation feature provides an organized view of all project documentation, guides, and references. Developers can browse documentation structure, search for topics, and access information without leaving the CLI. This ensures that documentation is discoverable and reduces the friction between code and its supporting materials.

Feature: create a internal development wiki so the information needed can be found easily.

**Key Benefits:**
- Single source of truth for project knowledge
- Integrated search and discovery
- Version-controlled documentation
- Improved team onboarding
