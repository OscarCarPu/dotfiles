-- You can also add or configure plugins by creating files in this `plugins/` folder
-- PLEASE REMOVE THE EXAMPLES YOU HAVE NO INTEREST IN BEFORE ENABLING THIS FILE
-- Here are some examples:

---@type LazySpec
return {
  {
    "magicmonty/sonicpi.nvim",
    config = function()
      require("sonicpi").setup {
        server_dir = "/var/lib/flatpak/app/net.sonic_pi.SonicPi/x86_64/stable/0fde7cfd6263d6d19b4e3e4dda1fa656a09af2ae0c27702fa8f5bfcba76155a9/files/app/server",
      }
    end,
  },
}
