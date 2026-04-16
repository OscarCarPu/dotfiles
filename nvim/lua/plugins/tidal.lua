return {
  {
    "tidalcycles/vim-tidal",
    ft = "tidal",
    init = function()
      vim.g.tidal_boot = vim.fn.expand "~/dev/tidalcycles/BootTidal.hs"
      vim.g.tidal_sc_enable = 1
    end,
  },
}
