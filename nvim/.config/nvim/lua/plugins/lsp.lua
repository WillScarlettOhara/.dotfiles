return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason-lspconfig.nvim",
    },
    config = function()
      -- ════════════════════════════════════════════════════════════════════
      -- LSP Keymaps Setup
      -- ════════════════════════════════════════════════════════════════════
      local function setup_keymaps(bufnr)
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
        end

        -- Hover & Signature
        map("n", "K", function()
          vim.lsp.buf.hover({ border = "rounded", max_height = 25, max_width = 120 })
        end, "Hover")
        map({ "n", "i" }, "<C-k>", vim.lsp.buf.signature_help, "Signature Help")

        -- gd, gD, gr, gi, gy handled by Snacks picker (snacks.lua)

        -- Diagnostics navigation
        map("n", "[d", function()
          vim.diagnostic.jump({ count = -1 })
        end, "Prev Diagnostic")
        map("n", "]d", function()
          vim.diagnostic.jump({ count = 1 })
        end, "Next Diagnostic")

        -- <leader>c = Code
        map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code Action")
        map("n", "<leader>cr", vim.lsp.buf.rename, "Rename Symbol")
        map("n", "<leader>cd", vim.diagnostic.open_float, "Line Diagnostic")
        map(
          "n",
          "<leader>cv",
          "<cmd>vsplit | lua vim.lsp.buf.definition()<cr>",
          "Definition in Vsplit"
        )

        -- <leader>l = LSP
        map("n", "<leader>li", "<cmd>LspInfo<cr>", "LSP Info")
        map("n", "<leader>lr", "<cmd>LspRestart<cr>", "LSP Restart")
        map("n", "<leader>lh", function()
          vim.lsp.inlay_hint.enable(
            not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }),
            { bufnr = bufnr }
          )
        end, "Toggle Inlay Hints")
      end

      -- ════════════════════════════════════════════════════════════════════
      -- LSP Attach Handler
      -- ════════════════════════════════════════════════════════════════════
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
        callback = function(args)
          local bufnr = args.buf
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then
            return
          end

          setup_keymaps(bufnr)
          vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

          -- Inlay hints disabled by default (toggle with <leader>lh)

          -- Document highlight on cursor hold
          if client.server_capabilities.documentHighlightProvider then
            local group =
              vim.api.nvim_create_augroup("LspDocumentHighlight_" .. bufnr, { clear = true })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              buffer = bufnr,
              group = group,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              buffer = bufnr,
              group = group,
              callback = vim.lsp.buf.clear_references,
            })
          end
        end,
      })

      -- ════════════════════════════════════════════════════════════════════
      -- BGforge-MLS Language Server
      -- ════════════════════════════════════════════════════════════════════
      vim.lsp.config["bgforge-mls"] = {
        cmd = { "bgforge-mls-server", "--stdio" },
        filetypes = { "weidu-baf", "weidu-d", "weidu-tp2", "fallout-worldmap-txt" },
        root_markers = { ".git" },
      }
      vim.lsp.enable("bgforge-mls")

      -- ════════════════════════════════════════════════════════════════════
      -- Diagnostic Configuration
      -- ════════════════════════════════════════════════════════════════════
      vim.diagnostic.config({
        virtual_text = false,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = { border = "rounded", source = true, header = "", prefix = "" },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN] = "󰀪 ",
            [vim.diagnostic.severity.INFO] = "󰋽 ",
            [vim.diagnostic.severity.HINT] = "󰌶 ",
          },
          numhl = {
            [vim.diagnostic.severity.ERROR] = "ErrorMsg",
            [vim.diagnostic.severity.WARN] = "WarningMsg",
          },
        },
      })
    end,
  },
  {
    "mason-org/mason.nvim",
    lazy = false,
    cmd = "Mason",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    lazy = false,
    dependencies = { "neovim/nvim-lspconfig" },
    config = function()
      -- Per-server overrides via vim.lsp.config (Neovim 0.11+ API).
      -- mason-lspconfig 2.x auto-enables installed servers; we only need to
      -- (1) opt-out servers we want to handle ourselves (e.g. rust_analyzer
      --     handled by rustaceanvim), and (2) tweak per-server settings.
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            -- lazydev.nvim handles workspace/library config
            telemetry = { enable = false },
          },
        },
      })

      vim.lsp.config("intelephense", {
        cmd = { "intelephense", "--stdio" },
        filetypes = { "php", "blade" },
        root_markers = { "composer.json", ".git" },
        init_options = {
          licenceKey = (function()
            local f = io.open(os.getenv("HOME") .. "/intelephense/license.txt", "rb")
            if not f then
              return ""
            end
            local content = f:read("*a")
            f:close()
            return (content:gsub("%s+", ""))
          end)(),
        },
      })

      require("mason-lspconfig").setup({
        -- Auto-enable all installed servers EXCEPT rust_analyzer
        -- (rustaceanvim spins up its own rust-analyzer instance)
        automatic_enable = {
          exclude = { "rust_analyzer" },
        },
      })
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    lazy = false,
    dependencies = { "mason-org/mason-lspconfig.nvim" },
    config = function()
      require("mason-tool-installer").setup({
        ensure_installed = {
          -- Language Servers
          "lua_ls",
          "gopls",
          "zls",
          "ts_ls",
          "intelephense",
          "bashls",
          "pyright",
          "cssls",
          "html",
          "jsonls",
          "yamlls",
          -- Linters
          "eslint_d",
          -- "luacheck",
          "golangci-lint",
          "shellcheck",
          "markdownlint",
          "yamllint",
          "jsonlint",
          "htmlhint",
          "stylelint",
          "phpstan",
          "ruff",
          "mypy",
          -- Formatters
          "stylua",
          "goimports",
          "prettier",
          "black",
          "isort",
          "shfmt",
          -- "pint", -- Laravel formatter, requires PHP/composer; install manually if needed
        },
      })
    end,
  },
}
