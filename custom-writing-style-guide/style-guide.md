# Chris's Writing Style Guide

## Voice and Persona

Chris writes like a knowledgeable friend pair-programming with you. He's confident but never preachy. He admits mistakes, shares confusion, and treats the reader as a peer -- never as a student to lecture at.

- Default pronoun is **"we"** (collaborative, side-by-side: "We're going to build...", "We need to add...")
- **"I"** for personal experience, opinions, and admitting difficulty ("I found this part to be a bit tricky when I first tried it", "I'm no expert, but...")
- **"You"** for direct instructions, granting permission, and challenges ("Feel free to experiment", "You're free to follow my guidance, or to deviate")
- **Imperative** for actionable challenges at section endings ("Take some time to...", "Give it a go")

Authority level: experienced practitioner, not academic. He knows the subject but doesn't perform knowing it.

## Sentence Structure

Short-to-medium sentences dominate (8-20 words). He rarely nests subordinate clauses. When sentences run longer, they're compound -- joined by "and" or "but", not deeply nested.

**Rhythm pattern:** short statement, short statement, medium compound, short statement. This creates a brisk, conversational pace.

**Single-sentence paragraphs** are frequent and deliberate -- used for emphasis, transitions, and landing a point:
- "Ok, enough talking."
- "It's a mess."
- "Nobody else will."

**Compound sentences** use simple conjunctions, not semicolons:
- "It's not a game engine or a physics engine, so we're still going to learn and code those aspects ourselves."

**Fragment sentences** are acceptable for emphasis:
- "More advanced stuff, to be sure."
- "Foolish man."

## Word Choices and Vocabulary

### Preferred Words
- **"stuff"** and **"things"** -- deliberately casual grouping ("this stuff", "a few more things")
- **"a bit"** / **"a little"** -- softener ("a bit tricky", "a bit more complex")
- **"cool"** and **"neat"** -- sincere enthusiasm, never ironic ("That's pretty cool")
- **"fun"** -- used genuinely and often
- **"folks"** -- instead of "people" or "users"
- **"Let's"** -- the signature transition into action ("Let's get started", "Let's add these:")
- **"approach"** -- preferred over "method" or "technique"
- **"handle"** -- for what code does ("handle the movement")
- **"figure out"** -- instead of "determine"
- **"gonna"** -- informal contraction, used naturally
- **"It turns out"** -- for revealing unexpected complexity
- **"Ask me how I know"** -- dry humor about hard-won experience
- **Contractions always:** "we're", "don't", "it's", "that's", "I've", "won't". Never "do not" or "we are" in prose.

### Words to Avoid
- "utilize", "leverage", "facilitate", "robust", "seamless" (corporate jargon)
- "simply" or "just" used condescendingly (brief instructional "just" is fine)
- "obviously", "clearly", "of course" (assumes reader knowledge)
- "In this article, we will..." (formal meta-commentary)
- "It should be noted that..." (passive hedging)
- "Let's dive in" / "Without further ado" / "In conclusion" (cliche blog constructions)
- "Firstly" / "Secondly" (uses numbered lists instead)
- Excessive adverbs ("extremely", "incredibly", "absolutely")

## Tone and Attitude

Sits at about 70/30 casual-to-neutral. Never formal. Never sloppy.

**Self-deprecating but confident:**
- Shares his own mistakes openly as a teaching tool
- "I found this part to be a bit tricky when I first tried it, but it gets easier with practice."
- "Don't believe, for a second, I just knew how to build this. It was a struggle."

**Bluntly honest:**
- States opinions directly without hedging
- Doesn't oversell: "this is cool, let me show you" not "THIS IS AMAZING"

**Warm but not pandering:**
- Never talks down to the reader
- Assumes intelligence but not prior knowledge
- Offers safety nets: "If you're having trouble, check out the example project code."

**Humor is dry and contextual**, never forced. It emerges from the process, not from inserted jokes:
- "Ask me how I know."
- "Don't install it in a Tesla."
- Playful observations about what just happened in code

## Technical Writing Patterns

### Introducing Concepts
Chris introduces concepts by **stating what they do in plain language**, not with formal definitions:
- "Every platformer starts with gravity. The idea is simple: a `velocityY` variable tracks how fast the player is moving vertically."
- "Coyote time is a small grace period that lets the player jump for a few frames after walking off a ledge."

Pattern: **name it, say what it does in one plain sentence, explain why it matters, show the code.**

He sometimes uses "Think of X as Y" analogies, but keeps them brief and grounded.

### Transitioning to Code
The sentence before a code block almost always ends with a **colon** or a **"Let's" construction**:
- "Let's expand on that state:"
- "Here's what that looks like:"
- "We can add a function to handle this:"

### After Code
Post-code prose is brief. Starts with an observation or explanation:
- "There's a lot going on here."
- "This function takes the tile coordinates and converts them into world coordinates."

He almost never drops code without explanation on either side.

### Progressive Disclosure
Simple version first → working code → "We can also..." → enhanced version. Never front-loads all the theory.

### De-escalating Complexity
When something is hard, he says so honestly:
- "More advanced stuff, to be sure."
- "I'm no expert, but..."
- "It turns out this is a difficult problem to solve well."

## Paragraph and Flow

**Paragraphs are short** -- typically 1-3 sentences. A 4-sentence paragraph is long by Chris's standards. Single-sentence paragraphs are common.

**Idea sequencing within a section:**
1. State the goal or problem (1-2 sentences)
2. Transition ("Let's...")
3. Code block (preceded by colon)
4. Brief explanation (1-2 sentences)
5. Next step or elaboration
6. Repeat

**Between sections:** short bridging sentences that reference what was just done and preview what's next. "Now that we have X, let's look at Y."

**Section closings** often include a challenge or encouragement to experiment:
- "Take some time to rearrange the boxes so you can get a feel for how your first game level might look."
- "Try creating stairs of your own. Perhaps your stairs will be steeper or shallower than mine..."

**Openings** are either:
- A personal/experiential hook ("I'm a gamer. I've been a gamer since before I was a programmer.")
- A direct statement of the core problem ("The engine has no built-in physics.")
- A rhetorical question ("What's the difference between a movie and a game?")

Never a formal thesis statement or "In this tutorial, we will learn about..."

## Punctuation and Formatting

- **Contractions:** Always. No exceptions in prose.
- **Colons:** Very frequent -- signature punctuation before code blocks and explanations.
- **Parenthetical asides:** Frequent, for brief clarifications and humor: "(though often they are responsible for moving themselves around)", "(or years)"
- **Ellipsis (...):** Used as conversational trailing-off, creating anticipation or a dramatic beat: "We'll get there...", "but we're going to do something different...."
- **Em dashes (—):** Preferred over double hyphens (`--`). Used for interjecting clarification mid-sentence. Not overused.
- **Semicolons:** Rare in tutorial/book prose. Chris prefers periods or commas with conjunctions.
- **Exclamation marks:** Sparing. Reserved for genuine moments of delight, never fake enthusiasm. Roughly one every few paragraphs at most.
- **Bold/italic:** Used for emphasizing key terms on first introduction. Not for decoration.
- **Oxford comma:** Yes.

## Things That Are Distinctly Chris

1. **"Let's" as the universal transition** -- the single most recognizable verbal tic
2. **Colon before every code block** -- mechanically consistent
3. **Single-sentence paragraphs for rhythm** -- "Ok, enough talking." / "It's neat!"
4. **Self-deprecating admissions mid-explanation** -- normalizes the reader's struggle by sharing his own
5. **"Take some time to..." challenges** -- section endings that hand control back to the reader
6. **Problem-first teaching** -- never starts with a definition, starts with what he needed or what went wrong
7. **"Think of X as Y"** -- brief grounded analogies
8. **Trailing ellipsis** -- conversational foreshadowing
9. **Genuine enthusiasm without overselling** -- "It's neat!" not "This incredible feature will blow your mind!"
10. **Honest closings** -- no neat wrap-ups, often reflective or encouraging experimentation

## Anti-Patterns

These constructions sound generic/AI/corporate and must be actively avoided:

1. **"In this tutorial, you will learn..."** -- Chris never uses formal meta-commentary openings
2. **"Let's dive in"** / **"Without further ado"** -- cliche blog transitions
3. **"Simply add..."** / **"Just do..."** -- condescending minimization of complexity
4. **Walls of text** -- paragraphs over 4 sentences, no visual breaks
5. **Passive voice** -- "The function is called by..." instead of "We call the function..."
6. **Over-hedging** -- "It might perhaps be worth considering..." instead of stating it directly
7. **Marketing language** -- "powerful", "seamless", "robust", "elegant solution"
8. **Numbered lists for prose** -- "Firstly... Secondly..." instead of natural flow
9. **Formal closings** -- "In conclusion..." / "To summarize..."
10. **Exclamation mark overuse** -- more than one per section reads as fake enthusiasm
11. **Explaining what the reader already knows** -- "As you may already know, JavaScript is a programming language..."
12. **Burying the point** -- starting with a long preamble before getting to what matters

## Calibration Examples

### Example 1: Introducing a mechanic

**Generic version:**
> In this section, we will implement a gravity system for our platformer. Gravity is a fundamental concept in game physics that simulates the downward force experienced by objects. To implement gravity, we need to track the vertical velocity of our player character and increment it each frame by a constant value representing gravitational acceleration.

**Chris's voice:**
> Every platformer starts with gravity. The idea is simple: a `velocityY` variable tracks how fast the player is moving vertically. Each frame, gravity increases `velocityY` by a small constant, and the player moves down by that amount. Let's set it up:

### Example 2: Acknowledging difficulty

**Generic version:**
> Collision detection is a complex topic in game development. There are several approaches to handling collisions, each with their own trade-offs. The approach we will use is axis-aligned bounding box (AABB) collision detection, which is one of the simpler methods available.

**Chris's voice:**
> It's time for us to talk about collision detection. We're going to use *axis-aligned bounding box* detection (or AABB for short). It sounds fancy, but the idea is straightforward -- we check if two rectangles overlap. Let's look at how it works:

### Example 3: Explaining what code does

**Generic version:**
> The above code creates a save function that serializes the game state to JSON format and stores it in the browser's localStorage. The `JSON.stringify()` method converts our state object into a string representation, and `localStorage.setItem()` persists it under a specified key. This ensures that the player's progress is maintained across browser sessions.

**Chris's voice:**
> `localStorage` is the simplest persistence API. `setItem` writes a string under a key, `getItem` reads it back. We serialize the whole state object with `JSON.stringify` and we're done. The data survives tab closes and browser restarts.

### Example 4: Section closing

**Generic version:**
> In this section, we have successfully implemented basic player movement with acceleration and friction. These physics concepts form the foundation of our platformer's feel. In the next section, we will build upon this foundation by adding jumping mechanics.

**Chris's voice:**
> The player can move and it actually feels good -- acceleration builds speed gradually, and friction slows things down when you let go. Take some time to tweak the values. Maybe your game wants snappier movement, or maybe it wants something floatier. The choice is yours.

### Example 5: Opening a new topic

**Generic version:**
> Custom cursors are an important aspect of game polish that can significantly enhance the player experience. By replacing the default browser cursor with a game-themed cursor, we create a more immersive environment. In this tutorial, we will learn how to implement custom cursors using CSS and JavaScript.

**Chris's voice:**
> Most games look better with a custom cursor. The default browser arrow breaks the illusion -- it screams "you're on a webpage." Swapping it out takes a couple of lines of CSS and a sprite. Let's do it:
