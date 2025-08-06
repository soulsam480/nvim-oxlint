## nvim-oxlint
- a lazy vim plugin making use of oxling via lsp server

## references
- referenced from https://github.com/esmuellert/nvim-eslint/blob/main/lua/nvim-eslint/init.lua
- https://github.com/oxc-project/coc-oxc/blob/main/src/index.ts
- https://github.com/oxc-project/oxc/blob/main/crates/oxc_language_server/README.md

## installation
### with Lazy.nvim
```lua
{
  "soulsam480/nvim-oxlint",
  opts = {}
}
```

## Config
- same config as https://github.com/oxc-project/coc-oxc#configurations
- filetypes <- trigger
```lua
{
  "javascript",
  "javascriptreact",
  "javascript.jsx",
  "typescript",
  "typescriptreact",
  "typescript.tsx",
}
```
- root_dir <- default is `.git` parent
- capabilities <- default is default client capabilities
- handlers <- default is config change 

## Example config for diagnostic floating window

This will format the diagnostic floating window in a familiar style and
setup a CursorHold autocommand to trigger the floating window display.

```lua
local function split_string_by_width(text, width)
  local lines = {}
  local current_line = {}
  local space = ' '

  for word in text:gmatch('%S+') do
    if #current_line == 0 then
      table.insert(current_line, word)
    else
      local current_line_string = table.concat(current_line, space)

      if #current_line_string + #space + #word <= width then
        table.insert(current_line, word)
      else
        table.insert(lines, current_line_string)

        current_line = { word }
      end
    end
  end

  if #current_line > 0 then
    table.insert(lines, table.concat(current_line, space))
  end

  return lines
end

local function spacer(num)
  return string.rep(' ', num)
end

local config = function(_, opts)
  require('nvim-oxlint').setup(opts or {})

  vim.api.nvim_create_augroup('DiagnosticFloat', { clear = true })
  vim.api.nvim_create_autocmd('CursorHold', {
    group = 'DiagnosticFloat',
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1

      local diagnostics = vim.diagnostic.get(bufnr, { lnum = lnum })

      if #diagnostics <= 0 then
        return
      end

      local lines = {}
      local max_width = 60

      local doc_url = diagnostics[1].user_data.lsp.codeDescription.href or ''

      max_width = math.max(max_width, #doc_url)

      -- 1, Add the diagnostic message(s)
      for _, d in ipairs(diagnostics) do
        local messages = split_string_by_width(d.message, max_width)

        for _, line in ipairs(messages) do
          table.insert(lines, spacer(1) .. line .. spacer(1))
        end
      end

      -- 2. Add the related information section with diagnostics details
      table.insert(lines, '\n' .. spacer(1) .. 'Related information:\n')

      for _, d in ipairs(diagnostics) do
        local file_path = vim.api.nvim_buf_get_name(0)
        local filename = vim.fn.fnamemodify(file_path, ':t')
        local pos = (d.lnum + 1) .. ',' .. (d.col + 1)

        local item = spacer(3) .. '* ' .. filename .. '#' .. pos .. ':\n'
        local source_code_text = spacer(2) .. '(' .. d.source .. ' ' .. d.code .. ')'

        table.insert(lines, item)
        table.insert(lines, source_code_text)
      end

      -- 3. Add footer with the doc_url
      local separator = string.rep('—', max_width)
      table.insert(lines, spacer(1) .. separator .. spacer(1))

      if doc_url ~= '' then
        table.insert(lines, spacer(1) .. doc_url .. spacer(1))
      end

      vim.lsp.util.open_floating_preview(lines, 'text', {
        focusable = false,
        border = 'none'
      })
    end,
  })
end

return {
  {
    'soulsam480/nvim-oxlint',
    opts = {},
    config = config
  }
}
```
