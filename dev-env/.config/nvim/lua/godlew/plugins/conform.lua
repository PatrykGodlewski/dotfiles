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
    formatters_by_ft = {
      lua = { "stylua" },
      javascript = { "prettierd", "eslint_d", stop_after_first = true },
      typescript = { "prettierd", "eslint_d", stop_after_first = true },
      javascriptreact = { "prettierd", "eslint_d", stop_after_first = true },
      typescriptreact = { "prettierd", "eslint_d", stop_after_first = true },
    },
  },
}
