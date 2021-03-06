# Turns an internal AST form into an estree object with reference to the given
# root environment.  Throws error unless the resulting estree AST is valid.

{ concat-map }   = require \prelude-ls
root-macro-table = require \./built-in-macros
statementify     = require \./es-statementify
environment      = require \./env

{ create-transform-macro } = require \./import-macro

{ errors } = require \esvalid

module.exports = (root-env, ast, options={}) ->

  transform-macros = (options.transform-macros || []) .map (func) ->
    isolated-env = environment root-macro-table
    create-transform-macro isolated-env, func

  statements = ast.content

  transform-macros .for-each (macro) ->
    statements := macro.apply null, statements

  program-ast =
    type : \Program
    body : statements
           |> concat-map (.compile root-env)
           |> (.filter (isnt null)) # because macro definitions emit null
           |> (.map statementify)

  err = errors program-ast
  if err.length
    first-error = err.0
    console.error "[Error] #{first-error.message}\n\
                   Node: #{JSON.stringify first-error.node}"
    throw first-error
  else
    return program-ast
