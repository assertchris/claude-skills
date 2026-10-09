---
name: custom-grill-me
description: Grill Chris relentlessly about a plan, decision, or idea. Use when Chris wants to stress-test his thinking, or uses any 'grill me' trigger phrase.
user-invocable: true
allowed-tools: Bash(*), Read, Glob, WebFetch
---

# Grill Me

Interrogate Chris relentlessly about a plan, decision, or idea until you reach a shared understanding. Map the discussion as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree one question at a time. The **frontier** is every decision whose prerequisites are already settled. Pick the single most important open question from the frontier, ask it concisely, give your recommended answer, and wait for Chris's response before asking the next one.

Format each question like this:

```
❓ **<question title>**: <question body — concise>

➡️ <your recommended answer>
```

After Chris answers, update the tree, recompute the frontier, and ask the next single question.

**Before asking Chris anything**, check whether you can answer it yourself. If the question is about the codebase, a note Chris has shared, a file, a config, a tool, or any fact you can look up — look it up and resolve it yourself. Only ask Chris about decisions that genuinely only he can make. Never ask Chris for information you could find with context already provided.

The **decisions** are Chris's: put each to him one at a time and wait.

The session ends when the frontier is empty — every branch of the design tree visited, nothing left silently assumed. Do not act on any of it until Chris confirms you've reached a shared understanding.
