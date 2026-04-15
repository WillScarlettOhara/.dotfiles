return {
  {
    "BGforgeNet/BGforge-MLS",
    lazy = false,
    config = function()
      -- Filetype detection
      vim.filetype.add({
        extension = {
          ssl = "fallout-ssl",
          baf = "weidu-baf",
          d = "weidu-d",
          tp2 = "weidu-tp2",
          tpa = "weidu-tp2",
          tph = "weidu-tp2",
          tpp = "weidu-tp2",
          tra = "weidu-tra",
        },
        filename = {
          ["worldmap.txt"] = "fallout-worldmap-txt",
        },
      })

      -- Commentstring
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "fallout-ssl", "weidu-baf", "weidu-d", "weidu-tp2", "weidu-tra" },
        callback = function()
          vim.bo.commentstring = "// %s"
        end,
      })

      -- LSP
      vim.lsp.config["bgforge-mls"] = {
        cmd = { "bgforge-mls-server", "--stdio" },
        filetypes = { "fallout-ssl", "weidu-baf", "weidu-d", "weidu-tp2", "fallout-worldmap-txt" },
        root_markers = { ".git" },
      }
      vim.lsp.enable("bgforge-mls")

      -- Tree-sitter parser registration
      vim.api.nvim_create_autocmd("User", {
        pattern = "TSUpdate",
        callback = function()
          local parsers = require("nvim-treesitter.parsers")
          local url = "https://github.com/BGforgeNet/BGforge-MLS"

          parsers.ssl = {
            install_info = {
              url = url,
              location = "grammars/fallout-ssl",
              queries = "grammars/fallout-ssl/queries",
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
          parsers.fallout_msg = {
            install_info = {
              url = url,
              location = "grammars/fallout-msg",
              queries = "grammars/fallout-msg/queries",
            },
          }
          parsers.weidu_tra = {
            install_info = {
              url = url,
              location = "grammars/weidu-tra",
              queries = "grammars/weidu-tra/queries",
            },
          }
        end,
      })

      -- Map tree-sitter grammar names to Neovim filetypes
      vim.treesitter.language.register("ssl", "fallout-ssl")
      vim.treesitter.language.register("baf", "weidu-baf")
      vim.treesitter.language.register("weidu_d", "weidu-d")
      vim.treesitter.language.register("weidu_tp2", "weidu-tp2")
      vim.treesitter.language.register("fallout_msg", "fallout-msg")
      vim.treesitter.language.register("weidu_tra", "weidu-tra")
    end,
  },
}