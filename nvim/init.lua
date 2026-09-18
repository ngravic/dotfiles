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

-- Igualar el tamaño de las ventanas cuando cambia el tamaño de la terminal,
-- para no apretar <C-w>= a mano.
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("resize_equalize", { clear = true }),
  desc = "Reacomodar el layout al redimensionar",
  callback = function()
    local tab = vim.api.nvim_get_current_tabpage()
    vim.cmd("tabdo wincmd =")
    vim.api.nvim_set_current_tabpage(tab)
  end,
})

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

-- Diff entre ramas en repos con layout de worktrees:
--
--   repo-folder/
--     .bare/             <- git dir compartido
--     worktree-rama-1/
--     worktree-rama-n/
--
-- `repo-folder` no está dentro de ningún worktree, así que con nvim abierto ahí
-- diffview no encuentra el repo. `:DiffRamas` resuelve un worktree y se lo pasa
-- a DiffviewOpen con el flag `-C`.

local function git_lines(dir, ...)
  local out = vim.fn.systemlist({ "git", "-C", dir, ... })
  if vim.v.shell_error ~= 0 then return nil end
  return out
end

local function git_toplevel(dir)
  local out = git_lines(dir, "rev-parse", "--show-toplevel")
  if out and out[1] and out[1] ~= "" then return out[1] end
  return nil
end

-- Directorio `.bare` más cercano, buscando hacia arriba desde el cwd.
local function find_bare()
  return vim.fs.find(".bare", {
    upward = true,
    type = "directory",
    path = vim.fn.getcwd(),
    limit = 1,
  })[1]
end

-- Worktrees del repo, sin el bare en sí.
local function list_worktrees(bare)
  local out = git_lines(bare, "worktree", "list", "--porcelain")
  if not out then return {} end
  local list, cur = {}, nil
  for _, line in ipairs(out) do
    local path = line:match("^worktree (.+)$")
    if path then
      cur = { path = path }
      table.insert(list, cur)
    elseif cur then
      local branch = line:match("^branch refs/heads/(.+)$")
      if branch then cur.branch = branch end
      if line == "bare" then cur.bare = true end
    end
  end
  return vim.tbl_filter(function(w) return not w.bare end, list)
end

-- Un dir git cualquiera del proyecto, sin prompts. Para completar ramas.
local function quiet_repo_dir()
  if vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
    local top = git_toplevel(vim.fn.expand("%:p:h"))
    if top then return top end
  end
  return git_toplevel(vim.fn.getcwd()) or find_bare()
end

-- Dir donde correr diffview. Vía callback: elegir worktree puede pedir input.
local function resolve_repo(head, cb)
  -- 1. El archivo del buffer actual, si vive dentro de un worktree.
  if vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
    local top = git_toplevel(vim.fn.expand("%:p:h"))
    if top then return cb(top) end
  end

  -- 2. El cwd, si ya es un worktree.
  local top = git_toplevel(vim.fn.getcwd())
  if top then return cb(top) end

  -- 3. Layout de worktrees: elegir un hermano del `.bare`.
  local bare = find_bare()
  if not bare then
    vim.notify("DiffRamas: no hay repo git ni .bare acá", vim.log.levels.ERROR)
    return
  end

  local wts = list_worktrees(bare)
  if #wts == 0 then
    vim.notify("DiffRamas: el .bare no tiene worktrees", vim.log.levels.ERROR)
    return
  end
  if #wts == 1 then return cb(wts[1].path) end

  -- Con dos revs commiteados el worktree da igual: comparten el object store.
  -- Igual preferimos el de `head`. Sin `head` el diff es contra el working
  -- tree, así que ahí la elección importa y preguntamos.
  if head and head ~= "" then
    for _, w in ipairs(wts) do
      if w.branch == head then return cb(w.path) end
    end
    return cb(wts[1].path)
  end

  vim.ui.select(wts, {
    prompt = "Worktree:",
    format_item = function(w)
      local name = vim.fn.fnamemodify(w.path, ":t")
      return w.branch and (name .. " (" .. w.branch .. ")") or name
    end,
  }, function(choice)
    if choice then cb(choice.path) end
  end)
end

vim.api.nvim_create_user_command("DiffRamas", function(opts)
  local base, head = opts.fargs[1], opts.fargs[2]

  if not base then
    base = vim.fn.input("Base: ")
    if base == "" then return end
    head = vim.fn.input("Head (vacío = working tree): ")
  end

  resolve_repo(head, function(repo)
    -- `base...head` (tres puntos) diffea contra el merge-base: muestra solo lo
    -- que cambió en head, sin lo que avanzó base mientras tanto.
    local range = (head and head ~= "") and (base .. "..." .. head) or base
    vim.cmd(("DiffviewOpen -C%s %s"):format(vim.fn.fnameescape(repo), range))
  end)
end, {
  nargs = "*",
  complete = function(lead)
    local dir = quiet_repo_dir()
    if not dir then return {} end
    local refs = git_lines(dir, "for-each-ref", "--format=%(refname:short)",
      "refs/heads", "refs/remotes") or {}
    return vim.tbl_filter(function(r) return r:find(lead, 1, true) == 1 end, refs)
  end,
  desc = "Diffview: archivos cambiados entre dos ramas (layout de worktrees)",
})

vim.keymap.set("n", "<leader>gD", "<cmd>DiffRamas<cr>", { desc = "Diffview: diff entre ramas" })
