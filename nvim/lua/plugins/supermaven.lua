return {
    {
        "supermaven-inc/supermaven-nvim",
        cmd = {"SupermavenUseFree"},
        event = "InsertEnter",
        config = function()
            require("supermaven-nvim").setup({
                keymaps = {
                    accept_suggestion = "<C-k>",
                    clear_suggestion = "<C-]>",
                    accept_word = "<C-j>",
                },
                color = {
                    suggestion_color = "#ff33ff",
                    cterm = 244,
                },
                log_level = "info",
                disable_keymaps = false
            })
        end,
    }
}
