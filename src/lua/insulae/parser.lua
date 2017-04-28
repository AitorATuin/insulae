------------
-- insulae.parser
-- Defines the insulae cli parser
-- module: insulae.parser
-- author: AitorATuin
-- license: GPL3

local argparse = require 'argparse'

local insulae_cmd = {
  name = {'create', 'c'},
  description = 'Create a new lua insulae',
}

local project_cmd = {
  name = {'project', 'p'},
  description = 'Manage project',
  subcmds = {
    {
      name = {'create', 'c'},
      description = 'Create and initialize a new insulae project'
    },
    {
      name = {'dist', 'd'},
      description = 'Project distribution commands'
    },
    {
      name = {'insulae', 'i'},
      description = 'Project insulae commands',
    }
  }
}

local insulae_parser_spec = {
  name = {'insulae'},
  description = [[
    insulae: tool to manage lua virtual environments and deploy projects on them.
  ]],
  subcmds = {
    insulae_cmd,
    project_cmd
  }
}

--- create_subcommand
-- creates a new command from subcommand_spec into parser
local function create_subcommand(subcommand_spec, parser)
  local name = (subcommand_spec['name'] or {})[1] or nil
  local names = table.concat(subcommand_spec.name or {}, ' ')
  local description = subcommand_spec['description']
  local epilog = subcommand_spec['epilog']
  local subcommands = subcommand_spec.subcmds or {}
  if name then
    local subcommand = parser:command(names, description, epilog)
    return subcommand, subcommands
  end
end

-- create_commands
-- Iterates over all commands in subcommands_spec and creates a new command from them
-- into parser
local function create_commands(subcommands_spec, parser)
  if subcommands_spec and type(subcommands_spec) == 'table' then
    for _, subcommand_spec in ipairs(subcommands_spec) do
      local subcommand, new_subcommands_spec = create_subcommand(subcommand_spec, parser)
      create_commands(new_subcommands_spec, subcommand)
    end
  end
end

-- create_parser
-- Creates and returns a new parser from parser_spec
local function create_parser(parser_spec)
  -- Table to store all the parsers
  local parsers = {}
  -- Get properties for first parser
  local name = parser_spec.name[1]
  local names = table.concat(parser_spec.name, ' ')
  local description = parser_spec.description
  local epilog = parser_spec.epilog
  local subcommands = parser_spec.subcmds or {}
  -- Create a new parser if we have enough data
  if name then
    local parser = argparse(names, description, epilog)
    -- Create subcommands recursively
    create_commands(subcommands, parser) 
    return parser
  end
  return nil, 'Unable to create a parser'
end

local parser = create_parser(insulae_parser_spec)

return parser
