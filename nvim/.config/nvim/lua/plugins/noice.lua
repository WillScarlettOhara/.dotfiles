-- function for simplifying the views options
local function getviews()
  local views = {}
  local all_views = {
    "notify",
    "split",
    "vsplit",
    "popup",
    "mini",
    "cmdline",
    "cmdline_popup",
    "cmdline_output",
    "messages",
    "confirm",
    "hover",
    "popupmenu",
  }
  for _, view in ipairs(all_views) do
    views[view] = { scrollbar = false }
  end
  views["split"].enter = true
  views["mini"] = { scrollbar = false, timeout = 5000 } -- 5 secondes
  views["notify"] = { scrollbar = false, timeout = 5000 }
  return views
end

return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    views = getviews(),
    lsp = {
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
      hover = { enabled = true },
      signature = { enabled = true },
    },
    routes = {
      {
        filter = {
          event = "msg_show",
          any = {
            { find = "%d+L, %d+B" },
            { find = "lines yanked" },
            { find = "; before #" },
            { find = "; after #" },
          },
        },
        view = "mini",
      },
      {
        filter = {
          any = {
            { event = { "notify", "msg_show" }, find = "No information available" },
            { event = { "notify", "msg_show" }, find = "minifiles is not supported" },
            { event = "msg_show", kind = "", find = "written" },
          },
        },
        opts = { skip = true },
      },
    },
    presets = {
      bottom_search = true,
      command_palette = true,
      long_message_to_split = true,
      lsp_doc_border = true,
    },
  },
  config = function(_, opts)
    local map = vim.keymap.set
    if vim.o.filetype == "lazy" then
      vim.cmd([[messages clear]])
    end

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
