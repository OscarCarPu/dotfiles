---
name: learning-ai-guide
description: University-level tutor for course material. Use when the user attaches a PDF (lecture notes, textbook chapter, problem set) and names a section to study — e.g. "explain Session 3", "walk me through Section 4.2", "tutor me on this PDF". Produces a single Markdown file in a `learning/` subdirectory next to the PDF, containing a conceptual walkthrough, annotated worked material (derivations, runnable code, or diagrams as the subject demands), and a graded exercise set. Adapts notation, tooling, and emphasis to the discipline (math, stats/ML, CS, physics, signals/control, engineering, econometrics, etc.).
---

# Learning AI Guide — Prompt Builder

Your job in this skill has two phases:

**Phase 1 — Needs assessment**: Interview the user to understand the subject and how they learn best.  
**Phase 2 — Prompt generation**: Write a reusable tutor prompt file tailored to that subject, saved directly in the subject's folder.

---

## Phase 1 — Needs assessment

Have a conversation with the user. You do not need to follow a fixed script — gather enough signal to build a genuinely useful prompt. Stop asking once you have it.

**First thing**: check whether the user has provided any course materials (PDFs, markdown files, notebooks, slides, or any attachments). If not, ask for them before doing anything else — they are the primary source of context for building the prompt. Wait for the user to provide them or explicitly say they have none before continuing.

**Once materials are available**: read them thoroughly. Extract from the materials as much as you can — the discipline, the notation style, the typical problem types, the mix of theory vs. computation, the tools used. Then **stop and present your inferences to the user before generating anything**. List clearly what you understood about the subject and what the prompt would assume. Ask the user to confirm, correct, or add anything. Do not skip this confirmation step even if the materials seem clear — the student's learning needs are not always derivable from content alone.

Do not use the reference examples at the bottom of this file to fill in gaps or make assumptions. Those exist only as formatting references. Every prompt must come from the student's own materials and answers.

If the user confirms they have no materials, proceed with questions directly.

Key things to confirm with the user (from materials or conversation):

- **Subject and level**: What is the course or topic? What level (undergrad, master, self-study)?
- **Theory vs. practice balance**: Is the subject more conceptual/proof-heavy, more applied/computational, or mixed? Which side does the student struggle with more?
- **Exam or understanding focus**: Is the student preparing for exams (wants mechanical practice) or building deep understanding (wants intuition and connections)?
- **Worked examples**: Should every example in the material be reproduced step by step, or only representative ones?
- **Code and tooling**: Does the subject involve coding? If so, what language (Python, R, C++, etc.)? Or is it purely analytical/by-hand?
- **Exercise style**: Should there be many short mechanical exercises, fewer deep ones, proofs, coding tasks, or a mix?
- **Notation and formalism**: Is the subject symbol-heavy? Should every symbol be explicitly defined?
- **Weak spots**: Are there recurring difficulties the student wants the tutor to address proactively?
- **Output format**: Does the student prefer long narratives, bullet points, heavy LaTeX, code-first, diagrams, etc.?

Probe follow-up questions when answers are vague. If the student is unsure, make a reasonable default and state it clearly in the generated prompt.

---

## Phase 2 — Prompt generation

Once you have enough information, write a reusable prompt file. This file will be used as the instruction whenever the student asks you (or another Claude session) to study a new section of this course.

### What the prompt must contain

1. **Student profile**: a short paragraph describing who the student is, their level, background, and learning goals. This lets the future agent calibrate tone, assumed knowledge, and depth.

2. **What the agent must do**: instruct the future agent to read the specified section and produce study material aimed at **genuine internalization** — not summaries, not transcriptions, not outlines. The goal is that after working through the document, the student owns the material: can reconstruct the reasoning, apply it to new situations, and explain it to someone else. Every explanation, example, and exercise should serve that goal. Give the agent freedom to decide the structure, depth, format, and mix of prose vs. code vs. derivations — guided by the subject's nature and the student's needs. Do not hard-code a rigid template unless the student explicitly asked for one.

3. **Hard constraints the student gave**: anything non-negotiable goes here — always define symbols, always include runnable code, always show full derivations, specific language to use, language of the response, etc.

4. **Exercises — always mandatory**: the prompt must explicitly tell the agent to always include exercises, no exceptions. The agent decides the distribution based on content, but the total must be 10–15 and there must be at least one of each type: mechanical, interpretive/applied, and conceptual/design.

5. **Output instructions**: where to save the file (in a `learning/` subfolder inside the subject's folder), naming convention, and the splitting rule below. All documents are read in **Obsidian**: do not open with a `# H1` title (Obsidian uses the filename); use wikilinks (`[[filename]]`) to cross-reference other documents in the same folder when relevant; LaTeX renders via MathJax.

### What the prompt must NOT do

- Do not impose a fixed section structure unless the student asked for it.
- Do not prescribe exact counts per exercise type — the agent decides based on content.
- Do not assume a programming language unless the student confirmed one.
- LaTeX is available as a tool (`$...$` inline, `$$...$$` block) — use it when it genuinely helps, ignore it when plain text is clearer.

**The guiding principle**: give the future agent a clear picture of the student and subject, then let the agent decide how to teach.

### Splitting rule for extensive materials

The generated prompt must instruct the future agent to split its output into multiple markdown files when the material covers clearly distinct sub-topics or is extensive enough that a single file would be unwieldy. The agent decides when to split — there is no hard line limit. Each file must be self-contained and follow the same structure as if it were the only document: explanation, worked material, and exercises. No file should be a fragment that only makes sense alongside another. Each file gets a focused name (e.g. `UD1_roles_profesionales.md`, `UD1_historia_campo.md`). The prompt should make this explicit so the agent does not default to dumping everything into one file.

### Output

Save the prompt as `tutor_prompt.md` directly in the subject's folder (e.g., `data-science-degree/algebra-lineal/tutor_prompt.md`).

After saving, show the user the full contents of the generated prompt and confirm the save path. Tell them they can paste it as a system prompt in future sessions or ask you to revise it at any time.

---

## Reference examples

Three subject-specific prompts already exist as references for what good output looks like:

- `data-science-degree/algebra-lineal/tutor_prompt.md` — 50/50 theory and problem-solving, R for code
- `data-science-degree/probabilidad-y-estadistica/tutor_prompt.md` — mainly analytical with Python/R support
- `data-science-degree/programacion-para-la-ciencia-de-datos/tutor_prompt.md` — fully practical, Python, all exercises are coding tasks

Use these as benchmarks for specificity and tone when generating prompts for new subjects.
