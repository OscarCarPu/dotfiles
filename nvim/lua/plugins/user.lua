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
