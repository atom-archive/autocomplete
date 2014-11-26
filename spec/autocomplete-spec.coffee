{EditorView, WorkspaceView} = require 'atom'
{$} = require 'atom-space-pen-views'
AutocompleteView = require '../lib/autocomplete-view'
Autocomplete = require '../lib/autocomplete'

describe "Autocomplete", ->
  [activationPromise] = []

  beforeEach ->
    atom.workspaceView = new WorkspaceView

    waitsForPromise ->
      atom.workspace.open('sample.js')

    runs ->
      atom.workspaceView.simulateDomAttachment()
      activationPromise = atom.packages.activatePackage('autocomplete')

  describe "@activate()", ->
    it "activates autocomplete on all existing and future editors (but not on autocomplete's own mini editor)", ->
      spyOn(AutocompleteView.prototype, 'initialize').andCallThrough()

      expect(AutocompleteView.prototype.initialize).not.toHaveBeenCalled()

      atom.workspaceView.attachToDom()
      leftEditor = atom.workspaceView.getActiveView()
      rightEditor = leftEditor.splitRight()

      atom.commands.dispatch leftEditor.element, 'autocomplete:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(leftEditor.find('.autocomplete')).toExist()
        expect(rightEditor.find('.autocomplete')).not.toExist()
        expect(AutocompleteView.prototype.initialize).toHaveBeenCalled()

        autoCompleteView = leftEditor.find('.autocomplete').view()
        atom.commands.dispatch leftEditor.find('.autocomplete').element, 'core:cancel'
        expect(leftEditor.find('.autocomplete')).not.toExist()

        atom.commands.dispatch rightEditor.element, 'autocomplete:toggle'
        expect(rightEditor.find('.autocomplete')).toExist()

  describe "@deactivate()", ->
    it "removes all autocomplete views and doesn't create new ones when new editors are opened", ->
      atom.workspaceView.attachToDom()
      atom.commands.dispatch atom.workspaceView.getActiveView().element, "autocomplete:toggle"

      waitsForPromise ->
        activationPromise

      runs ->
        expect(atom.workspaceView.getActiveView().find('.autocomplete')).toExist()
        atom.packages.deactivatePackage('autocomplete')
        expect(atom.workspaceView.getActiveView().find('.autocomplete')).not.toExist()
        atom.workspaceView.getActiveView().splitRight()
        atom.commands.dispatch atom.workspaceView.getActiveView().element, "autocomplete:toggle"
        expect(atom.workspaceView.getActiveView().find('.autocomplete')).not.toExist()

describe "AutocompleteView", ->
  [autocomplete, editorView, editor, miniEditor] = []

  beforeEach ->
    atom.workspaceView = new WorkspaceView

    waitsForPromise ->
      atom.workspace.open('sample.js').then (editor) ->
        editorView = new EditorView({editor})

    runs ->
      {editor} = editorView
      autocomplete = new AutocompleteView(editor)
      miniEditor = autocomplete.filterEditorView

  describe '::attach', ->
    it "shows autocomplete view and focuses its mini-editor", ->
      editorView.attachToDom()
      expect(editorView.find('.autocomplete')).not.toExist()

      autocomplete.attach()
      expect(editorView.find('.autocomplete')).toExist()
      expect(autocomplete.editor.isFocused).toBeFalsy()
      expect(autocomplete.filterEditorView.hasFocus()).toBeTruthy()

    describe "when the editor is empty", ->
      it "displays no matches", ->
        editorView.attachToDom()
        editor.setText('')
        expect(editorView.find('.autocomplete')).not.toExist()

        autocomplete.attach()
        expect(editor.getText()).toBe ''
        expect(editorView.find('.autocomplete')).toExist()
        expect(autocomplete.list.find('li').length).toBe 0

    describe "when no text is selected", ->
      it 'autocompletes word when there is only a prefix', ->
        editor.getBuffer().insert([10,0] ,"extra:s:extra")
        editor.setCursorBufferPosition([10,7])
        autocomplete.attach()

        expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,11]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,7], [10,11]]

        expect(autocomplete.list.find('li').length).toBe 2
        expect(autocomplete.list.find('li:eq(0)')).toHaveText('shift')
        expect(autocomplete.list.find('li:eq(1)')).toHaveText('sort')

      it 'autocompletes word when there is only a suffix', ->
        editor.getBuffer().insert([10,0] ,"extra:n:extra")
        editor.setCursorBufferPosition([10,6])
        autocomplete.attach()

        expect(editor.lineForBufferRow(10)).toBe "extra:function:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,13]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,6], [10,13]]

        expect(autocomplete.list.find('li').length).toBe 2
        expect(autocomplete.list.find('li:eq(0)')).toHaveText('function')
        expect(autocomplete.list.find('li:eq(1)')).toHaveText('return')

      it 'autocompletes word when there is a single prefix and suffix match', ->
        editor.getBuffer().insert([8,43] ,"q")
        editor.setCursorBufferPosition([8,44])
        autocomplete.attach()

        expect(editor.lineForBufferRow(8)).toBe "    return sort(left).concat(pivot).concat(quicksort(right));"
        expect(editor.getCursorBufferPosition()).toEqual [8,52]
        expect(editor.getSelection().getBufferRange().isEmpty()).toBeTruthy()

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

        expect(editor.lineForBufferRow(10)).toBe "extra:sort:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,10]
        expect(editor.getSelection().isEmpty()).toBeTruthy()

      it "allows the completion to be undone as a single operation", ->
        editor.getBuffer().insert([10,0] ,"extra:s:extra")
        editor.setCursorBufferPosition([10,7])
        autocomplete.attach()

        editor.undo()

        expect(editor.lineForBufferRow(10)).toBe "extra:s:extra"

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

          expect(editor.lineForBufferRow(10)).toBe "shift:extra:shift"
          expect(editor.getCursorBufferPosition()).toEqual [10,12]
          expect(editor.getSelection().getBufferRange()).toEqual [[10,8], [10,12]]

          expect(editor.getSelections().length).toEqual(2)

          expect(autocomplete.list.find('li').length).toBe 2
          expect(autocomplete.list.find('li:eq(0)')).toHaveText('shift')
          expect(autocomplete.list.find('li:eq(1)')).toHaveText('sort')

        describe 'where text differs between cursors', ->
          it 'cancels the autocomplete', ->
            editor.getBuffer().insert([10,0] ,"s:extra:a")
            editor.setSelectedBufferRanges([[[10,1],[10,1]], [[10,9],[10,9]]])
            autocomplete.attach()

            expect(editor.lineForBufferRow(10)).toBe "s:extra:a"
            expect(editor.getSelections().length).toEqual(2)
            expect(editor.getSelections()[0].getBufferRange()).toEqual [[10,1], [10,1]]
            expect(editor.getSelections()[1].getBufferRange()).toEqual [[10,9], [10,9]]

            expect(editorView.find('.autocomplete')).not.toExist()

    describe "when text is selected", ->
      it 'autocompletes word when there is only a prefix', ->
        editor.getBuffer().insert([10,0] ,"extra:sort:extra")
        editor.setSelectedBufferRange [[10,7], [10,10]]
        autocomplete.attach()

        expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,11]
        expect(editor.getSelection().getBufferRange().isEmpty()).toBeTruthy()

        expect(autocomplete.list.find('li').length).toBe 0

      it 'autocompletes word when there is only a suffix', ->
        editor.getBuffer().insert([10,0] ,"extra:current:extra")
        editor.setSelectedBufferRange [[10,6],[10,12]]
        autocomplete.attach()

        expect(editor.lineForBufferRow(10)).toBe "extra:concat:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,11]
        expect(editor.getSelection().getBufferRange()).toEqual [[10,6],[10,11]]

        expect(autocomplete.list.find('li').length).toBe 7
        expect(autocomplete.list.find('li:contains(current)')).not.toExist()

      it 'autocompletes word when there is a prefix and suffix', ->
        editor.setSelectedBufferRange [[5,7],[5,12]]
        autocomplete.attach()

        expect(editor.lineForBufferRow(5)).toBe "      concat = items.shift();"
        expect(editor.getCursorBufferPosition()).toEqual [5,12]
        expect(editor.getSelection().getBufferRange().isEmpty()).toBeTruthy()

        expect(autocomplete.list.find('li').length).toBe 0

      it 'replaces selection with selected match, moves the cursor to the end of the match, and removes the autocomplete menu', ->
        editor.getBuffer().insert([10,0] ,"extra:sort:extra")
        editor.setSelectedBufferRange [[10,7], [10,9]]
        autocomplete.attach()

        expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
        expect(editor.getCursorBufferPosition()).toEqual [10,11]
        expect(editor.getSelection().isEmpty()).toBeTruthy()
        expect(editorView.find('.autocomplete')).not.toExist()

      describe "when many ranges are selected", ->
        it 'replaces selection with selected match, moves the cursor to the end of the match, and removes the autocomplete menu', ->
          editor.getBuffer().insert([10,0] ,"sort:extra:sort")
          editor.setSelectedBufferRanges [[[10,1], [10,3]], [[10,12], [10,14]]]
          autocomplete.attach()

          expect(editor.lineForBufferRow(10)).toBe "shift:extra:shift"
          expect(editor.getSelections().length).toEqual(2)
          expect(editorView.find('.autocomplete')).not.toExist()

    describe "when the editor is scrolled to the right", ->
      it "does not scroll it to the left", ->
        editorView.width(300)
        editorView.height(300)
        editorView.attachToDom()
        editor.setCursorBufferPosition([6, 6])
        previousScrollLeft = editorView.scrollLeft()
        autocomplete.attach()
        expect(editorView.scrollLeft()).toBe previousScrollLeft

  describe 'core:confirm event', ->
    describe "where there are matches", ->
      describe "where there is no selection", ->
        it "closes the menu and moves the cursor to the end", ->
          editor.getBuffer().insert([10,0] ,"extra:sh:extra")
          editor.setCursorBufferPosition([10,8])
          autocomplete.attach()

          expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
          expect(editor.getCursorBufferPosition()).toEqual [10,11]
          expect(editor.getSelection().isEmpty()).toBeTruthy()
          expect(editorView.find('.autocomplete')).not.toExist()

  describe 'core:cancel event', ->
    describe "when there are no matches", ->
      it "closes the menu without changing the buffer", ->
        editor.getBuffer().insert([10,0] ,"xxx")
        editor.setCursorBufferPosition [10, 3]
        autocomplete.attach()
        expect(autocomplete.error).toHaveText "No matches found"

        atom.commands.dispatch miniEditor.element, "core:cancel"

        expect(editor.lineForBufferRow(10)).toBe "xxx"
        expect(editor.getCursorBufferPosition()).toEqual [10,3]
        expect(editor.getSelection().isEmpty()).toBeTruthy()
        expect(editorView.find('.autocomplete')).not.toExist()

    it 'does not replace selection, removes autocomplete view and returns focus to editor', ->
      editor.getBuffer().insert([10,0] ,"extra:so:extra")
      editor.setSelectedBufferRange [[10,7], [10,8]]
      originalSelectionBufferRange = editor.getSelection().getBufferRange()

      autocomplete.attach()
      editor.setCursorBufferPosition [0, 0] # even if selection changes before cancel, it should work
      atom.commands.dispatch miniEditor.element, "core:cancel"

      expect(editor.lineForBufferRow(10)).toBe "extra:so:extra"
      expect(editor.getSelection().getBufferRange()).toEqual originalSelectionBufferRange
      expect(editorView.find('.autocomplete')).not.toExist()

    it "does not clear out a previously confirmed selection when canceling with an empty list", ->
      editor.getBuffer().insert([10, 0], "ort\n")
      editor.setCursorBufferPosition([10, 0])

      autocomplete.attach()
      atom.commands.dispatch miniEditor.element, "core:confirm"
      expect(editor.lineForBufferRow(10)).toBe 'quicksort'

      editor.setCursorBufferPosition([11, 0])
      autocomplete.attach()
      atom.commands.dispatch miniEditor.element, "core:cancel"
      expect(editor.lineForBufferRow(10)).toBe 'quicksort'

    it "restores the case of the prefix to the original value", ->
      editor.getBuffer().insert([10,0] ,"extra:S:extra")
      editor.setCursorBufferPosition([10,7])
      autocomplete.attach()

      expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
      expect(editor.getCursorBufferPosition()).toEqual [10,11]
      atom.commands.dispatch miniEditor.element, "core:cancel"

      atom.commands.dispatch autocomplete.element, 'core:cancel'
      expect(editor.lineForBufferRow(10)).toBe "extra:S:extra"
      expect(editor.getCursorBufferPosition()).toEqual [10,7]

    it "restores the original buffer contents even if there was an additional operation after autocomplete attached (regression)", ->
      editor.getBuffer().insert([10,0] ,"extra:s:extra")
      editor.setCursorBufferPosition([10,7])
      autocomplete.attach()

      editor.getBuffer().append('hi')
      expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
      atom.commands.dispatch autocomplete.element, 'core:cancel'
      expect(editor.lineForBufferRow(10)).toBe "extra:s:extra"

      editor.redo()
      expect(editor.lineForBufferRow(10)).toBe "extra:s:extra"

  describe 'move-up event', ->
    it "highlights the previous match and replaces the selection with it", ->
      editor.getBuffer().insert([10,0] ,"extra:t:extra")
      editor.setCursorBufferPosition([10,6])
      autocomplete.attach()

      atom.commands.dispatch miniEditor.element, "core:move-up"
      expect(editor.lineForBufferRow(10)).toBe "extra:sort:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(7)')).toHaveClass('selected')

      atom.commands.dispatch miniEditor.element, "core:move-up"
      expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(7)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(6)')).toHaveClass('selected')

  describe 'move-down event', ->
    it "highlights the next match and replaces the selection with it", ->
      editor.getBuffer().insert([10,0] ,"extra:s:extra")
      editor.setCursorBufferPosition([10,7])
      autocomplete.attach()

      atom.commands.dispatch miniEditor.element, "core:move-down"
      expect(editor.lineForBufferRow(10)).toBe "extra:sort:extra"
      expect(autocomplete.find('li:eq(0)')).not.toHaveClass('selected')
      expect(autocomplete.find('li:eq(1)')).toHaveClass('selected')

      atom.commands.dispatch miniEditor.element, "core:move-down"
      expect(editor.lineForBufferRow(10)).toBe "extra:shift:extra"
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
      expect(editor.lineForBufferRow(10)).toBe matchToSelect.text()

  describe "when the mini-editor receives keyboard input", ->
    beforeEach ->
      editorView.attachToDom()

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
        expect(editor.lineForBufferRow(10)).toEqual 'pivot'

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

        miniEditor.getModel().insertText('iv')
        window.advanceClock(autocomplete.inputThrottle)
        expect(autocomplete.list.find('li:eq(0)')).toHaveText 'pivot'

        miniEditor.getModel().insertText(' ')
        window.advanceClock(autocomplete.inputThrottle)
        expect(autocomplete.isVisible()).toBe false
        expect(editor.lineForBufferRow(10)).toEqual 'pivot '

  describe 'when the mini-editor loses focus before the selection is confirmed', ->
    it "cancels the autocomplete", ->
      editorView.attachToDom()
      autocomplete.attach()
      spyOn(autocomplete, "cancel")

      editorView.focus()

      expect(autocomplete.cancel).toHaveBeenCalled()

  describe ".attach()", ->
    beforeEach ->
      editorView.attachToDom()
      setEditorHeightInLines(editorView, 13)
      editorView.resetDisplay() # Ensures the editor only has 13 lines visible

    describe "when the autocomplete view fits below the cursor", ->
      it "adds the autocomplete view to the editor below the cursor", ->
        editor.setCursorBufferPosition [1, 2]
        cursorPixelPosition = editorView.pixelPositionForScreenPosition(editor.getCursorScreenPosition())
        autocomplete.attach()
        expect(editorView.find('.autocomplete')).toExist()

        overlayElement = autocomplete.element.parentElement
        expect(overlayElement.offsetTop).toBe cursorPixelPosition.top + editorView.lineHeight
        expect(overlayElement.offsetLeft).toBe cursorPixelPosition.left

  describe ".cancel()", ->
    it "clears the mini-editor and unbinds autocomplete event handlers for move-up and move-down", ->
      autocomplete.attach()
      miniEditor.setText('foo')

      autocomplete.cancel()
      expect(miniEditor.getText()).toBe ''

      atom.commands.dispatch editorView.element, 'core:move-down'
      expect(editor.getCursorBufferPosition().row).toBe 1

      atom.commands.dispatch editorView.element, 'core:move-up'
      expect(editor.getCursorBufferPosition().row).toBe 0

  it "sets the width of the view to be wide enough to contain the longest completion without scrolling", ->
    editorView.attachToDom()
    editor.insertText('thisIsAReallyReallyReallyLongCompletion ')
    editor.moveCursorToBottom()
    editor.insertNewline()
    editor.insertText('t')
    autocomplete.attach()
    expect(autocomplete.list.prop('scrollWidth')).toBe autocomplete.list.width()

  it "includes completions for the scope's completion preferences", ->
    cssEditorView = null

    waitsForPromise ->
      atom.packages.activatePackage('language-css')

    waitsForPromise ->
      atom.workspace.open('css.css').then (editor) ->
        cssEditorView = new EditorView({editor})

    runs ->
      cssEditor = cssEditorView.getModel()
      autocomplete = new AutocompleteView(cssEditor)

      cssEditorView.attachToDom()
      cssEditor.moveCursorToEndOfLine()
      cssEditor.insertText(' out')
      cssEditor.moveCursorToEndOfLine()

      autocomplete.attach()
      expect(autocomplete.list.find('li').length).toBe 5
      expect(autocomplete.list.find('li:eq(0)')).toHaveText 'outline'
      expect(autocomplete.list.find('li:eq(1)')).toHaveText 'outline-color'
      expect(autocomplete.list.find('li:eq(2)')).toHaveText 'outline-offset'
      expect(autocomplete.list.find('li:eq(3)')).toHaveText 'outline-style'
      expect(autocomplete.list.find('li:eq(4)')).toHaveText 'outline-width'
