-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Show diagnostic messages inline, not just as gutter signs/underline
vim.diagnostic.config({ virtual_text = true })

-- Line numbers
vim.opt.number = true

-- No colapsar contexto no modificado en diffs (diffview, vimdiff, fugitive, etc.)
-- vim.opt.diffopt:append("context:999999")

require("lazy").setup({
  -- Colorscheme
  {
    "Mofiqul/vscode.nvim",
    priority = 1000, -- Load before other plugins so it's ready at startup
    config = function()
      vim.o.background = "dark"
      vim.cmd.colorscheme("vscode")
    end,
  },
  -- Package Manager for LSPs
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    opts = {
      ensure_installed = { "clangd" }, -- Automatically downloads clangd
      -- basedpyright is installed via `uv tool install basedpyright`, not
      -- mason (mason's own venv creation needs python3-venv, which this
      -- machine doesn't have) — enabled by hand below instead.
    },
  },
  -- Core LSP Config (no `config` callback here on purpose — see the plain
  -- vim.lsp.config/enable calls below `lazy.setup`, so `:source $MYVIMRC`
  -- + `:LspRestart` can reload them without quitting nvim)
  { "neovim/nvim-lspconfig" },
  -- File tree
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("neo-tree").setup({
	visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
      })
    end,
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle file tree" },
    },
  },
  -- Git diff/history viewer (blame de un archivo entre ramas: DiffviewFileHistory)
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview: diff contra HEAD" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: historial del archivo" },
      {
        "<leader>gb",
        function()
          local file = vim.fn.expand("%")
          local r1 = vim.fn.input("Rama/rev 1: ")
          if r1 == "" then return end
          local r2 = vim.fn.input("Rama/rev 2: ")
          if r2 == "" then return end
          vim.cmd(("DiffviewOpen %s..%s -- %s"):format(r1, r2, file))
        end,
        desc = "Diffview: comparar archivo actual entre 2 ramas",
      },
    },
  },
  {
    'nvim-telescope/telescope.nvim', version = '*',
    dependencies = {
        'nvim-lua/plenary.nvim',
        -- optional but recommended
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    }
  }
})

-- LSP config: plain top-level code (not a plugin `config` callback), so it
-- reruns on every `:source $MYVIMRC`. After editing, `:source $MYVIMRC` then
-- `:LspRestart` picks up changes without restarting nvim.

-- Configure clangd (Nvim 0.11+ native API; mason-lspconfig enables it
-- automatically via vim.lsp.enable() once the server is installed)
vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--header-insertion=iwyu",
    "--completion-style=detailed",
    "--function-arg-placeholders",
    "--fallback-style=llvm",
  },
})

-- basedpyright: root_dir autodetection walks up to the nearest
-- pyproject.toml, so it lands on server/ for this repo. venvPath="."
-- + venv=".venv" (relative to that root_dir) picks up server/.venv,
-- the venv `uv` manages there — portable to any project that follows
-- the same "own .venv at the project root" convention.
-- typeCheckingMode="basic": basedpyright's "standard"/"recommended"
-- defaults enable rules mypy doesn't check at all (reportAny,
-- reportUnusedParameter, reportDeprecated, ...), which is noise here
-- since mypy is this project's actual type checker. "basic" still
-- catches real type errors like reportArgumentType.
vim.lsp.config("basedpyright", {
  settings = {
    basedpyright = {
      analysis = {
        venvPath = ".",
        venv = ".venv",
        typeCheckingMode = "basic",
      },
    },
  },
})
vim.lsp.enable("basedpyright")

-- Frogmouth (lector de Markdown) en una terminal flotante, sin salir de la
-- sesión de nvim. :MDReader abre (o refoca) el archivo actual.
local frogmouth = { buf = nil, win = nil }

local function open_frogmouth()
  if frogmouth.win and vim.api.nvim_win_is_valid(frogmouth.win) then
    vim.api.nvim_set_current_win(frogmouth.win)
    return
  end

  local file = vim.fn.expand("%:p")
  frogmouth.buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  frogmouth.win = vim.api.nvim_open_win(frogmouth.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })
  vim.fn.termopen("frogmouth " .. vim.fn.shellescape(file))
  vim.cmd("startinsert")

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = frogmouth.buf,
    once = true,
    callback = function()
      if frogmouth.win and vim.api.nvim_win_is_valid(frogmouth.win) then
        vim.api.nvim_win_close(frogmouth.win, true)
      end
      frogmouth.buf = nil
      frogmouth.win = nil
    end,
  })
end


vim.api.nvim_create_user_command("MDReader", open_frogmouth, { desc = "Abrir archivo actual en Frogmouth" })

vim.keymap.set("n", "<leader>md", "<cmd>MDReader<cr>", { desc = "Frogmouth: abrir archivo actual" })
