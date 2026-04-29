return {
  "A7Lavinraj/fyler.nvim",
  dependencies = { "echasnovski/mini.icons" },
  keys = {
    {
      "-",
      function()
        require("fyler").open()
      end,
      desc = "Open Fyler (float)",
    },
  },
  opts = {
    views = {
      finder = {
        default_explorer = false, -- garde snacks explorer
        confirm_simple = true,
        follow_current_file = true,
        watcher = {
          enabled = true,
        },
        win = {
          kind = "float",
        },
      },
    },
  },
}
