-- mautopairs.nvim — lightweight auto-pair plugin for Neovim
local M = {}

local default_pairs = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
  ['"'] = '"',
  ["'"] = "'",
  -- ["<"] = ">",  -- убрано: конфликтует с операторами сравнения
}

local PAIRS = {}

local function count_char(str, char)
  return select(2, str:gsub(vim.pesc(char), ""))
end

local function word_left(line, col)
  return vim.fn.matchstr(line:sub(1, col), '\\k*$')
end

local function word_right(line, col)
  return vim.fn.matchstr(line:sub(col + 1), '^\\k*')
end

-- Проверка необходимости вставки парного символа
local function ch_insert(line, col, open_ch)
  local close_ch = PAIRS[open_ch]

  local left  = line:sub(1, col)
  local right = line:sub(col + 1)
	local wo, wc = select(2, left:gsub(vim.pesc(open_ch), "")), select(2, left:gsub(vim.pesc(close_ch), ""))

  -- Skip: курсор прямо перед закрывающим символом
  if right:sub(1, 1) == close_ch then
    if open_ch == close_ch then
      return 1                                -- одинаковые символы (кавычки)
    end
    if wo > wc then
      return 1                                -- есть «открытая» скобка
    end
  end

  local bal_l = wo  - wc
  local bal_r = count_char(right, close_ch) - count_char(right, open_ch)

  if bal_l == 0 and bal_r == 0 then
    local wb, wa = word_left(line, col), word_right(line, col)
    if #wb > 0 and #wa > 0 then
			return 3
		end
    return 2
  end

  return 1
end

-- Основная логика вставки
local function handle_pair(open_ch)
  local close_ch = PAIRS[open_ch]
  if not close_ch then return open_ch end

  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local mode = ch_insert(line, col, open_ch)

  if mode == 1 then
    return open_ch
  elseif mode == 2 then
    return open_ch .. close_ch .. "<Left>"
  elseif mode == 3 then
    local wb = word_left(line, col)
    local wa = word_right(line, col)
    local del_back = string.rep("<C-h>", vim.fn.strchars(wb))
    local del_fwd  = string.rep("<Del>", vim.fn.strchars(wa))
    return del_back .. del_fwd .. open_ch .. wb .. wa .. close_ch
  end
  return open_ch
end

function M.setup(options)
  options = options or {}

  -- Явный парсинг опций: ожидаем { pairs = {...}, ... }
  local user_pairs = options.pairs
  if not user_pairs then
    -- поддержка плоского формата (backward-compat): { ["("] = ")", ... }
    user_pairs = {}
    for k, v in pairs(options) do
      if type(k) == "string" and #k == 1 and type(v) == "string" and #v == 1 then
        user_pairs[k] = v
      end
    end
  end

  PAIRS = vim.tbl_extend("force", default_pairs, user_pairs)

  for open_ch in pairs(PAIRS) do
    vim.keymap.set("i", open_ch, function()
      return handle_pair(open_ch)
    end, { expr = true, replace_keycodes = true })
  end

end

return M
