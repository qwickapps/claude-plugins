---
name: writing-skills
description: >
  This skill should be used when creating a new skill for any Claude Code plugin, when improving
  or auditing an existing SKILL.md file, or when the user wants to document a technique as a
  reusable skill.
  Trigger phrases: "create a new skill", "add a skill", "write a skill", "how do I write a skill",
  "I want to document this technique", "add this to the plugin", "create a SKILL.md",
  "how do skills work", "how should I format a skill".
---

# Writing Skills for Claude Code Plugins

This skill covers the complete process of creating a new skill file for a Claude Code plugin.
A skill is a SKILL.md file that teaches the agent a specific technique, discipline, or workflow.
Skills auto-load based on context and description matching.

---

## What a Skill Is

A skill is procedural knowledge encoded in markdown. When Claude Code loads a skill, it reads the
file and applies the instructions for the duration of the task. Skills are not invoked by name
by the user. They activate based on description matching and context detection.

### When a Skill Activates

Claude Code reads the YAML frontmatter description field and determines whether the skill applies
to the current user prompt and context. The description must be precise enough to trigger the
skill when it is needed and not trigger it when it is not.

Skills load selectively: the frontmatter (name and description) always loads, the body loads
when the skill is triggered, and reference files in the references/ subdirectory load only when
the body directs the agent to them.

---

## Skill Directory Structure

```
skills/
  <skill-name>/
    SKILL.md                # Required. The skill content.
    references/             # Optional. Deep reference material.
      reference-topic.md
    examples/               # Optional. Worked examples.
      example-scenario.md
    scripts/                # Optional. Shell scripts referenced by the skill.
      setup.sh
```

The skill name uses present participle (gerund) form: `writing-tests`, `debugging`,
`creating-worktree`. Not `write-tests` or `test-writer`.

---

## SKILL.md Structure

Every SKILL.md has two parts: YAML frontmatter and a markdown body.

### YAML Frontmatter

```yaml
---
name: skill-name
description: >
  This skill should be used when [specific context or trigger].
  Trigger phrases: "[phrase 1]", "[phrase 2]", "[phrase 3]".
  Also load when [additional trigger conditions].
---
```

Requirements for the frontmatter:

**name** — Matches the directory name exactly. Present participle form.

**description** — Written in third person. Describes when the skill should be used, not what
the skill teaches. Must include specific trigger phrases. Start with: "This skill should be used
when...". The description is what the skill-activation system reads to determine if the skill
applies. Vague descriptions cause missed activations or false activations.

Third-person format is mandatory: "This skill should be used when..." not "Use this skill
when..." The difference is significant: the former is a statement about the skill's applicability
that the system evaluates, while the latter is an instruction that may confuse the activation logic.

### Markdown Body

The body teaches the technique. It is written in imperative or infinitive form, not second-person.

Correct:
- "Load the plan from docs/plans/."
- "Write a failing test first."
- "Run the verification command before declaring completion."

Incorrect:
- "You should load the plan."
- "You need to write a failing test first."
- "Make sure you run the verification command."

The body should be between 1,500 and 2,000 words. Skills shorter than 1,000 words often lack
the depth needed to change behavior. Skills longer than 3,000 words are harder to load and apply
consistently.

---

## Writing Process

### Step 1: Define the Trigger Conditions

Before writing anything, answer: when should this skill activate?

List at least five specific trigger phrases (user statements that indicate the skill is needed).
List at least two contextual triggers (what the agent observes that indicates the skill is needed,
independent of what the user said).

If the trigger conditions cannot be defined precisely, the skill scope is not clear enough. Narrow
it or split it into two skills.

### Step 2: Identify the Core Technique

Answer: what does the agent do differently when this skill is active versus when it is not?

A skill that cannot answer this question has no behavioral value. The technique must change
observable agent behavior: a different sequence of steps, a hard gate, a specific format, a
constraint, or a procedure.

### Step 3: Write the Frontmatter

Write the description. Include:
- The primary trigger condition (when the work type matches)
- Specific trigger phrases (what the user says)
- Secondary trigger conditions (what the agent observes)
- Any disambiguation (how to distinguish this skill from a similar one)

Test the description by asking: would the description cause the skill to load in the right
situations and not load in the wrong ones?

### Step 4: Write the Body

Organize the body around the technique, not around the history or motivation. The agent needs
to know what to do, in what order, and what gates to apply.

Effective body structure:
1. State the core principle in one or two sentences.
2. List any hard gates or iron laws (situations where the agent must stop before proceeding).
3. Describe the procedure in the order it should be executed.
4. Include concrete examples, commands, or output formats where relevant.
5. List failure modes (what the agent might do wrong without the skill, and how to avoid them).

Avoid:
- Motivation sections ("this matters because...")
- History sections ("previously, developers used to...")
- Hedging language ("you might want to consider...")
- Vague guidance ("make sure the code is good quality")

Every instruction must be specific enough to execute.

### Step 5: Add Reference Files If Needed

If a section of the body would require more than 300 words to describe fully, extract it into a
reference file. The body links to the reference:

```
For the full list of OWASP top 10 patterns, see references/owasp-patterns.md.
```

Reference files use the same imperative form as the body. They are loaded on demand, not
automatically. Keep each reference file focused on one topic.

### Step 6: Validate the Skill

Before marking the skill complete, run this checklist:

**Frontmatter:**
- [ ] name field matches the directory name
- [ ] description starts with "This skill should be used when..."
- [ ] description is in third person
- [ ] description includes at least three specific trigger phrases
- [ ] no instructions in the description (description is declarative, not imperative)

**Body:**
- [ ] written in imperative or infinitive form (not second person)
- [ ] between 1,500 and 2,000 words
- [ ] core principle stated in the first paragraph
- [ ] hard gates or stopping conditions are explicit
- [ ] procedure is in executable order
- [ ] no vague instructions ("ensure quality", "be careful")
- [ ] no second-person ("you should", "you need to")
- [ ] no hedging without explanation ("might", "possibly", "could")

**Behavior change:**
- [ ] can describe what the agent does differently with this skill active
- [ ] can describe a concrete failure mode the skill prevents
- [ ] the skill does not duplicate an existing skill

**Protocol improvement (if applicable):**
- [ ] if the skill introduces new or changed platform process, a KB spec document exists with labels `["protocol-improvement", "skill-update", "<skill-name>"]`
- [ ] KB document title follows: "Protocol Improvement: <skill-name> — <description>"
- [ ] KB document includes Before/After behavioral change description

---

## Common Mistakes

### Mistake 1: Description Is an Instruction

```yaml
# Wrong
description: >
  Use this skill to write better tests using TDD.
```

```yaml
# Correct
description: >
  This skill should be used when writing new code, when adding tests to existing code,
  or when a test fails and needs investigation.
  Trigger phrases: "write tests", "add a test", "test this", "TDD", "make this testable".
```

### Mistake 2: Body Uses Second Person

```
# Wrong
You should write a failing test before writing any implementation code.
Make sure you watch the test fail before proceeding.
```

```
# Correct
Write a failing test before writing any implementation code.
Watch the test fail before proceeding.
```

### Mistake 3: No Hard Gates

A skill without stopping conditions will be bypassed when the agent is moving quickly. Every
skill that enforces discipline needs explicit gates.

```
# Without gate (weak)
"It is generally good practice to write a test first."

# With gate (effective)
"HARD GATE: Do not write implementation code without a failing test. If there is no failing
test, stop. Write the test. Watch it fail. Then proceed."
```

### Mistake 4: Scope Too Broad

A skill that covers "writing good code" will not change behavior. The scope must be narrow
enough to produce specific, executable instructions.

Split broad skills into focused ones:
- Not "testing" but "writing-tests" (TDD procedure) and "verifying-completion" (evidence before assertions)
- Not "code quality" but "securing-code" (auth, OWASP) and "optimizing-performance" (profiling, caching)

### Mistake 5: No Concrete Examples

Agents apply abstract instructions inconsistently. Ground abstract guidance in concrete examples.

```
# Abstract (inconsistent)
"Use appropriate caching strategies for performance."

# Concrete (consistent)
"For database queries called on every page render: add Redis caching with a 60-second TTL.
For static configuration data: cache in memory at module initialization.
For user-specific data: cache with a key that includes the user ID."
```

---

## Skill Registration

After creating a SKILL.md, register the skill name in the plugin's skill-activation hook so the
skill-activation system knows to check for it.

The skill-activation hook in hooks/hooks.json contains a SessionStart prompt that lists all
available skills. Add the new skill name and a one-line description to that list.

If the plugin does not yet have a skill-activation hook, create one following the format in the
hooks directory.

---

## Protocol Improvement Labeling

When a new or updated skill changes how the platform operates — how agents execute a lifecycle
process, how work is tracked, how decisions are documented, or how quality is enforced — record
the change as a protocol improvement in the knowledge base.

This enables the PM agent's monthly health report to count protocol improvements per calendar
month, supporting the Platform Maturity metric `protocol_improvements_proposed_per_month`
(L3 criterion, L4 target ≥ 3/month). See the KB label taxonomy for the full definition:
"KB Label Taxonomy — protocol-improvement" (spec, label: `label-taxonomy`).

**Apply the `protocol-improvement` label when the skill:**

- Introduces new steps, gates, or constraints in an existing workflow
- Changes how agents execute a recurring lifecycle process (sprint, feature, release, review)
- Establishes a new naming convention, label, or taxonomy
- Adds a quality bar or decision criterion that was previously absent
- Closes a measurement gap in a Platform Maturity metric

**Do NOT apply the label when the skill:**

- Only improves documentation clarity without changing behavior
- Corrects instructions to match already-intended behavior (a fix, not an improvement)
- Covers a purely technical how-to with no workflow implications

**Procedure:**

After the skill is validated (Step 6), create a KB document to record the protocol improvement:

```
KB_CREATE_DOCUMENT:
  type: spec
  title: "Protocol Improvement: <skill-name> — <one-line description>"
  labels: ["protocol-improvement", "skill-update", "<skill-name>"]
  content: [use format below]
```

KB document content format:

```markdown
## Protocol Improvement: <skill-name>

**Date:** YYYY-MM-DD
**Skill:** <skill-name>
**Type:** New skill | Updated skill

### What Changed
[2–4 sentences describing the new or changed behavior the skill enforces.]

### Why It Matters
[The problem this solves or the gap it closes — one or two sentences.]

### Behavioral Change
Before: [What the agent did without this skill / before the update]
After: [What the agent does now]
```

If the skill update is minor (wording, example updates, no procedure change), skip the KB
document. If uncertain, create it — the cost of an extra KB entry is low; the cost of a missing
protocol improvement record is a gap in the maturity metric.

---

## Testing the Skill

Apply TDD to skill documentation: observe behavior without the skill, write the skill, verify
behavior changes.

**Baseline:** Before writing the skill, observe what the agent does without it. Document a
specific scenario where the agent makes a mistake or skips a step.

**Write the skill:** Create SKILL.md following this procedure.

**Verification:** Present the same scenario with the skill loaded. Verify the agent follows the
procedure defined in the skill. Check that the gate conditions are honored. Check that the output
format matches the skill's specification.

Document what changed:
- What mistake did the agent make before?
- What does the agent do correctly now?
- Is there any residual gap?

If behavior did not change, the skill body is too abstract. Rewrite the instructions to be more
specific and executable.

---

## Reference: Skill Activation Mechanics

Claude Code reads SKILL.md files from the plugin's skills directory. The description field in
the frontmatter is evaluated against the current context to determine applicability. The body
is loaded when the skill is determined to apply.

Skills are loaded per session and per prompt. A skill that is relevant to the session start
(like getting-started) loads at session initialization. Skills that are relevant to a specific
prompt (like debugging) load when the prompt matches the trigger conditions.

The 1% rule: load a skill if there is any meaningful chance it applies. The cost of loading
an unnecessary skill is one additional context block. The cost of missing a relevant skill is
incorrect or incomplete behavior.

For the full list of skills available in sdlc, their trigger conditions, and their
relationships to commands, see the getting-started skill.
