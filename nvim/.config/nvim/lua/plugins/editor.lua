-- Editor: Navigation, text objects, pairs, statusline, and utilities
return {
  -- ════════════════════════════════════════════════════════════════════════════
  -- Flash (quick navigation)
  -- ════════════════════════════════════════════════════════════════════════════
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    ---@type Flash.Config
    opts = {},
    -- stylua: ignore
    keys = {
      { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
      { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
      { "r",     mode = "o",               function() require("flash").remote() end,            desc = "Remote Flash" },
      { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" },           function() require("flash").toggle() end,            desc = "Toggle Flash Search" },
    },
  },

  -- ════════════════════════════════════════════════════════════════════════════
  -- Mini.nvim (text objects, surround, pairs, statusline, icons)
  -- ════════════════════════════════════════════════════════════════════════════
  {
    "echasnovski/mini.ai",
    event = "VeryLazy",
    dependencies = {
      -- On garde ce plugin juste pour qu'il fournisse ses "requêtes" invisibles à mini.ai
      "nvim-treesitter/nvim-treesitter-textobjects",
      "folke/which-key.nvim",
    },
    config = function()
      local ai = require("mini.ai")
      ai.setup({
        n_lines = 500,
        custom_textobjects = {
          -- On connecte mini.ai à Treesitter pour qu'il comprenne f, c et b
          f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
          c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
          b = ai.gen_spec.treesitter({ a = "@block.outer", i = "@block.inner" }),
        },
      })
      local wk = require("which-key")
      wk.add({
        mode = { "o", "x" }, -- Mode Action (d, y, c) et Visuel (v)
        { "a", group = "Around textobject" },
        { "af", desc = "Around function" },
        { "ac", desc = "Around class" },
        { "ab", desc = "Around block" },
        { "aa", desc = "Around argument" },
        { "aq", desc = "Around quote" },
        { "at", desc = "Around tag (html/xml)" },
        { "an", desc = "Around next textobject" },
        { "al", desc = "Around last textobject" },
        { "i", group = "Inside textobject" },
        { "if", desc = "Inside function" },
        { "ic", desc = "Inside class" },
        { "ib", desc = "Inside block" },
        { "ia", desc = "Inside argument" },
        { "iq", desc = "Inside quote" },
        { "it", desc = "Inside tag (html/xml)" },
        { "in", desc = "Inside next textobject" },
        { "il", desc = "Inside last textobject" },
      })
    end,
  },
  {
    "nvim-mini/mini.nvim",
    config = function()
      -- Better Around/Inside textobjects
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [']quote
      --  - ci'  - [C]hange [I]nside [']quote
      -- require("mini.ai").setup({ n_lines = 500 })

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require("mini.surround").setup()

      require("mini.pairs").setup()
    end,
  },

  {
    "echasnovski/mini.icons",
    enabled = true,
    opts = {},
    lazy = true,
  },

  -- ════════════════════════════════════════════════════════════════════════════
  -- Persistence (session management)
  -- ════════════════════════════════════════════════════════════════════════════
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
  },
}
