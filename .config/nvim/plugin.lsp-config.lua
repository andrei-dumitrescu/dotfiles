local utils = require("utils")
local lspconfig = require('lspconfig')

-- 
-- Format current buffer using "eslint" if active
--

formatBuffer = function()
  local preferred_formatting_clients = { "eslint" }
  local bufnr = vim.api.nvim_get_current_buf()
  local selected_client

  for _, client in ipairs(vim.lsp.get_active_clients()) do
    if vim.tbl_contains(preferred_formatting_clients, client.name) then
      selected_client = client
      break
    end
  end

  if not selected_client then
      return
  end

  local params = vim.lsp.util.make_formatting_params()
  local result, err = selected_client.request_sync("textDocument/formatting", params, 5000, bufnr)

  if err then
    local err_msg = type(err) == "string" and err or err.message
    vim.notify("lsp-config formatting buffer: " .. err_msg, vim.log.levels.WARN)
    return
  end

  if result and result.result then
    vim.lsp.util.apply_text_edits(result.result, bufnr)
  end
end

--
-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
--

local on_attach = function(client, bufnr)
  utils.lua_command("LSPDefinition", "vim.lsp.buf.definition()")
  utils.lua_command("LSPTypeDefinition", "vim.lsp.buf.type_definition()")
  utils.lua_command("LSPRename", "vim.lsp.buf.rename()")
  utils.lua_command("LSPCodeAction", "vim.lsp.buf.code_action()")
  utils.lua_command("LSPPrev", "vim.diagnostic.goto_prev()")
  utils.lua_command("LSPNext", "vim.diagnostic.goto_next()")
  utils.lua_command("LSPLine", "vim.diagnostic.open_float()")
  utils.lua_command("LSPHover", "vim.lsp.buf.hover()")
  utils.lua_command("LSPRefs", "vim.lsp.buf.references()")
  utils.lua_command("LSPImplementation", "vim.lsp.buf.implementation()")
  utils.lua_command("LSPSignatureHelp", "vim.lsp.buf.signature_help()")

  utils.buf_map(bufnr, 'n', '<M-cr>', ':LSPDefinition<CR>')
  utils.buf_map(bufnr, 'n', 'gt', ':LSPTypeDefinition<CR>')
  utils.buf_map(bufnr, 'n', 'gi', ':LSPImplementation<CR>')
  utils.buf_map(bufnr, 'n', 'gr', ':LSPRefs<CR>')
  utils.buf_map(bufnr, 'n', '<Leader>rn', ':LSPRename<CR>')
  utils.buf_map(bufnr, 'n', '<Leader>ca', ':LSPCodeAction<CR>')
  utils.buf_map(bufnr, 'n', '<C-j>', ':LSPNext<CR>')
  utils.buf_map(bufnr, 'n', '<C-k>', ':LSPPrev<CR>')
  utils.buf_map(bufnr, 'n', '<Leader>i', ':LSPLine<CR>')
  utils.buf_map(bufnr, 'n', '<Leader>K', ':LSPHover<CR>')
  utils.buf_map(bufnr, 'n', '<Leader>k', ':LSPSignatureHelp<CR>')

  if client.supports_method("textDocument/formatting") then
    vim.cmd("autocmd BufWritePre <buffer> lua formatBuffer()")
  end
end

-- 
-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
--

for _, server in ipairs({
  'tsserver',
  'eslint',
  'bashls',
  'jsonls',
  'graphql',
  'html',
  'remark_ls'
}) do
    require("lsp-" .. server).setup(on_attach)
end

-- 
-- Customizing how diagnostics are displayed
--

vim.diagnostic.config({
  virtual_text = {
    prefix = "❯",
    spacing = 2,
  },
  float = {
    source = "always" 
  },
  signs = true,
  underline = true,
  update_in_insert = true,
  severity_sort = true,
})

-- 
-- Change diagnostic symbols in the sign column (gutter)
--

for _, type in ipairs({ "Error", "Warn", "Hint", "Info" }) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = "●", texthl = hl, numhl = hl })
end

-- 
-- Go-to definition in a split window
--

local function goto_definition(split_cmd)
  local log = require("vim.lsp.log")

  -- note, this handler style is for neovim 0.5.1/0.6, if on 0.5, call with function(_, method, result)
  local handler = function(_, result, ctx)
    if result == nil or vim.tbl_isempty(result) then
      local _ = log.info() and log.info(ctx.method, "No location found")
      return nil
    end

    if split_cmd then
      vim.cmd(split_cmd)
    end

    if vim.tbl_islist(result) then
      vim.lsp.util.jump_to_location(result[1])

      if #result > 1 then
        vim.lsp.util.set_qflist(vim.lsp.util.locations_to_items(result))
        vim.api.nvim_command("copen")
        vim.api.nvim_command("wincmd p")
      end
    else
      vim.lsp.util.jump_to_location(result)
    end
  end

  return handler
end

vim.lsp.handlers["textDocument/definition"] = goto_definition('split')
