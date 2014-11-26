_ = require 'underscore-plus'
{Range, CompositeDisposable}  = require 'atom'
{$, $$, SelectListView}  = require 'atom-space-pen-views'

module.exports =
class AutocompleteView extends SelectListView
  currentBuffer: null
  checkpoint: null
  wordList: null
  wordRegex: /\w+/g
  originalSelectionBufferRanges: null
  originalCursorPosition: null
  aboveCursor: false

  initialize: (@editorView) ->
    super
    @addClass('autocomplete popover-list')
    {@editor} = @editorView
    @handleEvents()
    @setCurrentBuffer(@editor.getBuffer())

  getFilterKey: ->
    'word'

  viewForItem: ({word}) ->
    $$ ->
      @li =>
        @span word

  handleEvents: ->
    @list.on 'mousewheel', (event) -> event.stopPropagation()

    @editorView.on 'editor:path-changed', => @setCurrentBuffer(@editor.getBuffer())

    @subscriptions = new CompositeDisposable
    @subscriptions.add @editor.onDidDestroy => @subscriptions.dispose()
    @subscriptions.add atom.commands.add @editorView.element,
      'autocomplete:toggle': =>
        if @isVisible()
          @cancel()
        else
          @attach()
      'autocomplete:next': => @selectNextItemView()
      'autocomplete:previous': => @selectPreviousItemView()

    @filterEditorView.getModel().on 'will-insert-text', ({cancel, text}) =>
      unless text.match(@wordRegex)
        @confirmSelection()
        @editor.insertText(text)
        cancel()

  setCurrentBuffer: (@currentBuffer) ->

  selectItemView: (item) ->
    super
    if match = @getSelectedItem()
      @replaceSelectedTextWithMatch(match)

  selectNextItemView: ->
    super
    false

  selectPreviousItemView: ->
    super
    false

  getCompletionsForCursorScope: ->
    cursorScope = @editor.scopesForBufferPosition(@editor.getCursorBufferPosition())
    completions = atom.syntax.propertiesForScope(cursorScope, 'editor.completions')
    completions = completions.map (properties) -> _.valueForKeyPath(properties, 'editor.completions')
    _.uniq(_.flatten(completions))

  buildWordList: ->
    wordHash = {}
    if atom.config.get('autocomplete.includeCompletionsFromAllBuffers')
      buffers = atom.project.getBuffers()
    else
      buffers = [@currentBuffer]
    matches = []
    matches.push(buffer.getText().match(@wordRegex)) for buffer in buffers
    wordHash[word] ?= true for word in _.flatten(matches) when word
    wordHash[word] ?= true for word in @getCompletionsForCursorScope() when word

    @wordList = Object.keys(wordHash).sort (word1, word2) ->
      word1.toLowerCase().localeCompare(word2.toLowerCase())

  confirmed: (match) ->
    @editor.getSelections().forEach (selection) -> selection.clear()
    @cancel()
    return unless match
    @replaceSelectedTextWithMatch(match)
    @editor.getCursors().forEach (cursor) ->
      position = cursor.getBufferPosition()
      cursor.setBufferPosition([position.row, position.column + match.suffix.length])

  cancelled: ->
    @overlayMarker?.destroy()

    unless @editor.isDestroyed()
      @editor.revertToCheckpoint(@checkpoint)

      @editor.setSelectedBufferRanges(@originalSelectionBufferRanges)
      @editorView[0].focus() unless document.activeElement is @editorView[0]

  attach: ->
    @checkpoint = @editor.createCheckpoint()

    @aboveCursor = false
    @originalSelectionBufferRanges = @editor.getSelections().map (selection) -> selection.getBufferRange()
    @originalCursorPosition = @editor.getCursorScreenPosition()

    return @cancel() unless @allPrefixAndSuffixOfSelectionsMatch()

    @buildWordList()
    matches = @findMatchesForCurrentSelection()
    @setItems(matches)

    if matches.length is 1
      @confirmSelection()
    else
      @overlayMarker = @editor.markScreenRange([@originalCursorPosition, @originalCursorPosition], reversed: true, invalidate: 'never')
      @editor.decorateMarker(@overlayMarker, type: 'overlay', item: this)

  findMatchesForCurrentSelection: ->
    selection = @editor.getSelection()
    {prefix, suffix} = @prefixAndSuffixOfSelection(selection)

    if (prefix.length + suffix.length) > 0
      regex = new RegExp("^#{prefix}.+#{suffix}$", "i")
      currentWord = prefix + @editor.getSelectedText() + suffix
      for word in @wordList when regex.test(word) and word != currentWord
        {prefix, suffix, word}
    else
      {word, prefix, suffix} for word in @wordList

  replaceSelectedTextWithMatch: (match) ->
    newSelectedBufferRanges = []
    @editor.transact =>
      selections = @editor.getSelections()
      selections.forEach (selection, i) =>
        startPosition = selection.getBufferRange().start
        buffer = @editor.getBuffer()

        selection.deleteSelectedText()
        cursorPosition = @editor.getCursors()[i].getBufferPosition()
        buffer.delete(Range.fromPointWithDelta(cursorPosition, 0, match.suffix.length))
        buffer.delete(Range.fromPointWithDelta(cursorPosition, 0, -match.prefix.length))

        infixLength = match.word.length - match.prefix.length - match.suffix.length

        newSelectedBufferRanges.push([startPosition, [startPosition.row, startPosition.column + infixLength]])

      @editor.insertText(match.word)
      @editor.setSelectedBufferRanges(newSelectedBufferRanges)

  prefixAndSuffixOfSelection: (selection) ->
    selectionRange = selection.getBufferRange()
    lineRange = [[selectionRange.start.row, 0], [selectionRange.end.row, @editor.lineLengthForBufferRow(selectionRange.end.row)]]
    [prefix, suffix] = ["", ""]

    @currentBuffer.scanInRange @wordRegex, lineRange, ({match, range, stop}) ->
      stop() if range.start.isGreaterThan(selectionRange.end)

      if range.intersectsWith(selectionRange)
        prefixOffset = selectionRange.start.column - range.start.column
        suffixOffset = selectionRange.end.column - range.end.column

        prefix = match[0][0...prefixOffset] if range.start.isLessThan(selectionRange.start)
        suffix = match[0][suffixOffset..] if range.end.isGreaterThan(selectionRange.end)

    {prefix, suffix}

  allPrefixAndSuffixOfSelectionsMatch: ->
    {prefix, suffix} = {}

    @editor.getSelections().every (selection) =>
      [previousPrefix, previousSuffix] = [prefix, suffix]

      {prefix, suffix} = @prefixAndSuffixOfSelection(selection)

      return true unless previousPrefix? and previousSuffix?
      prefix is previousPrefix and suffix is previousSuffix

  attached: ->
    @focusFilterEditor()

    widestCompletion = parseInt(@css('min-width')) or 0
    @list.find('span').each ->
      widestCompletion = Math.max(widestCompletion, $(this).outerWidth())
    @list.width(widestCompletion)
    @width(@list.outerWidth())

  detached: ->

  populateList: ->
    super
