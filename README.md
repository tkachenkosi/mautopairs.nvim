# 🧩 mautopairs.nvim

A **minimal**, dependency-free auto-pairs plugin for **Neovim 0.11+**.  
No LSP integration, no external libraries — just smart pairing in pure Lua.

---

## ✨ Features

- Automatically inserts matching pairs:  
  `() [] {} <> '' ""`
- Smart word wrapping:
Menu → "Menu"
web → (web)

- Balances existing pairs to avoid duplicate closings
- Even-count check for partially balanced expressions
- Extensible symbol pairs

---

## 🚀 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
"yourname/mautopairs.nvim",
config = function()
  require("mautopairs").setup()
end
}


require("mautopairs").setup({
  pairs = {
    ["`"] = "`", -- add backtick support
    ["«"] = "»", -- add angled quotes
  },
  debug = false, -- print diagnostics via vim.print()
})

ru:
Минималистичный автопарсер скобок и кавычек для Neovim 0.11+  
Без зависимостей, без LSP, только Lua API.

---

## ✨ Возможности

- Автоматическая вставка парных символов: `() [] {} <> '' ""`
- Умное обрамление слова под курсором:  
---
