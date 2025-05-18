return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
    "MunifTanjim/nui.nvim",
  },
  lazy = false, -- neo-tree will lazily load itself
  keys = {
    { "\\", ":Neotree reveal<CR>", desc = "NeoTree reveal", silent = true },
  },
  ---@module "neo-tree"
  ---@type neotree.Config?
  opts = {
    window = {
      position = "float",
    },
    filesystem = {
      window = {
        mappings = {
          ["\\"] = "close_window",
        },
      },
    },
  },
}
