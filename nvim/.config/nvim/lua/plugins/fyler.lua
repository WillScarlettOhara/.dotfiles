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
        mappings = {
          ["<BS>"] = "GotoParent",
          ["?"] = function()
            local lines = {
              "  q          Close Fyler",
              "  <CR>       Open file",
              "  <C-t>      Open in new tab",
              "  |          Open in vsplit",
              "  -          Open in split",
              "  <BS>       Go to parent dir",
              "  ^          Go to cwd",
              "  .          Go to node",
              "  #          Collapse all",
              "  a          Add file/dir",
              "  d          Delete",
              "  r          Rename",
              "  c          Copy",
              "  m          Move",
              "  o          Open with system app",
              "  y          Yank",
              "  p          Paste",
              "  u          Update",
              "  I          Toggle ignored",
              "  H          Toggle hidden",
              "  Z          Close all dirs",
            }
            Snacks.notify(table.concat(lines, "\n"), {
              title = "Fyler Keymaps",
              timeout = 15000,
              icon = "󰌌",
            })
          end,
        },
      },
    },
  },
}
