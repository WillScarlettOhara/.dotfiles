return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
    "TmuxNavigatorProcessList",
  },
  -- stylua: ignore
  keys = {
    { "<c-h>",  "<cmd>TmuxNavigateLeft<cr>",     mode = { "n", "v", "i", "t" }, desc = "Navigate Left" },
    { "<c-j>",  "<cmd>TmuxNavigateDown<cr>",     mode = { "n", "v", "i", "t" }, desc = "Navigate Down" },
    { "<c-k>",  "<cmd>TmuxNavigateUp<cr>",       mode = { "n", "v", "i", "t" }, desc = "Navigate Up" },
    { "<c-l>",  "<cmd>TmuxNavigateRight<cr>",    mode = { "n", "v", "i", "t" }, desc = "Navigate Right" },
    { "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>", mode = { "n", "v", "i", "t" }, desc = "Navigate Previous" },
  },
}
