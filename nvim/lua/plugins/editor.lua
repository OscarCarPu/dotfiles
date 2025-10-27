-- Editor behavior customizations
return {
  -- Configure auto-pairs (mini.pairs)
  -- Disable auto-pairing only on third consecutive quote (for Python docstrings)
  {
    "echasnovski/mini.pairs",
    opts = function()
      -- Custom function to check if we should pair quotes
      -- Don't pair if the previous two characters are the same quote
      local function should_pair_quote(quote_char)
        return function()
          local line = vim.api.nvim_get_current_line()
          local col = vim.api.nvim_win_get_cursor(0)[2]
          -- Check if the two characters before cursor are the same quote
          if col >= 2 then
            local before = line:sub(col - 1, col)
            if before == quote_char .. quote_char then
              return false -- Don't pair on third quote
            end
          end
          return true -- Pair normally
        end
      end

      return {
        modes = { insert = true, command = false, terminal = false },
        mappings = {
          ['"'] = {
            action = "closeopen",
            pair = '""',
            neigh_pattern = "[^\\].",
            register = { cr = false },
          },
          ["'"] = {
            action = "closeopen",
            pair = "''",
            neigh_pattern = "[^\\].",
            register = { cr = false },
          },
          ["`"] = {
            action = "closeopen",
            pair = "``",
            neigh_pattern = "[^\\].",
            register = { cr = false },
          },
        },
      }
    end,
    config = function(_, opts)
      local pairs = require("mini.pairs")
      pairs.setup(opts)

      -- Override quote mappings to check for triple quotes
      local function smart_quote(quote_char)
        return function()
          local line = vim.api.nvim_get_current_line()
          local col = vim.api.nvim_win_get_cursor(0)[2]

          -- Check if the two characters before cursor are the same quote
          if col >= 2 then
            local before = line:sub(col - 1, col)
            if before == quote_char .. quote_char then
              -- Third quote - just insert without pairing
              return quote_char
            end
          end

          -- Otherwise, use mini.pairs default behavior
          return pairs.open(quote_char, quote_char)
        end
      end

      -- Set up smart quote mappings
      vim.keymap.set("i", '"', smart_quote('"'), { expr = true, replace_keycodes = false })
      vim.keymap.set("i", "'", smart_quote("'"), { expr = true, replace_keycodes = false })
      vim.keymap.set("i", "`", smart_quote("`"), { expr = true, replace_keycodes = false })
    end,
  },
}
