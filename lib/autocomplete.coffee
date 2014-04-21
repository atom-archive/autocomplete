_ = require 'underscore-plus'
AutocompleteView = require './autocomplete-view'
Provider = require "./provider"
Suggestion = require "./suggestion"

module.exports =
  configDefaults:
    includeCompletionsFromAllBuffers: false

  autocompleteViews: []
  editorSubscription: null

  activate: ->
    @editorSubscription = atom.workspaceView.eachEditorView (editor) =>
      if editor.attached and not editor.mini
        autocompleteView = new AutocompleteView(editor)
        editor.on 'editor:will-be-removed', =>
          autocompleteView.remove() unless autocompleteView.hasParent()
          autocompleteView.dispose()
          _.remove(@autocompleteViews, autocompleteView)
        @autocompleteViews.push(autocompleteView)

  deactivate: ->
    @editorSubscription?.off()
    @editorSubscription = null
    @autocompleteViews.forEach (autocompleteView) =>
      autocompleteView.remove()
      autocompleteView.dispose()
    @autocompleteViews = []

  ###
   * Finds the autocomplete view for the given EditorView
   * and registers the given provider
   * @param  {Provider} provider
   * @param  {EditorView} editorView
  ###
  registerProviderForEditorView: (provider, editorView) ->
    autocompleteView = _.findWhere @autocompleteViews, editorView: editorView
    unless autocompleteView?
      throw new Error("Could not register provider", provider.constructor.name)

    autocompleteView.registerProvider provider

  ###
   * Finds the autocomplete view for the given EditorView
   * and unregisters the given provider
   * @param  {Provider} provider
   * @param  {EditorView} editorView
  ###
  unregisterProvider: (provider) ->
    view.unregisterProvider for view in @autocompleteViews

  Provider: Provider
  Suggestion: Suggestion
