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

-- подсчет символов
local function count(s, ch)
  local n = 0
  local i = s:find(ch, 1, true)
  while i do
    n = n + 1
    i = s:find(ch, i + 1, true)
  end
  return n
end

-- Основная логика вставки
local function handle_pair(open_ch)
  local close_ch = PAIRS[open_ch]
  if not close_ch then return open_ch end
	local isQuoted = open_ch == close_ch

  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()

  local left, right = line:sub(1, col), line:sub(col + 1)
	-- count char - количество открывающих и закрывающий скобок
	local wol, wcl = count(left, open_ch), count(left, close_ch)
	local wor, wcr = count(right, open_ch), count(right, close_ch)

  -- курсор прямо перед закрывающим символом
  if right:sub(1, 1) == close_ch and (isQuoted or wol > wcl) then
    return open_ch
  end

	-- не четное количество кавычек с любой стороны
  if isQuoted and (wol % 2 ~= 0 or wor % 2 ~= 0) then
    return open_ch
	end

  if wol - wcl == 0 and wcr - wor == 0 then
		-- оборачиваем слово только для двойныых кавычек
		-- local wb	-- подстрока слева вычесляем ниже
		local wa = vim.fn.matchstr(line:sub(col + 1), '^\\k*')
    if wa ~= '' and open_ch ~= "'" then
			-- для оптимизации выделяем подстроку с лева здесь
			local wb = vim.fn.matchstr(line:sub(1, col), '\\k*$')
			if wb ~= '' then
				-- обрамляем слово кавычками
				local del_back = string.rep("<C-h>", vim.fn.strchars(wb))
				local del_fwd  = string.rep("<Del>", vim.fn.strchars(wa))
				return del_back .. del_fwd .. open_ch .. wb .. wa .. close_ch
			end
		end
    return open_ch .. close_ch .. "<Left>"
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
