{CompositeDisposable, Range, Point, Emitter} = require 'atom'
Highlights = require '../highlights.js'
CONSOLE_URI = 'atom://proto-repl/console'

module.exports =

# Wraps the Atom Ink console to allow it to work with Proto REPL.
class InkConsole
  emitter: null
  subscriptions: null
  ink: null
  console: null
  higlighter: null

  constructor: (@ink)->
    @emitter = new Emitter
    @subscriptions = new CompositeDisposable
    # Register console opener
    @subscriptions.add(atom.workspace.addOpener((uri) =>
      if (uri == CONSOLE_URI)
        @emitter.emit 'proto-repl-ink-console:open'
        return @console
    ))
    @startConsole()
    @highlighter = new Highlights(registry: atom.grammars)

  startConsole: () ->
    # create the console object
    @console = @ink.Console.fromId('proto-repl')
    # overwrite ink's Console title
    TAB_TITLE = 'Proto-REPL'
    @console.getTitle = () -> TAB_TITLE
    @console.emitter.emit('did-change-title', TAB_TITLE)
    # activate and open the console
    @console.activate()
    @console.onEval (ed) => @executeEnteredText ed
    # set console modes
    @console.setModes([
      {name: 'proto-repl', default: true, grammar: 'source.clojure'}
    ])
    @console.destroy = =>
      @emitter.emit 'proto-repl-ink-console:close'
      @console = null

    atom.workspace.open(CONSOLE_URI,
      {
        split: 'right',
        searchAllPanes: true
      })

  # Calls the callback after the text editor has been opened.
  onDidOpen: (callback)->
    # Already open
    callback()

  # Calls the callback after the text editor window has been closed.
  onDidClose: (callback)->
    @emitter.on 'proto-repl-ink-console:close', callback

  # Clears all output and text entry in the REPL.
  clear: ->
    @console.reset()

  # Writes some information to the REPL. Should be used for messages generated by
  # Proto REPL.
  info: (text)->
    @console?.info(text)

  # Writes error messages to the REPL.
  stderr: (text)->
    @console?.stderr(text)

  # Writes standard out produced from a process to the REPL.
  stdout: (text)->
    @console?.stdout(text)

  # Writes results from Clojure execution to the REPL. The results are syntactically
  # highlighted as Clojure code.
  result: (text)->
    html = @highlighter.highlightSync
      fileContents: text
      scopeName: 'source.clojure'

    div = document.createElement('div')
    div.innerHTML = html
    el = div.firstChild

    el.classList.add("proto-repl-console")
    el.style.fontSize = atom.config.get('editor.fontSize') + "px"
    el.style.lineHeight = atom.config.get('editor.lineHeight')

    @console.result(el, {error: false})

  # Displays code that was executed in the REPL adding it to the history.
  displayExecutedCode: (code)->
    inputCell = @console.getInput()
    if not (inputCell.editor.getText())
      inputCell.editor.setText(code)
    @console.logInput()
    @console.done()
    @console.input()

  # Executes the text that was entered in the entry area
  executeEnteredText: (inputCell={}) ->
    editor = @console.getInput().editor
    return null unless editor.getText().trim()
    code = editor.getText()
    # Wrap code in do block so that multiple statements entered at the REPL
    # will execute all of them
    window.protoRepl.executeCode("(do #{code})", displayCode: code)
