# doc-driven-dev
A project to test the following concept: 

# Product Vision

| **Product Vision** |
|--------------------|
| We remove the busywork from product development by automatically translating product definitions into aligned user stories just-in-time. This way we make sure every story reflects the product vision and user flows, allowing teams to focus on crafting exceptional products. |

| **Target Groups** | **Needs** | **Product** | **Business Goals** |
|-------------------|-------------------|-------------------|-------------------|
| Software product teams (PMs, Designers, Developers, Tech Leads, QA). | - Disconnect between product definition and development work.<br>- Documentation is outdated or neglected.<br>- Story creation is detached from definitions and PRs.<br>- Hard to maintain alignment between strategy, vision, user flows, and implementation. | - Automatic detection of documentation changes from PRs.<br>- Extraction of goals, context, assumptions, and test ideas.<br>- Integration with product strategy & user flows.<br>- Automated creation or enrichment of user stories.<br>- Linking PRs and stories for traceability.<br>- Optional doc-driven validation or test hints. | - Reduce time spent creating/maintaining user stories.<br>- Improve documentation quality and consistency.<br>- Strengthen alignment between strategy and implementation.<br>- Reduce rework caused by unclear requirements.<br>- Increase team productivity and clarity. |

| **Differentiators** | **Metrics**|
|--------|-------------|
| - Deep integration with the development workflow (PRs + docs).<br>- AI-assisted extraction of product intent from real documentation.<br>- Strong focus on product strategy and user flows, not just text summarization.<br>- Encourages healthy documentation habits without extra burden.<br>- Unique “doc-driven dev” workflow innovation. | - Time saved per story created.<br>- Documentation update frequency.<br>- Reduction in rework due to unclear requirements.<br>- Consistency score between docs, stories, and PRs.<br>- Adoption across teams (active users / repos). |

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
