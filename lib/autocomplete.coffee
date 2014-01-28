{_} = require 'atom'
AutocompleteView = deferredRequire './autocomplete-view'

module.exports =
  configDefaults:
    includeCompletionsFromAllBuffers: false

  autocompleteViews: {}
  commandSubscription: null

  activate: ->
    @commandSubscription = atom.workspaceView.command 'autocomplete:attach', '.editor:not(.mini)', =>
      editor = atom.workspaceView.getActiveView()
      @autocompleteViews[editor.id] ?= new AutocompleteView(editor, this)
      @autocompleteViews[editor.id].attach()

  deactivate: ->
    @commandSubscription.off()
    view.remove() for editorId, view of @autocompleteViews
    @autocompleteViews = {}
