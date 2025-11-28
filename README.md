# doc-driven-dev
A project to test the following concept: 

# Product Vision
# Product Vision Canvas

| Section | Description |
|--------|-------------|
| **Vision** | Create an automated, documentation-driven development assistant that keeps product definition, user flows, strategy, and implementation seamlessly aligned. |
| **Target Group** | Software product teams: Product Managers, Designers, Developers, Tech Leads, QA Engineers. |
| **Needs / Problems** | - Disconnect between product definitions and actual development work.<br>- Documentation is often outdated or neglected.<br>- User stories are created separately from the product definition and PRs, causing inconsistencies.<br>- Difficult to maintain a continuous connection between product strategy, vision, user flows, and implementation.<br>- Manual translation from product definition to development work wastes time and introduces misalignment. |
| **Product** | A system that monitors documentation and pull requests, detects changes, interprets their intent, generates user stories with goal/context/test guidance, and links them to PRs—ensuring documentation-driven, strategy-aligned development. |
| **Business Goals** | - Reduce time spent writing and maintaining user stories.<br>- Improve quality, completeness, and accuracy of documentation.<br>- Strengthen alignment between product strategy and implementation decisions.<br>- Reduce rework and misunderstandings caused by unclear requirements.<br>- Promote documentation-first and consistent product thinking.<br>- Increase developer efficiency and clarity. |
| **Key Features** | - Automatic detection of documentation changes from PRs.<br>- Extraction of goals, context, assumptions, and test ideas.<br>- Integration with product strategy & user flows.<br>- Automated creation or enrichment of user stories.<br>- Linking PRs and stories for traceability.<br>- Optional doc-driven validation or test hints. |
| **Value Proposition** | Ensure that product changes always reflect strategic intent and user needs by automatically translating documentation updates into actionable, high-quality user stories. |
| **Differentiators** | - Deep integration with the development workflow (PRs + docs).<br>- AI-assisted extraction of product intent from real documentation.<br>- Strong focus on product strategy and user flows, not just text summarization.<br>- Encourages healthy documentation habits without extra burden.<br>- Unique “doc-driven dev” workflow innovation. |
| **Metrics** | - Time saved per story created.<br>- Documentation update frequency.<br>- Reduction in rework due to unclear requirements.<br>- Consistency score between docs, stories, and PRs.<br>- Adoption across teams (active users / repos). |

# User flows

# Features

- A product repo contains the product definition (Strategy, vision, user flows, desired behaviour, how to test...).
- After a change in the product description a pull request and connected issue will be created. 



```mermaid
flowchart LR
    A[Product definition] --> B[Pull request]

    B --> C{Change in docs folder?}

    C -- Yes --> D[See doc changes<br/>Formulate goal, context & how to test<br/>Include product strategy, vision & user flows]

    D --> E[Create / update user story]

    E --> F[Link user story and PR]

    C -- No --> Z[No doc-driven action]
```
