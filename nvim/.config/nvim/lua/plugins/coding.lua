-- Coding: Completion, treesitter, and dev tools
return {
  -- ════════════════════════════════════════════════════════════════════════════
  -- Completion (blink.cmp)
  -- ════════════════════════════════════════════════════════════════════════════
  {
    "saghen/blink.cmp",
    version = "*",
    config = function()
      require("blink.cmp").setup({
        snippets = { preset = "default" },
        signature = { enabled = true },
        appearance = {
          use_nvim_cmp_as_default = false,
          nerd_font_variant = "normal",
        },
        sources = {
          default = { "lazydev", "lsp", "path", "buffer", "snippets" },
          providers = {
            lazydev = {
              name = "LazyDev",
              module = "lazydev.integrations.blink",
              score_offset = 100,
            },
            cmdline = {
              min_keyword_length = 2,
            },
          },
        },
        keymap = {
          ["<C-f>"] = {},
        },
        cmdline = {
          enabled = true,
          completion = { menu = { auto_show = true } },
          keymap = {
            ["<CR>"] = { "accept_and_enter", "fallback" },
            -- Ajoute le preset par défaut pour que Tab et les flèches fonctionnent bien
            preset = "cmdline",
          },
          -- On explique à Blink quelles sources utiliser selon si tu cherches (/) ou si tu tapes une commande (:)
          sources = function()
            local type = vim.fn.getcmdtype()
            if type == "/" or type == "?" then
              return { "buffer" }
            end
            if type == ":" then
              return { "cmdline", "path" }
            end
            return {}
          end,
        },
        completion = {
          menu = {
            border = "rounded",
            scrolloff = 1,
            scrollbar = false,
            draw = {
              padding = 1,
              gap = 1,
              columns = {
                { "kind_icon" },
                { "label", "label_description", gap = 1 },
                { "kind" },
                { "source_name" },
              },
            },
          },
          documentation = {
            window = {
              border = "rounded",
              scrollbar = false,
              winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc",
            },
            auto_show = true,
            auto_show_delay_ms = 500,
          },
        },
      })
    end,
  },

  -- ════════════════════════════════════════════════════════════════════════════
  -- Treesitter
  -- ════════════════════════════════════════════════════════════════════════════
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      require("nvim-treesitter").setup({
        ensure_installed = {
          "bash",
          "c",
          "css",
          "go",
          "gomod",
          "gosum",
          "gowork",
          "html",
          "javascript",
          "json",
          "latex",
          "lua",
          "luadoc",
          "luap",
          "markdown",
          "markdown_inline",
          "php",
          "proto",
          "python",
          "query",
          "regex",
          "rust",
          "scss",
          "svelte",
          "swift",
          "terraform",
          "tsx",
          "typescript",
          "vim",
          "vimdoc",
          "vue",
          "yaml",
          "zig",
        },
        auto_install = true,
      })
      -- BGforge-MLS parser registration
      vim.api.nvim_create_autocmd("User", {
        pattern = "TSUpdate",
        callback = function()
          local parsers = require("nvim-treesitter.parsers")
          local url = "https://github.com/BGforgeNet/BGforge-MLS"

          parsers.weidu_tra = {
            install_info = {
              url = url,
              location = "grammars/weidu-tra",
              queries = "grammars/weidu-tra/queries",
            },
          }
          parsers.baf = {
            install_info = {
              url = url,
              location = "grammars/weidu-baf",
              queries = "grammars/weidu-baf/queries",
            },
          }
          parsers.weidu_d = {
            install_info = {
              url = url,
              location = "grammars/weidu-d",
              queries = "grammars/weidu-d/queries",
            },
          }
          parsers.weidu_tp2 = {
            install_info = {
              url = url,
              location = "grammars/weidu-tp2",
              queries = "grammars/weidu-tp2/queries",
            },
          }
        end,
      })

      -- Map tree-sitter grammar names to Neovim filetypes
      vim.treesitter.language.register("weidu_tra", "weidu-tra")
      vim.treesitter.language.register("baf", "weidu-baf")
      vim.treesitter.language.register("weidu_d", "weidu-d")
      vim.treesitter.language.register("weidu_tp2", "weidu-tp2")

      -- Enable treesitter-based highlighting and indentation
      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })
      vim.opt.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
  },

  -- ════════════════════════════════════════════════════════════════════════════
  -- Lua development
  -- ════════════════════════════════════════════════════════════════════════════
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        { path = "snacks.nvim", words = { "Snacks" } },
      },
    },
  },

  -- ════════════════════════════════════════════════════════════════════════════
  -- Autotags for HTML/JSX
  -- ════════════════════════════════════════════════════════════════════════════
  {
    "windwp/nvim-ts-autotag",
    ft = {
      "html",
      "xml",
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
      "vue",
      "svelte",
      "astro",
      "markdown",
      "php",
      "blade",
    },
    opts = {
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = false,
      },
    },
  },
}
