{ obj-to-lists, zip, concat-map } = require \prelude-ls
es-generate = (require \escodegen).generate _

ast-errors = require \./esvalid-partial

looks-like-number = (atom-text) ->
  atom-text.match /^\d+(\.\d+)?$/
looks-like-negative-number = (atom-text) ->
  atom-text.match /^-\d+(\.\d+)?$/

class string
  (@content-text) ~>

  text : ->
    return @content-text if not it?
    @content-text := it

  as-sm : ->
    type : \Literal
    value : @content-text
    raw : "\"#{@content-text}\""

  compile : ->
    type : \Literal
    value : @content-text
    raw : "\"#{@content-text}\""

class atom
  (@content-text) ~>

  text : ->
    return @content-text if not it?
    @content-text := it

  is-number: -> (looks-like-number @content-text)
             || (looks-like-negative-number @content-text)

  as-sm : ->
    if @is-number!
      type  : \Literal
      value : Number @content-text
      raw   : @content-text
    else
      type : \ObjectExpression
      properties : [
        type : \Property
        kind : \init
        key :
          type : \Identifier
          name : \atom
        value  :
          type : \Literal
          value : @content-text
          raw : "\"#{@content-text}\""
      ]

  compile : ->

    lit = ~> type : \Literal, value : it, raw : @content-text

    switch @content-text
    | \this  => type : \ThisExpression
    | \null  => lit null
    | \true  => lit true
    | \false => lit false
    | otherwise switch
      | looks-like-number @content-text
        type  : \Literal
        value : Number @content-text
        raw   : @content-text
      | looks-like-negative-number @content-text
        type     : \UnaryExpression
        operator : \-
        prefix   : true
        argument : lit Number @content-text.slice 1 # trim leading minus
      | otherwise
        type : \Identifier
        name : @content-text

class list
  (@content=[]) ~>

  contents : ->
    return @content if not it?
    @content := it

  as-sm : ->
    type : \ArrayExpression elements : @content.map (.as-sm!)

  compile : (parent-macro-table, import-target-macro-tables) ->

    # The import-target-macro-tables argument is for the situation when a macro
    # returns another macro.  In such a case, the returned macro should be
    # added to the tables specified (the scope the macro that created it was
    # in, as well as the scope of other statements during that compile) not to
    # the table representing the scope of the outer macro's contents.

    # If that's confusing, take a few deep breaths and read it again.  Welcome
    # to the blissful land of Lisp, where everything is recursive somehow.

    macro-table = contents : {}, parent : parent-macro-table

    # Recursively search a macro table and its parents for a macro with a given
    # name.  Returns `null` if unsuccessful; a macro representing the function
    # if successful.
    find-macro = (macro-table, name) ->
      switch macro-table.contents[name]
      | null => null                          # deliberately masks parent; fail
      | undefined =>                          # not defined at this level
        if macro-table.parent
          find-macro macro-table.parent, name # ask parent
        else return null                      # no parent to ask; fail
      | otherwise => that                     # defined at this level; succeed

    return null if @content.length is 0

    [ head, ...rest ] = @content

    return null unless head

    if head instanceof atom
    and find-macro macro-table, head.text!

      env = do
        compile = -> # compile to SpiderMonkey AST
          if it.compile?
            it.compile macro-table
          else it
        compile-many = -> it |> concat-map compile |> (.filter (isnt null))
        compile-to-js = -> es-generate it

        {
          compile
          compile-many
          compile-to-js
          macro-table
          import-target-macro-tables
          find-macro
        }

      r = that.apply null, ([ env ] ++ rest)

      check-for-ast-errors = ->
        if ast-errors it
          that.for-each -> console.error it
          #throw Error "Invalid AST"

      if typeof! r is \Array
        r.for-each check-for-ast-errors
      else
        check-for-ast-errors r

      r

    else
      # TODO compile-time check if callee has sensible type
      type : \CallExpression
      callee : head.compile macro-table
      arguments : rest.map (.compile macro-table)

module.exports = { atom, string, list }
