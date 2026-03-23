return {
  "stevearc/oil.nvim",
  dependencies = { "echasnovski/mini.icons" },
  opts = {
    default_file_explorer = false, -- garde snacks explorer
    columns = {
      "icon",
      "permissions",
      "size",
      "mtime",
    },
    skip_confirm_for_simple_edits = true,
    watch_for_changes = true,
    view_options = {
      show_hidden = true,
      -- Tri naturel des nombres : fichier2 avant fichier10
      natural_order = "fast",
      sort = {
        { "type", "asc" }, -- dossiers avant fichiers
        { "name", "asc" },
      },
    },
    keymaps = {
      ["q"] = "actions.close",
      ["<C-h>"] = false, -- libère pour vim-tmux-navigator
      ["<C-l>"] = false, -- libère pour vim-tmux-navigator
      -- ouvre la preview automatiquement à l'ouverture
      ["<CR>"] = "actions.select",
    },
    float = {
      padding = 2,
      max_width = 0.7,
      max_height = 0.7,
      preview_split = "right",
    },
    preview_win = {
      -- Met à jour la preview automatiquement quand tu bouges le curseur
      update_on_cursor_moved = true,
      preview_method = "fast_scratch",
    },
  },
  keys = {
    {
      "-",
      function()
        require("oil").open_float()
      end,
      desc = "Open Oil (float)",
    },
  },
  config = function(_, opts)
    require("oil").setup(opts)
    vim.api.nvim_create_autocmd("User", {
      pattern = "OilEnter",
      callback = function()
        local oil = require("oil")
        if oil.get_current_dir() then
          oil.open_preview()
        end
      end,
    })
  end,
}
