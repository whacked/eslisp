# Serves as an adapter from the S-expression parser's format to the internal
# AST objects.

parse-sexpr = require \sexpr-plus .parse
{ list, atom, string } = require \./ast

convert = (tree) ->
  switch tree.type
  | \list   => list   tree.content.map convert
  | \atom   => atom   tree.content
  | \string => string tree.content
  | null    => throw Error "Unexpected type `#that` (of `#tree`)"

module.exports = parse-sexpr >> convert
