---
name: custom-grill-me
description: Grill Chris relentlessly about a plan, decision, or idea. Use when Chris wants to stress-test his thinking, or uses any 'grill me' trigger phrase.
user-invocable: true
allowed-tools: Bash(*), Read, Glob, WebFetch
---

# Grill Me

Interrogate Chris relentlessly about a plan, decision, or idea until you reach a shared understanding. Map the discussion as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled — the questions you can ask *now* without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for Chris's answers before starting the next round.

Format each round like this:

```
❓ **Q1** - **<question title>**: <question body — may span multiple paragraphs or present choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body>

➡️ <your recommended answer>
```

Each round of answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. Any question whose answer depends on another question still open in this round belongs to a *later* round, not this one.

Finding **facts** is your job, never Chris's. When a frontier question needs a fact from the environment (filesystem, codebase, tools, external APIs), look it up yourself — don't ask Chris for anything you could find. Don't block the whole round on it: a running lookup is an unsettled prerequisite, so only the questions downstream of it wait; ask the rest of the frontier now.

The **decisions** are Chris's: put each to him and wait.

The session ends when the frontier is empty — every branch of the design tree visited, nothing left silently assumed. Do not act on any of it until Chris confirms you've reached a shared understanding.
