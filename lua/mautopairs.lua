-- mautopairs.nvim — lightweight auto-pair plugin for Neovim
local M = {}

local PAIRS = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
  ["<"] = ">",
  ['"'] = '"',
  ["'"] = "'",
}

-- Проверка необходимости вставки парного символа (исправлён подсчёт)
local function ch_insert(line, col, open_char)
  local close_char = PAIRS[open_char]

  local left = line:sub(1, col)
  local right = line:sub(col + 1)

  -- Считаем открывающие слева и закрывающие справа (как раньше)
  local left_open = select(2, left:gsub(vim.pesc(open_char), ""))
  local right_close = select(2, right:gsub(vim.pesc(close_char), ""))

  -- Новое: считаем общее кол-во "скобочных" символов в каждой половине
  local left_close = select(2, left:gsub(vim.pesc(close_char), ""))
  local right_open = select(2, right:gsub(vim.pesc(open_char), ""))

  local before = left:match("[%wА-Яа-я_]+$") or ""
  local after = right:match("^[%wА-Яа-я_]+") or ""
  local on_word = (#before > 0 and #after > 0)

	left_open = left_open - left_close
	right_close = right_close - right_open

  -- Если открывающих слева и закрывающих справа равны — старая логика
  if left_open == right_close then
		-- vim.print(left_open,left_close,right_open,right_close,on_word,#before,#after)
    -- курсор внутри слова => обрамление
    if on_word then
      return 3
    end
    return 2
	else
    return 1
  end

end

-- Основная логика вставки (без изменений)
local function handle_pair(open_char)
  local close_char = PAIRS[open_char]
  if not close_char then
    return open_char
  end

  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local mode = ch_insert(line, col, open_char)

  if mode == 1 then
    return open_char
  elseif mode == 2 then
    return open_char .. close_char .. "<Left>"
  elseif mode == 3 then
    local before = line:sub(1, col)
    local after = line:sub(col + 1)
    local word_before = before:match("[%wА-Яа-я_]+$") or ""
    local word_after = after:match("^[%wА-Яа-я_]+") or ""
    local total_word = word_before .. word_after

    local del_back = string.rep("<BS>", #word_before)
    local del_fwd = string.rep("<Del>", #word_after)

    return del_back .. del_fwd .. open_char .. total_word .. close_char
  end

  return open_char
end

function M.setup(options)
	options = options or {}
  local pairs_opt = options.pairs or options

	PAIRS = vim.tbl_deep_extend("force", PAIRS, pairs_opt)

  for open_char, _ in pairs(PAIRS) do
    vim.keymap.set("i", open_char, function()
      return handle_pair(open_char)
    end, { expr = true, noremap = true, replace_keycodes = true })
  end
end

return M

