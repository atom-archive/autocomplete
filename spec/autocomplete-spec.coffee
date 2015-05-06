{$} = require 'atom-space-pen-views'
AutocompleteView = require '../lib/autocomplete-view'
Autocomplete = require '../lib/autocomplete'

describe "Autocomplete", ->
  [workspaceElement, activationPromise] = []

  beforeEach ->
    waitsForPromise ->
      atom.workspace.open('sample.js')

    runs ->
      workspaceElement = atom.views.getView(atom.workspace)
      jasmine.attachToDOM(workspaceElement)
      activationPromise = atom.packages.activatePackage('autocomplete')

  describe "@activate()", ->
    it "activates autocomplete on all existing and future editors (but not on autocomplete's own mini editor)", ->
      spyOn(AutocompleteView.prototype, 'initialize').andCallThrough()

      expect(AutocompleteView.prototype.initialize).not.toHaveBeenCalled()
      atom.workspace.getActivePane().splitRight(copyActiveItem: true)

      [leftEditorElement, rightEditorElement] = workspaceElement.querySelectorAll('atom-text-editor')

      atom.commands.dispatch leftEditorElement, 'autocomplete:toggle'

      waitsForPromise ->
        activationPromise

      waits()

      runs ->
        expect(leftEditorElement.querySelector('.autocomplete')).toExist()
        expect(rightEditorElement.querySelector('.autocomplete')).not.toExist()
        expect(AutocompleteView.prototype.initialize).toHaveBeenCalled()

        atom.commands.dispatch leftEditorElement.querySelector('.autocomplete'), 'core:cancel'

      waits()

      runs ->
        expect(leftEditorElement.querySelector('.autocomplete')).not.toExist()
        atom.commands.dispatch rightEditorElement, 'autocomplete:toggle'

      waits()

      runs ->
        expect(rightEditorElement.querySelector('.autocomplete')).toExist()

  describe "@deactivate()", ->
    it "removes all autocomplete views and doesn't create new ones when new editors are opened", ->
      textEditorElement = workspaceElement.querySelector('atom-text-editor')
      atom.commands.dispatch textEditorElement, "autocomplete:toggle"

      waitsForPromise ->
        activationPromise

      waits()
      runs ->
        expect(textEditorElement.querySelector('.autocomplete')).toExist()
        atom.packages.deactivatePackage('autocomplete')

      waits()
      runs ->
        expect(textEditorElement.querySelector('.autocomplete')).not.toExist()

        atom.workspace.getActivePane().splitRight(copyActiveItem: true)
        atom.commands.dispatch atom.views.getView(atom.workspace.getActivePaneItem()), "autocomplete:toggle"

      waits()
      runs ->
        expect(workspaceElement.querySelector('.autocomplete')).not.toExist()

  describe "confirming an auto-completion", ->
    it "updates the buffer with the selected completion and restores focus", ->
      editor = null

      runs ->
        editor = atom.workspace.getActiveTextEditor()
        editorElement = atom.views.getView(editor)
        editorElement.setUpdatedSynchronously(false)

        editor.getBuffer().insert([10,0] ,"extra:s:extra")
        editor.setCursorBufferPosition([10,7])

        atom.commands.dispatch document.activeElement, 'autocomplete:toggle'

      waitsForPromise -> activationPromise
      waits()

      runs ->
        expect(editor.lineTextForBufferRow(10)).toBe "extra:shift:extra"

        atom.commands.dispatch document.activeElement, 'core:confirm'

      waits()

      runs ->
        expect(editor.lineTextForBufferRow(10)).toBe "extra:shift:extra"

describe "AutocompleteView", ->
  [autocomplete, editor, miniEditor] = []

  beforeEach ->
    waitsForPromise ->
      atom.workspace.open('sample.js').then (anEditor) -> editor = anEditor

    runs ->
      autocomplete = new AutocompleteView(editor)
      miniEditor = autocomplete.filterEditorView

  describe "when the view is attached to the DOM", ->
    it "focuses the filter editor", ->
      jasmine.attachToDOM(autocomplete.element)
      expect(miniEditor).toHaveFocus()

  describe '::attach', ->
    it "adds the autocomplete view as an overlay decoration", ->
      expect(editor.getOverlayDecorations().length).toBe 0
      autocomplete.attach()
      overlayDecorations = editor.getOverlayDecorations()
      expect(overlayDecorations.length).toBe 1
      expect(overlayDecorations[0].properties.item).toBe autocomplete

    describe "when the editor is empty", ->
      it "displays no matches", ->
        editor.setText('')
        expect(editor.getOverlayDecorations().length).toBe 0

        autocomplete.attach()

        overlayDecorations = editor.getOverlayDecorations()
        expect(overlayDecorations.length).toBe 1
        expect(overlayDecorations[0].properties.item).toBe autocomplete

        expect(editor.getText()).toBe ''
        expect(autocomplete.list.find('li').length).toBe 0

    describe "when no text is selected", ->
      it 'autocompletes word when there is only a prefix', ->
        editor.getBuffer().insert([10,0] ,"extra:s:extra")
        editor.setCursorBufferPosition([10,7])
        autocomplete.attach()

        expect(editor.lineTextForBufferRow(10)).toBe "extra:shift:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,11]
        expect(editor.getLastSelection().getBufferRange()).toEqual [[10,7], [10,11]]

        expect(autocomplete.list.find('li').length).toBe 2
        expect(autocomplete.list.find('li:eq(0)')).toHaveText('shift')
        expect(autocomplete.list.find('li:eq(1)')).toHaveText('sort')

      it 'autocompletes word when there is only a suffix', ->
        editor.getBuffer().insert([10,0] ,"extra:n:extra")
        editor.setCursorBufferPosition([10,6])
        autocomplete.attach()

        expect(editor.lineTextForBufferRow(10)).toBe "extra:function:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,13]
        expect(editor.getLastSelection().getBufferRange()).toEqual [[10,6], [10,13]]

        expect(autocomplete.list.find('li').length).toBe 2
        expect(autocomplete.list.find('li:eq(0)')).toHaveText('function')
        expect(autocomplete.list.find('li:eq(1)')).toHaveText('return')

      it 'autocompletes word when there is a single prefix and suffix match', ->
        editor.getBuffer().insert([8,43] ,"q")
        editor.setCursorBufferPosition([8,44])
        autocomplete.attach()

        expect(editor.lineTextForBufferRow(8)).toBe "    return sort(left).concat(pivot).concat(quicksort(right));"
        expect(editor.getCursorBufferPosition()).toEqual [8,52]
        expect(editor.getLastSelection().getBufferRange().isEmpty()).toBeTruthy()

        expect(autocomplete.list.find('li').length).toBe 0

      it "shows all words when there is no prefix or suffix", ->
        editor.setCursorBufferPosition([10, 0])
        autocomplete.attach()

        expect(autocomplete.list.find('li:eq(0)')).toHaveText('0')
        expect(autocomplete.list.find('li:eq(1)')).toHaveText('1')
        expect(autocomplete.list.find('li').length).toBe 22

      it "autocompletes word and replaces case of prefix with case of word", ->
        editor.getBuffer().insert([10,0] ,"extra:SO:extra")
        editor.setCursorBufferPosition([10,8])
        autocomplete.attach()

        expect(editor.lineTextForBufferRow(10)).toBe "extra:sort:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,10]
        expect(editor.getLastSelection().isEmpty()).toBeTruthy()

      it "allows the completion to be undone as a single operation", ->
        editor.getBuffer().insert([10,0] ,"extra:s:extra")
        editor.setCursorBufferPosition([10,7])
        autocomplete.attach()

        editor.undo()

        expect(editor.lineTextForBufferRow(10)).toBe "extra:s:extra"

      describe "when `autocomplete.includeCompletionsFromAllBuffers` is true", ->
        it "shows words from all open buffers", ->
          atom.config.set('autocomplete.includeCompletionsFromAllBuffers', true)

          waitsForPromise ->
            atom.workspace.open('sample.txt')

          runs ->
            editor.getBuffer().insert([10,0] ,"extra:SO:extra")
            editor.setCursorBufferPosition([10,8])
            autocomplete.attach()

            expect(autocomplete.list.find('li').length).toBe 2
            expect(autocomplete.list.find('li:eq(0)')).toHaveText('Some')
            expect(autocomplete.list.find('li:eq(1)')).toHaveText('sort')

      describe 'where many cursors are defined', ->
        it 'autocompletes word when there is only a prefix', ->
          editor.getBuffer().insert([10,0] ,"s:extra:s")
          editor.setSelectedBufferRanges([[[10,1],[10,1]], [[10,9],[10,9]]])
          autocomplete.attach()

          expect(editor.lineTextForBufferRow(10)).toBe "shift:extra:shift"
          expect(editor.getCursorBufferPosition()).toEqual [10,12]
          expect(editor.getLastSelection().getBufferRange()).toEqual [[10,8], [10,12]]

          expect(editor.getSelections().length).toEqual(2)

          expect(autocomplete.list.find('li').length).toBe 2
          expect(autocomplete.list.find('li:eq(0)')).toHaveText('shift')
          expect(autocomplete.list.find('li:eq(1)')).toHaveText('sort')

        describe 'where text differs between cursors', ->
          it 'does not display the autocomplete overlay', ->
            editor.getBuffer().insert([10,0] ,"s:extra:a")
            editor.setSelectedBufferRanges([[[10,1],[10,1]], [[10,9],[10,9]]])
            autocomplete.attach()

            expect(editor.lineTextForBufferRow(10)).toBe "s:extra:a"
            expect(editor.getSelections().length).toEqual(2)
            expect(editor.getSelections()[0].getBufferRange()).toEqual [[10,1], [10,1]]
            expect(editor.getSelections()[1].getBufferRange()).toEqual [[10,9], [10,9]]

            expect(editor.getOverlayDecorations().length).toBe 0

    describe "when text is selected", ->
      it 'autocompletes word when there is only a prefix', ->
        editor.getBuffer().insert([10,0] ,"extra:sort:extra")
        editor.setSelectedBufferRange [[10,7], [10,10]]
        autocomplete.attach()

        expect(editor.lineTextForBufferRow(10)).toBe "extra:shift:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,11]
        expect(editor.getLastSelection().getBufferRange().isEmpty()).toBeTruthy()

        expect(autocomplete.list.find('li').length).toBe 0

      it 'autocompletes word when there is only a suffix', ->
        editor.getBuffer().insert([10,0] ,"extra:current:extra")
        editor.setSelectedBufferRange [[10,6],[10,12]]
        autocomplete.attach()

        expect(editor.lineTextForBufferRow(10)).toBe "extra:concat:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,11]
        expect(editor.getLastSelection().getBufferRange()).toEqual [[10,6],[10,11]]

        expect(autocomplete.list.find('li').length).toBe 7
        expect(autocomplete.list.find('li:contains(current)')).not.toExist()

      it 'autocompletes word when there is a prefix and suffix', ->
        editor.setSelectedBufferRange [[5,7],[5,12]]
        autocomplete.attach()

        expect(editor.lineTextForBufferRow(5)).toBe "      concat = items.shift();"
        expect(editor.getCursorBufferPosition()).toEqual [5,12]
        expect(editor.getLastSelection().getBufferRange().isEmpty()).toBeTruthy()

        expect(autocomplete.list.find('li').length).toBe 0

      it 'replaces selection with selected match, moves the cursor to the end of the match, and removes the autocomplete overlay', ->
        editor.getBuffer().insert([10,0] ,"extra:sort:extra")
        editor.setSelectedBufferRange [[10,7], [10,9]]
        autocomplete.attach()

        expect(editor.lineTextForBufferRow(10)).toBe "extra:shift:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,11]
        expect(editor.getLastSelection().isEmpty()).toBeTruthy()

        expect(editor.getOverlayDecorations().length).toBe 0

      describe "when many ranges are selected", ->
        it 'replaces selection with selected match, moves the cursor to the end of the match, and removes the autocomplete overlay', ->
          editor.getBuffer().insert([10,0] ,"sort:extra:sort")
          editor.setSelectedBufferRanges [[[10,1], [10,3]], [[10,12], [10,14]]]
          autocomplete.attach()

          expect(editor.lineTextForBufferRow(10)).toBe "shift:extra:shift"
          expect(editor.getSelections().length).toEqual(2)
          expect(editor.getOverlayDecorations().length).toBe 0

  describe 'core:confirm event', ->
    describe "where there are matches", ->
      describe "where there is no selection", ->
        it "closes the menu and moves the cursor to the end", ->
          editor.getBuffer().insert([10,0] ,"extra:sh:extra")
          editor.setCursorBufferPosition([10,8])
          autocomplete.attach()

          expect(editor.lineTextForBufferRow(10)).toBe "extra:shift:extra"
          expect(editor.getCursorBufferPosition()).toEqual [10,11]
          expect(editor.getLastSelection().isEmpty()).toBeTruthy()
          expect(editor.getOverlayDecorations().length).toBe 0

  describe 'core:cancel event', ->
    describe "when there are no matches", ->
      it "closes the menu without changing the buffer", ->
        editor.getBuffer().insert([10,0] ,"xxx")
        editor.setCursorBufferPosition [10, 3]
        autocomplete.attach()
        expect(editor.getOverlayDecorations().length).toBe 1
        expect(autocomplete.error).toHaveText "No matches found"

        atom.commands.dispatch miniEditor.element, "core:cancel"

        expect(editor.lineTextForBufferRow(10)).toBe "xxx"
        expect(editor.getCursorBufferPosition()).toEqual [10,3]
        expect(editor.getLastSelection().isEmpty()).toBeTruthy()
        expect(editor.getOverlayDecorations().length).toBe 0

    it 'does not replace selection, removes autocomplete view and returns focus to editor', ->
      editor.getBuffer().insert([10,0] ,"extra:so:extra")
      editor.setSelectedBufferRange [[10,7], [10,8]]
      originalSelectionBufferRange = editor.getLastSelection().getBufferRange()

      autocomplete.attach()
      expect(editor.getOverlayDecorations().length).toBe 1
      editor.setCursorBufferPosition [0, 0] # even if selection changes before cancel, it should work
      atom.commands.dispatch miniEditor.element, "core:cancel"

      expect(editor.lineTextForBufferRow(10)).toBe "extra:so:extra"
      expect(editor.getLastSelection().getBufferRange()).toEqual originalSelectionBufferRange
      expect(editor.getOverlayDecorations().length).toBe 0

    it "does not clear out a previously confirmed selection when canceling with an empty list", ->
      editor.getBuffer().insert([10, 0], "ort\n")
      editor.setCursorBufferPosition([10, 0])

      autocomplete.attach()
      atom.commands.dispatch miniEditor.element, "core:confirm"
      expect(editor.lineTextForBufferRow(10)).toBe 'quicksort'

      editor.setCursorBufferPosition([11, 0])
      autocomplete.attach()
      atom.commands.dispatch miniEditor.element, "core:cancel"
      expect(editor.lineTextForBufferRow(10)).toBe 'quicksort'

    it "restores the case of the prefix to the original value", ->
      editor.getBuffer().insert([10,0] ,"extra:S:extra")
      editor.setCursorBufferPosition([10,7])
      autocomplete.attach()

      expect(editor.lineTextForBufferRow(10)).toBe "extra:shift:extra"
      expect(editor.getCursorBufferPosition()).toEqual [10,11]
      atom.commands.dispatch miniEditor.element, "core:cancel"

      atom.commands.dispatch autocomplete.element, 'core:cancel'
      expect(editor.lineTextForBufferRow(10)).toBe "extra:S:extra"
      expect(editor.getCursorBufferPosition()).toEqual [10,7]

    it "restores the original buffer contents even if there was an additional operation after autocomplete attached (regression)", ->
      editor.getBuffer().insert([10,0] ,"extra:s:extra")
      editor.setCursorBufferPosition([10,7])
      autocomplete.attach()

      editor.getBuffer().append('hi')
      expect(editor.lineTextForBufferRow(10)).toBe "extra:shift:extra"
      atom.commands.dispatch autocomplete.element, 'core:cancel'
      expect(editor.lineTextForBufferRow(10)).toBe "extra:s:extra"

      editor.redo()
      expect(editor.lineTextForBufferRow(10)).toBe "extra:s:extra"

  describe 'move-up event', ->
    it "highlights the previous match and replaces the selection with it", ->
      editor.getBuffer().insert([10,0] ,"extra:t:extra")
      editor.setCursorBufferPosition([10,6])
      autocomplete.attach()

      atom.commands.dispatch miniEditor.element, "core:move-up"
      expect(editor.lineTextForBufferRow(10)).toBe "extra:sort:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(7)')).toHaveClass('selected')

      atom.commands.dispatch miniEditor.element, "core:move-up"
      expect(editor.lineTextForBufferRow(10)).toBe "extra:shift:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(7)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(6)')).toHaveClass('selected')

  describe 'move-down event', ->
    it "highlights the next match and replaces the selection with it", ->
      editor.getBuffer().insert([10,0] ,"extra:s:extra")
      editor.setCursorBufferPosition([10,7])
      autocomplete.attach()

      atom.commands.dispatch miniEditor.element, "core:move-down"
      expect(editor.lineTextForBufferRow(10)).toBe "extra:sort:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).toHaveClass('selected')

      atom.commands.dispatch miniEditor.element, "core:move-down"
      expect(editor.lineTextForBufferRow(10)).toBe "extra:shift:extra"
      expect(autocomplete.find('li:eq(0)')).toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).not.toHaveClass('selected')

  describe "when a match is clicked in the match list", ->
    it "selects and confirms the match", ->
      editor.getBuffer().insert([10,0] ,"t")
      editor.setCursorBufferPosition([10, 0])
      autocomplete.attach()

      matchToSelect = autocomplete.list.find('li:eq(1)')
      matchToSelect.mousedown()
      expect(matchToSelect).toMatchSelector('.selected')
      matchToSelect.mouseup()

      expect(autocomplete.parent()).not.toExist()
      expect(editor.lineTextForBufferRow(10)).toBe matchToSelect.text()

  describe "when the mini-editor receives keyboard input", ->
    beforeEach ->
      # List population is async, so it requires DOM attachment
      jasmine.attachToDOM(autocomplete.element)

    describe "when text is removed from the mini-editor", ->
      it "reloads the match list based on the mini-editor's text", ->
        editor.getBuffer().insert([10,0], "t")
        editor.setCursorBufferPosition([10,0])
        autocomplete.attach()

        expect(autocomplete.list.find('li').length).toBe 8
        miniEditor.getModel().insertText('c')
        window.advanceClock(autocomplete.inputThrottle)
        expect(autocomplete.list.find('li').length).toBe 3
        miniEditor.getModel().backspace()
        window.advanceClock(autocomplete.inputThrottle)
        expect(autocomplete.list.find('li').length).toBe 8

    describe "when the text contains only word characters", ->
      it "narrows the list of completions with the fuzzy match algorithm", ->
        editor.getBuffer().insert([10,0] ,"t")
        editor.setCursorBufferPosition([10,0])
        autocomplete.attach()

        expect(autocomplete.list.find('li').length).toBe 8
        miniEditor.getModel().insertText('i')
        window.advanceClock(autocomplete.inputThrottle)
        expect(autocomplete.list.find('li').length).toBe 4
        expect(autocomplete.list.find('li:eq(0)')).toHaveText 'pivot'
        expect(autocomplete.list.find('li:eq(0)')).toHaveClass 'selected'
        expect(autocomplete.list.find('li:eq(1)')).toHaveText 'right'
        expect(autocomplete.list.find('li:eq(2)')).toHaveText 'shift'
        expect(autocomplete.list.find('li:eq(3)')).toHaveText 'quicksort'
        expect(editor.lineTextForBufferRow(10)).toEqual 'pivot'

        miniEditor.getModel().insertText('o')
        window.advanceClock(autocomplete.inputThrottle)
        expect(autocomplete.list.find('li').length).toBe 2
        expect(autocomplete.list.find('li:eq(0)')).toHaveText 'pivot'
        expect(autocomplete.list.find('li:eq(1)')).toHaveText 'quicksort'

    describe "when a non-word character is typed in the mini-editor", ->
      it "immediately confirms the current completion choice and inserts that character into the buffer", ->
        editor.getBuffer().insert([10,0] ,"t")
        editor.setCursorBufferPosition([10,0])
        autocomplete.attach()
        expect(editor.getOverlayDecorations().length).toBe 1

        miniEditor.getModel().insertText('iv')
        window.advanceClock(autocomplete.inputThrottle)
        expect(autocomplete.list.find('li:eq(0)')).toHaveText 'pivot'

        miniEditor.getModel().insertText(' ')
        window.advanceClock(autocomplete.inputThrottle)
        expect(editor.getOverlayDecorations().length).toBe 0
        expect(editor.lineTextForBufferRow(10)).toEqual 'pivot '

  describe ".cancel()", ->
    it "removes the overlay and clears the mini editor", ->
      autocomplete.attach()
      miniEditor.setText('foo')

      autocomplete.cancel()
      expect(editor.getOverlayDecorations().length).toBe 0
      expect(miniEditor.getText()).toBe ''

  it "sets the width of the view to be wide enough to contain the longest completion without scrolling", ->
    editor.insertText('thisIsAReallyReallyReallyLongCompletion ')
    editor.moveToBottom()
    editor.insertNewline()
    editor.insertText('t')
    autocomplete.attach()
    jasmine.attachToDOM(autocomplete.element)
    expect(autocomplete.list.prop('scrollWidth')).toBeLessThan autocomplete.list.width() + 1
