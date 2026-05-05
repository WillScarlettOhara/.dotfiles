-- ════════════════════════════════════════════════════════════════════════════
-- Rust IDE: rustaceanvim wraps rust-analyzer with first-class Neovim support
-- (inlay hints, code actions grouping, runnables, debuggables, expand macro,
-- crate graph, etc.)
-- ════════════════════════════════════════════════════════════════════════════
return {
  {
    "mrcjkb/rustaceanvim",
    version = "^9", -- requires Neovim 0.11+; you're on 0.13-dev
    lazy = false, -- handles its own lazy loading via ftplugin
    ft = { "rust" },
    init = function()
      vim.g.rustaceanvim = {
        -- Plugin behaviour
        tools = {
          float_win_config = { border = "rounded" },
          hover_actions = { replace_builtin_hover = true },
          code_actions = { ui_select_fallback = true },
        },
        -- LSP
        server = {
          on_attach = function(_, bufnr)
            -- Inlay hints ON by default for Rust
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })

            -- Register which-key group + descriptions for Rust mappings
            local ok_wk, wk = pcall(require, "which-key")
            if ok_wk then
              wk.add({
                buffer = bufnr,
                { "<leader>r", group = "Rust", icon = { icon = "󱘗", color = "orange" } },
                { "<leader>rr", desc = "Runnables" },
                { "<leader>rd", desc = "Debuggables" },
                { "<leader>rt", desc = "Testables" },
                { "<leader>rm", desc = "Expand Macro" },
                { "<leader>rc", desc = "Open Cargo.toml" },
                { "<leader>re", desc = "Explain Error" },
                 { "<leader>rD", desc = "Render Diagnostic" },
                 { "<leader>ro", desc = "Open docs.rs" },
                 { "<leader>r?", desc = "Rust Cheat Sheet" },
              })
            end

            local map = function(mode, lhs, rhs, desc)
              vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
            end

            -- Hover actions (better than vim.lsp.buf.hover for rust)
            map("n", "K", function()
              vim.cmd.RustLsp({ "hover", "actions" })
            end, "Rust Hover Actions")

            -- Code action grouping
            map({ "n", "v" }, "<leader>ca", function()
              vim.cmd.RustLsp("codeAction")
            end, "Rust Code Action")

            -- Runnables / Debuggables / Testables
            map("n", "<leader>rr", function()
              vim.cmd.RustLsp("runnables")
            end, "Rust Runnables")
            map("n", "<leader>rd", function()
              vim.cmd.RustLsp("debuggables")
            end, "Rust Debuggables")
            map("n", "<leader>rt", function()
              vim.cmd.RustLsp("testables")
            end, "Rust Testables")

            -- Expand macro under cursor
            map("n", "<leader>rm", function()
              vim.cmd.RustLsp("expandMacro")
            end, "Rust Expand Macro")

            -- Open Cargo.toml
            map("n", "<leader>rc", function()
              vim.cmd.RustLsp("openCargo")
            end, "Open Cargo.toml")

            -- Explain the error under cursor
            map("n", "<leader>re", function()
              vim.cmd.RustLsp("explainError")
            end, "Explain Error")

            -- Render diagnostic (full message)
            map("n", "<leader>rD", function()
              vim.cmd.RustLsp("renderDiagnostic")
            end, "Render Diagnostic")

            -- Open docs.rs for symbol under cursor
            map("n", "<leader>ro", function()
              vim.cmd.RustLsp("openDocs")
            end, "Open docs.rs")

            -- Open Rust Cheat Sheet (cheats.rs)
            map("n", "<leader>r?", function()
              vim.fn.system("xdg-open https://cheats.rs")
            end, "Rust Cheat Sheet")

            -- Signature help already set globally in lsp.lua (<C-k>)
          end,
          default_settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
                buildScripts = { enable = true },
              },
              -- Use clippy instead of cargo check on save
              checkOnSave = true,
              check = {
                command = "clippy",
                extraArgs = { "--no-deps" },
              },
              procMacro = {
                enable = true,
                ignored = {
                  ["async-trait"] = { "async_trait" },
                  ["napi-derive"] = { "napi" },
                  ["async-recursion"] = { "async_recursion" },
                },
              },
              inlayHints = {
                bindingModeHints = { enable = false },
                chainingHints = { enable = true },
                closingBraceHints = { enable = true, minLines = 25 },
                closureReturnTypeHints = { enable = "never" },
                lifetimeElisionHints = { enable = "never", useParameterNames = false },
                maxLength = 25,
                parameterHints = { enable = true },
                reborrowHints = { enable = "never" },
                renderColons = true,
                typeHints = {
                  enable = true,
                  hideClosureInitialization = false,
                  hideNamedConstructor = false,
                },
              },
            },
          },
        },
        -- DAP (debugging) - works with nvim-dap if installed
        dap = {},
      }
    end,
  },
}
