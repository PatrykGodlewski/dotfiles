local function find_config(bufnr, config_files)
  return vim.fs.find(config_files, {
    upward = true,
    stop = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)),
    path = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)),
  })[1]
end

local function biome_or_prettier(bufnr)
  local has_biome_config = find_config(bufnr, { "biome.json", "biome.jsonc" })
  if has_biome_config then
    return { "biome-check", stop_after_first = true }
  end

  local has_prettier_config = find_config(bufnr, {
    ".prettierrc",
    ".prettierrc.json",
    ".prettierrc.yml",
    ".prettierrc.yaml",
    ".prettierrc.json5",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.toml",
    "prettier.config.js",
    "prettier.config.cjs",
  })
  if has_prettier_config then
    return { "prettierd", stop_after_first = true }
  end

  -- Default to Prettier if no config is found
  return { "prettierd", stop_after_first = true }
end

local filetypes_with_dynamic_formatter = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "vue",
  "css",
  "scss",
  "less",
  "html",
  "json",
  "jsonc",
  "yaml",
  "markdown",
  "markdown.mdx",
  "graphql",
  "handlebars",
}

return { -- Autoformat
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>f",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = "",
      desc = "[F]ormat buffer",
    },
  },
  opts = {
    notify_on_error = false,
    format_on_save = {
      timeout_ms = 500,
      lsp_format = "fallback",
    },
    formatters_by_ft = (function()
      local result = {}
      for _, ft in ipairs(filetypes_with_dynamic_formatter) do
        result[ft] = biome_or_prettier
      end

      result.lua = { "stylua" }

      return result
    end)(),
    -- formatters_by_ft = {
    --   lua = { "stylua" },
    --   javascript = { "prettierd", "biome", stop_after_first = true },
    --   typescript = { "prettierd", "biome", stop_after_first = true },
    --   javascriptreact = { "prettierd", "biome", stop_after_first = true },
    --   typescriptreact = { "prettierd", "biome", stop_after_first = true },
    -- },
  },
}
