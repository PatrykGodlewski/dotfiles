return { -- Highlight, edit, and navigate code
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- main branch does not support lazy-loading
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").install({
      "bash",
      "c",
      "diff",
      "html",
      "lua",
      "luadoc",
      "markdown",
      "markdown_inline",
      "query",
      "vim",
      "vimdoc",
    })

    -- Highlighting is provided by Neovim; indentation by nvim-treesitter.
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        if pcall(vim.treesitter.start, args.buf) then
          -- Ruby keeps Vim's regex-based indentation
          if vim.bo[args.buf].filetype ~= "ruby" then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end
      end,
    })
  end,
  -- Related plugins:
  --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
  --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
}
