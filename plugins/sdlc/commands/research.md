---
name: research
description: Deep technical investigation. Creates a research issue, uses multiple investigation methods, documents findings with evidence, and saves to QwickBrain as a spike document.
---

The /research command is for structured investigation when understanding is needed before decisions can be made. Prioritize depth over speed.

## Argument

Accept an optional argument: the research question. If not provided, use AskUserQuestion to elicit the question before proceeding. The question must be specific and answerable. A vague question like "how does auth work" is not sufficient. Refine it to something like "what is the correct approach for implementing SSO in the control panel given our existing Auth0 setup".

## Phases

### Phase 1: Define the Question

Load `sdlc:tracking-issues` to create a GitHub issue with the label `research`.

If the research question is ambiguous, use AskUserQuestion to clarify:
- What decision depends on this research?
- What are the candidate options being evaluated?
- What is the time constraint?
- What is already known?

Restate the final research question explicitly before proceeding. Confirm with the user if the scope is large.

If the scope appears unbounded, propose a time-box upfront using the pattern from COMMON-PATTERNS.md. Document what will be covered and what will not.

### Phase 2: Investigation

Apply RESEARCH-DEPTH.md and INVESTIGATION-METHODS.md throughout this phase.

Use all available tools systematically. Work through the investigation methods hierarchy in order:

**Level 1: Local codebase (always first)**
- Use the Task tool with Explore agent to understand existing structure and patterns
- Use Grep to find specific implementations, usages, and references
- Use Read to inspect actual code at identified file:line locations
- Check configuration files, package.json, and installed dependencies

**Level 2: Package registries**
- Check npmjs.com for version history, engine requirements, and dependencies
- Check download statistics and publish dates for maintenance signals

**Level 3: Code repositories**
- Search GitHub/GitLab for the project's repository
- Read README, CHANGELOG, and open issues
- Search the issue tracker for known problems relevant to the research question

**Level 4: Official documentation**
- Use WebFetch to retrieve official documentation and API references
- Check release announcements for breaking changes and migration guides

**Level 5: QwickBrain knowledge base**
- Use `mcp__qwickbrain__search_documents` to find past decisions and ADRs related to the question
- Use `mcp__qwickbrain__get_document` to retrieve specific documents by name and type
- Use `mcp__qwickbrain__list_documents` to browse by type (adr, spike, design, frd)
- Do not reinvent solutions that have already been decided

**Level 6: Community sources**
- Use WebSearch for community knowledge, Stack Overflow answers, and blog posts
- Verify community claims against primary sources before including them as evidence

**Level 7: Testing and experimentation**
- If documentation is unavailable or contradictory, create a minimal test case
- Run commands and capture actual output
- Document the test setup and results

Before concluding any item as "unknown", apply INVESTIGATION-METHODS.md exhaustiveness checklist. Document every method attempted and its result.

Apply FACT-VERIFICATION.md to all findings. Every factual claim must have:
- Source: file:line, URL, or command output
- Evidence: code snippet, documentation quote, or test result
- Verification method: how it was confirmed

Apply ITERATION-GATES.md. After the first pass, check the evidence gate and depth gate. Iterate to address gaps before documenting findings.

### Phase 3: Document Findings

Structure the findings document as follows:

**Research Question**
State the exact question being answered.

**Methods Used**
List each investigation method attempted and what it produced. Be specific.

**Findings**
Present each finding with its source (file:line or URL). Quote relevant code or documentation directly. No claims without evidence.

**Options Evaluated**
For each candidate option or approach:
- Description
- Evidence supporting it
- Trade-offs (pros and cons with evidence)
- Effort estimate if applicable

**Unknowns**
For each item that could not be determined, document:
- What is unknown
- Why it is unknowable with the methods attempted
- What would be needed to resolve it
- Impact on the recommendation

Apply COMMON-PATTERNS.md Unknown/Gap Documentation template for each unknown.

**Confidence Level**
State High (80-100%), Medium (50-80%), or Low (<50%) with justification. Reference SATISFACTORY-CRITERIA.md confidence level definitions.

**Recommendation**
State a concrete recommendation based on the findings. The recommendation must be actionable, not "investigate more". Each next step must have an effort estimate.

Apply SATISFACTORY-CRITERIA.md self-assessment checklist before finalizing. The document is not complete if any red flags are present (vague language, claims without evidence, placeholder recommendations, incomplete coverage).

### Phase 4: Save to QwickBrain

Save the findings as a spike document using `mcp__qwickbrain__create_document`:

```
doc_type: "spike"
name: [descriptive name for the research question]
project: [project name, e.g. "qwickapps" or "faabzi"]
content: [the full findings document]
```

Confirm the document was saved and provide the name so the user can retrieve it later.

### Phase 5: Close Issue

Close the GitHub issue with a comment that includes:
- A one-paragraph summary of the key finding
- The recommendation
- A link to the QwickBrain spike document by name and type

Do not close the issue until the spike document is saved in QwickBrain.
