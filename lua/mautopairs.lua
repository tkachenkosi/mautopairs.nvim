-- mautopairs.nvim — исправленная и расширенная версия
local M = {}

-- 1. Сделаем таблицу опциональной и защищенной от глобальной перезаписи
local default_pairs = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
  ["<"] = ">",
  ['"'] = '"',
  ["'"] = "'",
}

local PAIRS = {}

-- Вспомогательная функция для безопасного подсчета (игнорируем экранирование)
local function count_char(str, char)
  -- vim.pesc защищает от магии Lua, но для простого подсчета достаточно gsub
  -- Если char содержит спецсимволы Lua, они будут экранированы
  return select(2, str:gsub(vim.pesc(char), ""))
end

-- Улучшенная логика вставки
local function ch_insert(line, col, open_char)
  local close_char = PAIRS[open_char]
  -- if not close_char then return 1 end

  local left = line:sub(1, col)
  local right = line:sub(col + 1)

  -- Балансировка: открывающие слева минус закрывающие слева
  local balance_left = count_char(left, open_char) - count_char(left, close_char)
  -- Закрывающие справа минус открывающие справа
  local balance_right = count_char(right, close_char) - count_char(right, open_char)

  local before = line:sub(1, col):match("[%wА-Яа-я_]+$") or ""
  local after = line:sub(col + 1):match("^[%wА-Яа-я_]+") or ""
  local on_word = (#before > 0 and #after > 0)

  -- Если баланс вокруг курсора равен 0, скобок поровну
  if balance_left == 0 and balance_right == 0 then
    if on_word then
      return 3 -- обрамить слово
    end
    return 2 -- вставить пару и сдвинуть курсор
  end

  -- Если справа уже есть закрывающая скобка, просто вставить открывающую
  if right:sub(1, 1) == close_char then
    return 1
  end

  return 2 -- fallback
end

-- Функция обработки удаления (для <BS> и <C-h>)
local function handle_backspace(open_char)
  local close_char = PAIRS[open_char]
  if not close_char then return end

  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()

  -- Проверяем, что прямо перед курсором стоит открывающая скобка,
  -- а сразу после — закрывающая
  if line:sub(col, col) == open_char and line:sub(col + 1, col + 1) == close_char then
    -- Удаляем обе скобки. <C-h> безопаснее <BS> (работает с табами).
    return string.rep("<C-h>", 2)
  end
  return nil
end

local function handle_pair(open_char)
  local close_char = PAIRS[open_char]
  if not close_char then return open_char end

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

    -- Используем <C-h> вместо <BS> для корректной работы с табуляцией
    local del_back = string.rep("<C-h>", #word_before)
    local del_fwd = string.rep("<Del>", #word_after)

    return del_back .. del_fwd .. open_char .. total_word .. close_char
  end

  return open_char
end

function M.setup(options)
  options = options or {}
  -- Корректное слияние таблиц без перезаписи глобальной области модуля
  local pairs_opt = options.pairs or options
  PAIRS = vim.tbl_deep_extend("force", default_pairs, pairs_opt)

  -- 2. Добавляем маппинги на удаление
  vim.keymap.set("i", "<BS>", function()
    local ok, _ = pcall(vim.api.nvim_get_current_line)
    if not ok then return end
    local _, col = unpack(vim.api.nvim_win_get_cursor(0))
    if col == 0 then return end

    local char_before = vim.api.nvim_get_current_line():sub(col, col)
    local result = handle_backspace(char_before)
    if result then
      return result
    end
  end, { expr = true, noremap = true })

  -- 3. Основной маппинг (лучше использовать <expr> только для скобок)
  for open_char, _ in pairs(PAIRS) do
    -- Чтобы не ломать ввод в командной строке, можно добавить buffer = 0
    vim.keymap.set("i", open_char, function()
      return handle_pair(open_char)
    end, { expr = true, noremap = true, replace_keycodes = true })
  end
end

return M

