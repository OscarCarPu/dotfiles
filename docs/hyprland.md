[&#11013; Back to main README](../README.md)

# Hyprland Configuration

## Keybindings

| Key | Action |
|-----|--------|
| `SUPER + E` | Open Kitty terminal |
| `SUPER + R` | Open Wofi launcher |
| `SUPER + Q` | Kill active window |
| `SUPER + V` | Power menu (wofi) — shutdown, reboot, or update |
| `SUPER + SHIFT + N` | Toggle sticky note |

## Power Menu (Super+V)

A wofi selection menu for power actions and system updates.

| Option | Behavior |
|--------|----------|
| `⏻  Shutdown` | Immediate shutdown — no terminal opens |
| `↺  Reboot` | Immediate reboot — no terminal opens |
| `⟳  Update + Shutdown` | Opens update terminal, then shuts down |
| `⟳  Update + Reboot` | Opens update terminal, then reboots |
| `⟳  Update Only` | Opens update terminal, no power action |
| `×  Cancel` | Dismiss menu |

**Update terminal flow:**
1. Calculates available updates and starts AI summary fetch in the background
2. Shows latest Arch Linux news
3. Lists packages updating (critical ones highlighted in red)
4. Optionally shows AI summary — already fetched, no waiting
5. Confirms before running the update
6. Checks `.pacnew` files after update

**AI summary** requires `GROQ_API_KEY` set in `~/.bashrc`. Uses the LLM's training knowledge — no slow GitHub changelog fetching.

**Source:** [`hypr/scripts/shutdown.sh`](../hypr/scripts/shutdown.sh)

---

## Sticky Note

A floating terminal note window (Kitty + micro) pinned across all workspaces.

| Key / Action | Description |
|---|---|
| `SUPER + SHIFT + N` | Toggle sticky note open/closed |
| `SUPER + left-click drag` | Move the note around the screen |
| `SUPER + SHIFT + 1–8` | Move the note to a specific workspace |

**Notes file:** `~/.sticky-notes.md` (plain Markdown, auto-created on first open)

**Source:** [`hypr/scripts/sticky_note.sh`](../hypr/scripts/sticky_note.sh)

The window is pinned (`pin` rule), so it follows you across workspaces by default. Use `SUPER + SHIFT + number` to unpin it onto a specific workspace if needed.

---

## Startup Boot Mode Selector

On Hyprland startup, a wofi popup appears allowing you to choose the boot mode.

**Options:**

| Key | Option | Description |
|-----|--------|-------------|
| `1` | Normal Setup | Opens browser (Gmail, Clockify, Gemini, WhatsApp) on workspace 2, Spotify on workspace 3 |
| `2` | Learn Go | Same as Normal + Go tests tutorial site + terminal at `~/dev/play/go/learn-tests/` |
| `3` | Boot Windows | Opens a terminal and runs `winboot` |

**Controls:**
- Type the number to quick-filter, then press Enter
- Use Up/Down arrows to navigate, then Enter to confirm
- Press Escape to cancel (no action)

**Source:** [`hypr/scripts/startup_apps.sh`](../hypr/scripts/startup_apps.sh)

### Adding/Removing Options

1. **Add a new option:** Define a function in the script, then add `"function_name|Label"` to `ENABLED_OPTIONS`
2. **Remove an option:** Delete or comment out its line in `ENABLED_OPTIONS`

```bash
ENABLED_OPTIONS=(
    "normal_setup|Normal Setup"
    "learn_go|Learn Go"
    "boot_windows|Boot Windows"
)
```
