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
local line
local wb, wa	-- word left, word right

-- Проверка необходимости вставки парного символа
local function ch_insert(col, open_ch)
  local close_ch = PAIRS[open_ch]
	local isQuoted = open_ch == close_ch

  local left, right = line:sub(1, col), line:sub(col + 1)
	-- count char - количество открывающих и закрывающий скобок
	local lwo, lwc = select(2, left:gsub(vim.pesc(open_ch), "")), select(2, left:gsub(vim.pesc(close_ch), ""))
	local rwc, rwo = select(2, right:gsub(vim.pesc(close_ch), "")), select(2, right:gsub(vim.pesc(open_ch), ""))

  -- Skip: курсор прямо перед закрывающим символом
  if right:sub(1, 1) == close_ch then
    if isQuoted or lwo > lwc then
      return 1				-- одинаковые символы (кавычки) или открытая скобка
    end
  end

  if isQuoted and (lwo % 2 ~= 0 or rwo % 2 ~= 0) then
		-- не четное количество кавычек с любой стороны
		return 1
	end

  if lwo - lwc == 0 and rwc - rwo == 0 then
		-- word left, word right
    -- if #wb > 0 and #wa > 0 then
    if vim.fn.strchars(wb) > 0 and vim.fn.strchars(wa) > 0 then
			-- оборачиваем слово только для двойныых кавычек
			if open_ch == '"' then return 3 else return 1 end
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
  line = vim.api.nvim_get_current_line()
	wb = vim.fn.matchstr(line:sub(1, col), '\\k*$')
	wa = vim.fn.matchstr(line:sub(col + 1), '^\\k*')
  local mode = ch_insert(col, open_ch)

  if mode == 1 then
    return open_ch
  elseif mode == 2 then
		-- вставляем парные символы, курсор между ними
    return open_ch .. close_ch .. "<Left>"
  elseif mode == 3 then
		-- обрамляем слово кавычками
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
