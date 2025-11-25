# AI Chat Setup Guide (GitHub Copilot)

This guide explains how to set up and use the AI chat integration in Neovim using CopilotChat with GitHub Copilot.

## Prerequisites

1. **GitHub Copilot Access**: Free for verified students, teachers, and open source maintainers.
   - Student/Teacher: Get it through GitHub Education at https://education.github.com/
   - Already verified? Your existing Copilot subscription works!

2. **GitHub Account**: You need to be signed in to GitHub

## Installation

### 1. Authenticate GitHub Copilot

If you haven't already authenticated Copilot:

1. Open Neovim
2. Run: `:Copilot auth`
3. Follow the authentication flow in your browser
4. Enter the code shown in Neovim
5. Authorize GitHub Copilot

### 2. Install the plugins

Open Neovim and run:
```vim
:Lazy sync
```

Wait for `CopilotChat.nvim` and dependencies to install. Restart Neovim after installation completes.

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:Ask` | Opens quick chat prompt with current file as context |
| `:CopilotChat` | Open full chat window |
| `:CopilotChatToggle` | Toggle the chat window visibility |
| `:CopilotChatExplain` | Explain current code/selection |
| `:CopilotChatTests` | Generate tests for current code |
| `:CopilotChatFix` | Fix issues in current code |
| `:CopilotChatOptimize` | Optimize current code |
| `:CopilotChatDocs` | Generate documentation |

### Keybindings

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>aa` | Normal | Quick ask with current file context |
| `<leader>aa` | Visual | Ask about selected code |
| `<leader>ac` | Normal | Toggle chat window |
| `<leader>ae` | Normal/Visual | Explain code |
| `<leader>at` | Normal | Generate tests |
| `<leader>af` | Normal/Visual | Fix code issues |
| `<leader>ao` | Normal/Visual | Optimize code |
| `<leader>ad` | Normal | Generate documentation |
| `<leader>an` | Normal | Open full chat window |

**Note**: `<leader>` is the space key in LazyVim.

### Chat Window Shortcuts

Inside the chat window:
- `<CR>` (Enter) - Submit prompt / Send message
- `<C-s>` (Ctrl+s) - Submit prompt in insert mode
- `<C-c>` - Close chat (insert mode)
- `q` - Close chat (normal mode)
- `<C-r>` - Reset/clear chat
- `<C-y>` - Accept AI's suggested diff
- `gd` - Show diff of changes
- `gy` - Yank/copy the diff
- `gp` - Show system prompt
- `gs` - Show user selection

### Workflow Examples

#### Example 1: Quick question about current file
1. Open any file in Neovim
2. Press `<leader>aa` (space + a + a)
3. Type your question in the prompt: "What does this function do?"
4. Press Enter
5. Copilot responds with context about your file

#### Example 2: Ask about selected code
1. Select code in visual mode (press `v` and select lines)
2. Press `<leader>aa`
3. Type your question
4. Press Enter
5. Copilot analyzes just the selected code

#### Example 3: Explain code
1. Select code or place cursor in function
2. Press `<leader>ae`
3. Copilot opens chat with explanation

#### Example 4: Fix code issues
1. Select problematic code
2. Press `<leader>af`
3. Copilot suggests fixes
4. Press `<C-y>` to accept the changes

#### Example 5: Generate tests
1. Place cursor in a function
2. Press `<leader>at`
3. Copilot generates test cases

### Context Options

CopilotChat can use different contexts using `@` mentions in chat:
- `@buffers` - Include all open buffers (default)
- `@buffer` - Current buffer only
- `@file <path>` - Specific file
- Type `@` and press Tab to see all options

### Slash Commands

Use `/` commands in chat for special actions:
- `/explain` - Explain code
- `/review` - Review code
- `/fix` - Fix problems
- `/optimize` - Optimize code
- `/docs` - Generate documentation
- `/tests` - Generate tests
- Type `/` and press Tab to see all options

## Benefits of Copilot Chat vs Anthropic API

✅ **Free for students** - No separate API costs
✅ **No API key management** - Uses GitHub authentication
✅ **Same quality** - Powered by GPT-4 class models
✅ **Integrated with GitHub** - Understands your repos
✅ **Built-in commands** - Explain, fix, test, optimize
✅ **No credit limits** - Part of your Copilot subscription

## Troubleshooting

### "Copilot not authorized" error
- Run `:Copilot auth` to authenticate
- Make sure you have an active Copilot subscription
- Check your subscription at: https://github.com/settings/copilot

### "Copilot not available for students"
- Sign up for GitHub Education: https://education.github.com/
- Verify your student status with school email
- After verification, enable Copilot in your GitHub settings

### Plugin not loading
- Run `:Lazy sync` to ensure CopilotChat.nvim is installed
- Check for errors: `:Lazy log`
- Restart Neovim
- Make sure `copilot.lua` is also installed (it's a dependency)

### Chat window not opening
- Check if Copilot is enabled: `:Copilot status`
- Enable Copilot: `:Copilot enable`
- Look for error messages: `:messages`

### "Node.js version" error
- Copilot requires Node.js version > 18.x
- Check your version: `node --version`
- Update Node.js if needed

### Chat responses are slow
- This is normal - AI responses can take a few seconds
- Check your internet connection
- GitHub Copilot requires active internet connection

## Privacy & Data

- Copilot Chat sends your code to GitHub's servers for processing
- Review GitHub's privacy policy: https://docs.github.com/en/copilot/overview-of-github-copilot/about-github-copilot
- You can control what data is sent in GitHub Copilot settings
- Copilot respects `.gitignore` patterns

## Additional Resources

- CopilotChat.nvim: https://github.com/CopilotC-Nvim/CopilotChat.nvim
- GitHub Copilot docs: https://docs.github.com/en/copilot
- GitHub Education: https://education.github.com/
- copilot.lua: https://github.com/zbirenbaum/copilot.lua

## Enabling Inline Suggestions (Optional)

If you also want inline code suggestions (ghost text), enable copilot.lua:

```vim
:Copilot enable
```

This will show AI suggestions as you type (separate from chat feature).
