--- referenced from https://github.com/esmuellert/nvim-eslint/blob/main/lua/nvim-eslint/init.lua
--- https://github.com/oxc-project/coc-oxc/blob/main/src/index.ts
--- https://github.com/oxc-project/oxc/blob/main/crates/oxc_language_server/README.md

local M = {}

--- Writes to error buffer.
---@param ... string Will be concatenated before being written
local function err_message(...)
	vim.notify(table.concat(vim.iter({ ... }):flatten():totable()), vim.log.levels.ERROR)
	vim.api.nvim_command("redraw")
end

--- @return table| nil
function M.find_binary(bufnr)
	local path = M.resolve_git_dir(bufnr) .. "/node_modules/.bin/oxc_language_server"

	if vim.loop.fs_stat(path) then
		return { path }
	end

	return nil
end

function M.resolve_git_dir(bufnr)
	local markers = { ".git" }
	local git_dir = vim.fs.root(bufnr, markers)
	return git_dir
end

local oxlint_config_files = {
	"oxlintrc.json",
	".oxlintrc.json",
}

function M.check_config_presence()
	local cwd = vim.fn.getcwd() -- Get the current working directory

	for _, config_file in ipairs(oxlint_config_files) do
		local file_path = cwd .. "/" .. config_file
		if vim.loop.fs_stat(file_path) then
			return true
		end
	end

	return false
end

function M.make_settings(buffer)
	local settings_with_function = {
		run = M.user_config.run or "onType",
		enable = M.user_config.enable or true,
		typeAware = M.user_config.type_aware or false,
		configPath = M.user_config.config_path or ".oxlintrc.json",
		workingDirectory = { mode = "location" },
		workspaceFolder = function(bufnr)
			local git_dir = M.resolve_git_dir(bufnr)
			return {
				uri = vim.uri_from_fname(git_dir),
				name = vim.fn.fnamemodify(git_dir, ":t"),
			}
		end,
	}

	local flattened_settings = {}

	for k, v in pairs(settings_with_function) do
		if type(v) == "function" then
			flattened_settings[k] = v(buffer)
		else
			flattened_settings[k] = v
		end
	end

	return flattened_settings
end

function M.make_client_capabilities()
	local default_capabilities = vim.lsp.protocol.make_client_capabilities()
	default_capabilities.workspace.didChangeConfiguration.dynamicRegistration = true
	return default_capabilities
end

function M.lsp_start()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = vim.tbl_extend("force", {
			"javascript",
			"javascriptreact",
			"javascript.jsx",
			"typescript",
			"typescriptreact",
			"typescript.tsx",
		}, M.user_config.filetypes or {}),
		callback = function(args)
			local lsp_cmd = M.user_config.bin_path or M.find_binary(args.buf)

			local settings = M.make_settings(args.buf)

			vim.lsp.start({
				name = "oxc",
				cmd = lsp_cmd,
				settings = settings,
				-- INFO: we need this to make server start with correct params
				-- https://github.com/oxc-project/oxc/blob/main/crates/oxc_language_server/src/main.rs#L89-L95
				init_options = { settings = settings },
				root_dir = M.user_config.root_dir and M.user_config.root_dir(args.buf) or M.resolve_git_dir(args.buf),
				capabilities = M.user_config.capabilities or M.make_client_capabilities(),
				on_init = function()
					vim.notify("OXC LSP started", vim.log.levels.INFO)
				end,
				handlers = vim.tbl_deep_extend("keep", M.user_config.handlers or {}, {
					["workspace/didChangeConfiguration"] = function(_, result, ctx)
						local function lookup_section(table, section)
							local keys = vim.split(section, ".", { plain = true }) --- @type string[]
							return vim.tbl_get(table, unpack(keys))
						end

						local client_id = ctx.client_id
						local client = vim.lsp.get_client_by_id(client_id)

						if not client then
							err_message(
								"LSP[",
								client_id,
								"] client has shut down after sending a workspace/configuration request"
							)
							return
						end
						if not result.items then
							return {}
						end

						--- Insert custom logic to update client settings
						local new_settings = M.make_settings(args.buf)
						client.settings = new_settings
						--- end custom logic

						local response = {}
						for _, item in ipairs(result.items) do
							if item.section then
								local value = lookup_section(client.settings, item.section)
								-- For empty sections with no explicit '' key, return settings as is
								if value == nil and item.section == "" then
									value = client.settings
								end
								if value == nil then
									value = vim.NIL
								end
								table.insert(response, value)
							end
						end

						return response
					end,
				}),
			})
		end,
	})
end

function M.setup(user_config)
	if user_config then
		M.user_config = user_config
	end

	if M.check_config_presence() then
		M.lsp_start()
	end
end

return M
