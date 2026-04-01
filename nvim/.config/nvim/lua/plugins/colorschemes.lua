return {
  {
    "sainnhe/gruvbox-material",
    priority = 1000,
    config = function()
      vim.o.background = "dark"
      vim.g.gruvbox_material_transparent_background = 2
      vim.g.gruvbox_material_foreground = "original"
      vim.g.gruvbox_material_background = "hard"
      vim.g.gruvbox_material_ui_contrast = "high"
      vim.g.gruvbox_material_float_style = "blend"
      vim.g.gruvbox_material_statusline_style = "default"
      vim.g.gruvbox_material_cursor = "auto"
      vim.g.gruvbox_material_enable_bold = 1
      vim.g.gruvbox_material_enable_italic = 1
      vim.g.gruvbox_material_diagnostic_virtual_text = "colored"
      vim.cmd("colorscheme gruvbox-material")
      local hl = vim.api.nvim_set_hl

      -- Dashboard
      hl(0, "SnacksDashboardHeader", { fg = "#83A598", bold = true })
      hl(0, "SnacksDashboardKey", { fg = "#FABD2F", bold = true })
      hl(0, "SnacksDashboardIcon", { fg = "#B8BB26" })
      hl(0, "SnacksDashboardDesc", { fg = "#ebdbb2" })

      -- Snacks indentline (Arc-en-ciel fidèle à l'image)
      hl(0, "SnacksIndent1", { fg = "#FB4934" }) -- red
      hl(0, "SnacksIndent2", { fg = "#FE8019" }) -- orange
      hl(0, "SnacksIndent3", { fg = "#FABD2F" }) -- yellow
      hl(0, "SnacksIndent4", { fg = "#B8BB26" }) -- green
      hl(0, "SnacksIndent5", { fg = "#8EC07C" }) -- aqua
      hl(0, "SnacksIndent6", { fg = "#83A598" }) -- blue
      hl(0, "SnacksIndent7", { fg = "#D3869B" }) -- purple

      -- Snacks picker
      hl(0, "SnacksPickerDir", { fg = "#928374" }) -- grey1

      -- Rainbow delimiters (Arc-en-ciel fidèle à l'image)
      hl(0, "RainbowDelimiter1", { fg = "#FB4934" }) -- red
      hl(0, "RainbowDelimiter2", { fg = "#FE8019" }) -- orange
      hl(0, "RainbowDelimiter3", { fg = "#FABD2F" }) -- yellow
      hl(0, "RainbowDelimiter4", { fg = "#B8BB26" }) -- green
      hl(0, "RainbowDelimiter5", { fg = "#8EC07C" }) -- aqua
      hl(0, "RainbowDelimiter6", { fg = "#83A598" }) -- blue
      hl(0, "RainbowDelimiter7", { fg = "#D3869B" }) -- purple
    end,
  },
}
