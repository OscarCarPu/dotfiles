return {
  {
    "tidalcycles/vim-tidal",
    ft = "tidal",
    init = function()
      vim.g.tidal_boot = vim.fn.expand "~/dev/tidalcycles/BootTidal.hs"
    end,
  },
}
