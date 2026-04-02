return {
  -- ════════════════════════════════════════════════════════════════════════════
  -- Rustaceanvim: L'outil ultime pour Rust
  -- ════════════════════════════════════════════════════════════════════════════
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    lazy = false,
    config = function()
      vim.g.rustaceanvim = {
        server = {
          -- Remplacement de `client` par `_` pour corriger l'avertissement Lua
          on_attach = function(_, bufnr)
            local map = function(mode, lhs, rhs, desc)
              vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
            end

            -- Déclarer le groupe Which-Key dynamiquement (uniquement pour les buffers Rust)
            pcall(function()
              require("which-key").add({
                { "<leader>r", group = "Rust", icon = "🦀", mode = { "n", "v" } },
              })
            end)

            -- Surcharge du Hover standard (K) par celui de Rust (qui gère mieux les macros et types)
            map("n", "K", function()
              vim.cmd.RustLsp({ "hover", "actions" })
            end, "Hover Actions (Rust)")

            -- Raccourcis exclusifs à Rust sous le préfixe <leader>r
            map({ "n", "v" }, "<leader>ra", function()
              vim.cmd.RustLsp("codeAction")
            end, "Code Action")
            map("n", "<leader>rr", function()
              vim.cmd.RustLsp("runnables")
            end, "Runnables (Run/Test)")
            map("n", "<leader>re", function()
              vim.cmd.RustLsp("expandMacro")
            end, "Expand Macro")
            map("n", "<leader>rE", function()
              vim.cmd.RustLsp("explainError")
            end, "Explain Error")
            map("n", "<leader>rd", function()
              vim.cmd.RustLsp("renderDiagnostic")
            end, "Render Diagnostic")
            map("n", "<leader>rp", function()
              vim.cmd.RustLsp("parentModule")
            end, "Parent Module")
            map("n", "<leader>rm", function()
              vim.cmd.RustLsp("rebuildProcMacros")
            end, "Rebuild Macros")
          end,
          default_settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
              },
              checkOnSave = {
                command = "clippy",
              },
              diagnostics = {
                enable = true,
              },
            },
          },
        },
      }
    end,
  },

  -- ════════════════════════════════════════════════════════════════════════════
  -- Crates.nvim: La magie pour Cargo.toml
  -- ════════════════════════════════════════════════════════════════════════════
  {
    "Saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    config = function()
      require("crates").setup({
        lsp = {
          enabled = true,
          actions = true,
          completion = true,
          hover = true,
        },
      })

      -- Raccourcis exclusifs quand tu ouvres un Cargo.toml
      vim.api.nvim_create_autocmd("BufRead", {
        pattern = "Cargo.toml",
        callback = function(args)
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
          end

          -- Déclarer un sous-groupe Which-Key pour Crates.nvim
          pcall(function()
            require("which-key").add({
              { "<leader>rc", group = "Crates", icon = "📦" },
            })
          end)

          -- Raccourcis de gestion des dépendances (sous <leader>rc)
          map("n", "<leader>rcv", function()
            require("crates").show_versions_popup()
          end, "Show Versions")
          map("n", "<leader>rcf", function()
            require("crates").show_features_popup()
          end, "Show Features")
          map("n", "<leader>rcd", function()
            require("crates").show_dependencies_popup()
          end, "Show Dependencies")
          map("n", "<leader>rcu", function()
            require("crates").upgrade_all_crates()
          end, "Upgrade All Crates")
        end,
      })
    end,
  },
}
