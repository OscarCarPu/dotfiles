[⬅ Back to main README](../README.md)

# Claude Code

Personal Claude Code configuration tracked in this repo: custom skills under
`claude/skills/`, symlinked into `~/.claude/skills/` by `install.sh`.

Skills are auto-loaded by Claude Code from `~/.claude/skills/<name>/SKILL.md`.
Each `SKILL.md` has a YAML frontmatter (`name`, `description`) — the
`description` is what Claude reads to decide when to invoke the skill, so it
should describe both *what* the skill does and *what triggers* it.

## Skills

| Skill | Trigger | Output |
|---|---|---|
| [`learning-ai-guide`](../claude/skills/learning-ai-guide/SKILL.md) | User attaches a course PDF and names a section to study (e.g. "explain Session 3", "tutor me on Section 4.2") | A single Markdown file in `learning/` next to the PDF: conceptual walkthrough, annotated worked material (derivations / runnable code / diagrams), and a graded exercise set. Adapts notation and tooling to the discipline. |

## Adding a new skill

1. Create `claude/skills/<skill-name>/SKILL.md` with frontmatter:

   ```markdown
   ---
   name: <skill-name>
   description: <when-to-use + triggers, in one paragraph>
   ---

   # <Skill Title>

   <body — instructions Claude follows when the skill is invoked>
   ```

2. Add a row to the table above.
3. The symlink is already in place (`claude/skills` → `~/.claude/skills`),
   so the new skill is picked up on the next Claude Code session.
