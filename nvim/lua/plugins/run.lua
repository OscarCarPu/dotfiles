-- Custom :Run command for executing Rust and Python files
return {
  {
    "LazyVim/LazyVim",
    opts = function()
      -- Function to find Python venv
      local function find_python_venv()
        -- Check common venv locations
        local venv_names = { ".venv", "venv", "env" }
        for _, name in ipairs(venv_names) do
          local venv_python = vim.fn.getcwd() .. "/" .. name .. "/bin/python"
          if vim.fn.filereadable(venv_python) == 1 then
            return venv_python
          end
        end
        -- Fallback to system python
        return "python"
      end

      -- Function to get Rust binary name from file path
      local function get_rust_bin_name(filepath)
        -- Check if file is in src/bin/ directory
        local bin_match = filepath:match("src/bin/([^/]+)%.rs$")
        if bin_match then
          return bin_match
        end
        return nil
      end

      -- Function to find Cargo project root from file location
      local function find_cargo_root()
        local filepath = vim.fn.expand("%:p")
        local current_dir = vim.fn.fnamemodify(filepath, ":h")

        while current_dir ~= "/" do
          if vim.fn.filereadable(current_dir .. "/Cargo.toml") == 1 then
            return current_dir
          end
          current_dir = vim.fn.fnamemodify(current_dir, ":h")
        end
        return nil
      end

      -- Create the :Run command
      vim.api.nvim_create_user_command("Run", function()
        local filepath = vim.fn.expand("%:p")
        local filetype = vim.bo.filetype
        local cmd = ""

        if filetype == "rust" then
          local cargo_root = find_cargo_root()
          if cargo_root then
            local bin_name = get_rust_bin_name(filepath)
            if bin_name then
              cmd = "cd " .. cargo_root .. " && cargo run --bin " .. bin_name
            else
              cmd = "cd " .. cargo_root .. " && cargo run"
            end
          else
            -- Standalone Rust file
            local filename = vim.fn.expand("%:t:r")
            cmd = "rustc " .. vim.fn.expand("%") .. " && ./" .. filename
          end
        elseif filetype == "python" then
          local python_cmd = find_python_venv()
          cmd = python_cmd .. " " .. vim.fn.expand("%")
        else
          vim.notify("Filetype not supported by :Run command", vim.log.levels.WARN)
          return
        end

        -- Execute in a terminal split
        vim.cmd("split")
        vim.cmd("terminal " .. cmd)
        vim.cmd("startinsert")
      end, {
        desc = "Run current file (Rust/Python)",
      })
    end,
  },
}
