return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("noice").setup({
      -- Snacks.notifier handles all notifications. We disable Noice's notify
      -- routing to avoid duplicate messages.
      notify = { enabled = false },
      messages = { enabled = false },
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true, -- Gardé par sécurité même avec Blink
        },

        -- Noice prend le relais pour afficher les fenêtres de documentation LSP.
        -- Tes raccourcis actuels (`K` pour Hover et `<C-k>` pour Signature)
        -- déclencheront automatiquement les belles fenêtres de Noice !
        hover = { enabled = true },
        signature = { enabled = true },
      },

      -- Les "presets" donnent un look très "VS Code / Moderne" instantanément
      presets = {
        bottom_search = true, -- La recherche avec '/' reste en bas (plus lisible)
        command_palette = true, -- La ligne de commande ':' s'ouvre au centre de l'écran
        long_message_to_split = true, -- Les très longs messages d'erreur s'ouvrent dans un split au lieu de bloquer l'écran
        inc_rename = false, -- À passer à true si un jour tu installes le plugin `inc-rename.nvim`
        lsp_doc_border = true, -- Ajoute de belles bordures aux fenêtres d'information LSP
      },
      popupmenu = {
        enabled = true,
        backend = "nui", -- Laisse "nui" pour que Noice dessine le menu de base si Blink ne le fait pas
      },

      -- ════════════════════════════════════════════════════════════════════
      -- Routage des messages (Pour ne pas spammer ton écran)
      -- ════════════════════════════════════════════════════════════════════
      routes = {
        {
          -- Intercepte les messages très courants de Vim (ex: "X lines yanked", "written")
          filter = {
            event = "msg_show",
            any = {
              { find = "%d+L, %d+B" }, -- Sauvegarde de fichier
              { find = "; before #" }, -- Undo
              { find = "; after #" }, -- Redo
              { find = "lines yanked" }, -- Copie
            },
          },
          -- Au lieu d'en faire une grosse notification Snacks, on les affiche
          -- discrètement (view = "mini") en bas à droite de l'écran.
          view = "mini",
        },
      },
    })

    -- ════════════════════════════════════════════════════════════════════
    -- Keymaps spécifiques à Noice (En plus de ceux de Snacks)
    -- ════════════════════════════════════════════════════════════════════
    vim.keymap.set("n", "<leader>nl", function()
      require("noice").cmd("last")
    end, { desc = "Noice Last Message" })
    vim.keymap.set("n", "<leader>nh", function()
      require("noice").cmd("history")
    end, { desc = "Noice History" })

    -- Note : Ton raccourci `<leader>nd` (Dismiss) est déjà géré par Snacks dans ta config,
    -- ce qui nettoiera aussi les messages passés par Noice !
  end,
}
