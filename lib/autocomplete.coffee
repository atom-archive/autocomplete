{CompositeDisposable, Disposable} = require 'atom'
_ = require 'underscore-plus'
AutocompleteView = require './autocomplete-view'

module.exports =
  config:
    includeCompletionsFromAllBuffers:
      type: 'boolean'
      default: false

  autocompleteViewsByEditor: null
  deactivationDisposables: null

  activate: ->
    @autocompleteViewsByEditor = new WeakMap
    @deactivationDisposables = new CompositeDisposable

    @deactivationDisposables.add atom.workspace.observeTextEditors (editor) =>
      return if editor.mini

      autocompleteView = new AutocompleteView(editor)
      @autocompleteViewsByEditor.set(editor, autocompleteView)

      disposable = new Disposable => autocompleteView.destroy()
      @deactivationDisposables.add editor.onDidDestroy => disposable.dispose()
      @deactivationDisposables.add disposable

    getAutocompleteView = (editorElement) =>
      @autocompleteViewsByEditor.get(editorElement.getModel())

    @deactivationDisposables.add atom.commands.add 'atom-text-editor:not([mini])',
      'autocomplete:toggle': ->
        getAutocompleteView(this)?.toggle()
      'autocomplete:next': ->
        getAutocompleteView(this)?.selectNextItemView()
      'autocomplete:previous': ->
        getAutocompleteView(this)?.selectPreviousItemView()

  deactivate: ->
    @deactivationDisposables.dispose()
