# doc-driven-dev
A project to test the following concept: 

# Product Vision

| **Product Vision** |
|--------------------|
| We create room for teams to focus on exceptional product creation by ensuring that every story naturally reflects the strategy, vision and user flows. We achieve this by taking away the manual effort of connecting documentation to development and by generating meaningful, well-aligned stories. |

| **Target Groups** | **Needs** | **Product** | **Business Goals** |
|-------------------|-------------------|-------------------|-------------------|
| Software product teams (PMs, Designers, Developers, Tech Leads, QA). | - Disconnect between product definition and development work.<br>- Documentation is outdated or neglected.<br>- Story creation is detached from definitions and PRs.<br>- Hard to maintain alignment between strategy, vision, user flows, and implementation. | - Automatic detection of documentation changes from PRs.<br>- Extraction of goals, context, assumptions, and test ideas.<br>- Integration with product strategy & user flows.<br>- Automated creation or enrichment of user stories.<br>- Linking PRs and stories for traceability.<br>- Optional doc-driven validation or test hints. | - Reduce time spent creating/maintaining user stories.<br>- Improve documentation quality and consistency.<br>- Strengthen alignment between strategy and implementation.<br>- Reduce rework caused by unclear requirements.<br>- Increase team productivity and clarity. |

| **Differentiators** | **Metrics**|
|--------|-------------|
| - Deep integration with the development workflow (PRs + docs).<br>- AI-assisted extraction of product intent from real documentation.<br>- Strong focus on product strategy and user flows, not just text summarization.<br>- Encourages healthy documentation habits without extra burden.<br>- Unique “doc-driven dev” workflow innovation. | - Time saved per story created.<br>- Documentation update frequency.<br>- Reduction in rework due to unclear requirements.<br>- Consistency score between docs, stories, and PRs.<br>- Adoption across teams (active users / repos). |

# User flows
```mermaid
flowchart LR
    A[Product owner receives feedback from users] --> B[Addition to existing functionality is required]
    B --> C[PO updates product definitions and user flows]
    C --> D[PO creates a pull request]
    D --> E[User story is created<br/>reflecting the change in the product definition<br/>and linked to the PR]
    E --> F[Link to the user story is included<br/>in the product definition in the main branch]
```

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
