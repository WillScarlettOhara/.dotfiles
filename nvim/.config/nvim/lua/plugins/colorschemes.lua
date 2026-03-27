local hl = vim.api.nvim_set_hl

-- Snacks indentline
hl(0, "SnacksIndent1", { fg = "#ea6962" })
hl(0, "SnacksIndent2", { fg = "#d8a657" })
hl(0, "SnacksIndent3", { fg = "#458588" })
hl(0, "SnacksIndent4", { fg = "#8ec07c" })
hl(0, "SnacksIndent5", { fg = "#d3869b" })
hl(0, "SnacksIndent6", { fg = "#e78a4e" })
hl(0, "SnacksIndent7", { fg = "#83a598" })

-- Snacks picker
hl(0, "SnacksPickerDir", { fg = "#928374" })

-- Rainbow delimiters
hl(0, "RainbowDelimiter1", { fg = "#ea6962" })
hl(0, "RainbowDelimiter2", { fg = "#d8a657" })
hl(0, "RainbowDelimiter3", { fg = "#458588" })
hl(0, "RainbowDelimiter4", { fg = "#8ec07c" })
hl(0, "RainbowDelimiter5", { fg = "#d3869b" })
hl(0, "RainbowDelimiter6", { fg = "#e78a4e" })
hl(0, "RainbowDelimiter7", { fg = "#83a598" })

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
      vim.g.gruvbox_material_float_style = "bright"
      vim.g.gruvbox_material_statusline_style = "default"
      vim.g.gruvbox_material_cursor = "auto"
      vim.g.gruvbox_material_enable_bold = 1
      vim.g.gruvbox_material_enable_italic = 1
      vim.g.gruvbox_material_diagnostic_virtual_text = "colored"
      vim.cmd("colorscheme gruvbox-material")
      vim.api.nvim_set_hl(0, "SnacksDashboardHeader", { fg = "#83a598", bold = true })
    end,
  },
}
