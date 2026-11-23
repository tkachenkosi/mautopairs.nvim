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
local function ch_insert2(line, col, open_char)
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

  return 2 -- fallback для скобок
end


-- Логика вставки
local function ch_insert(line, col, open_char)
  local close_char = PAIRS[open_char]
  if not close_char then return 1 end

  -- 1. Строгая логика для кавычек (ваше исправление)
  if open_char == '"' or open_char == "'" then
    -- Если кавычка уже есть в строке где-либо — просто печатаем её
    if line:find(vim.pesc(open_char), 1, true) then
      return 1
    end
    -- Если кавычки нет, но мы внутри слова (test|ing) — тоже просто печатаем
    local before = line:sub(1, col)
    local after = line:sub(col + 1)
    if before:match("%S$") and after:match("^%S") then
      return 1
    end
    -- В остальных случаях (начало строки, после пробела, в пустой строке) — вставляем пару
    return 2
  end

  -- 2. Логика балансировки для скобок
  local left = line:sub(1, col)
  local right = line:sub(col + 1)

  local balance_left = count_char(left, open_char) - count_char(left, close_char)
  local balance_right = count_char(right, close_char) - count_char(right, open_char)

  if balance_left == 0 and balance_right == 0 then
    local before = line:sub(1, col):match("[%wА-Яа-я_]+$") or ""
    local after = line:sub(col + 1):match("^[%wА-Яа-я_]+") or ""
    if #before > 0 and #after > 0 then
      return 3 -- обрамить слово
    end
    return 2 -- вставить пару
  end

  -- Если справа уже стоит закрывающая скобка (например, (|)) — просто печатаем открывающую
  if right:sub(1, 1) == close_char then
    return 1
  end

  return 2 -- fallback для скобок
end

-- Основная обработка
local function handle_pair(open_char)
  local close_char = PAIRS[open_char]
  if not close_char then return open_char end

  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local mode = ch_insert(line, col, open_char)

  -- ВАЖНО: возвращаем управляющие последовательности только для режимов 2 и 3.
  -- Для режима 1 (обычный ввод) возвращаем пустую строку, чтобы не было дублирования символа.
  if mode == 1 then
    -- return open_char
    return ""
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

  -- 3. Основной маппинг (лучше использовать <expr> только для скобок)
  for open_char, _ in pairs(PAIRS) do
    -- Чтобы не ломать ввод в командной строке, можно добавить buffer = 0
    vim.keymap.set("i", open_char, function()
      return handle_pair(open_char)
    end, { expr = true, noremap = true, replace_keycodes = true })
  end
end

return M

