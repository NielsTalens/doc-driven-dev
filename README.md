# doc-driven-dev
A project to test the following concept: the base of the repo is the product definition (Strategy, vision, user flows, desired behaviour, how to test...). After a change in the product description a pull request and connected issue will be created. 


flowchart TD
    A[Product definition] --> B[Pull request]

    B --> C{Change in docs folder?}

    C -- Yes --> D[See doc changes<br/>Formulate goal, context & how to test<br/>Include product strategy, vision & user flows]

    D --> E[Create / update user story]

    E --> F[Link user story and PR]

    C -- No --> Z[No doc-driven action]
