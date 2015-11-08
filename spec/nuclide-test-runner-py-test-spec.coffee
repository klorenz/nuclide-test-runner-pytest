NuclideTestRunnerPyTest = require '../lib/nuclide-test-runner-pytest'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "NuclideTestRunnerPyTest", ->
  [workspaceElement, activationPromise] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    activationPromise = atom.packages.activatePackage('nuclide-test-runner-py-test')

  describe "when the nuclide-test-runner-py-test:toggle event is triggered", ->
    it "hides and shows the modal panel", ->
      # Before the activation event the view is not on the DOM, and no panel
      # has been created
      expect(workspaceElement.querySelector('.nuclide-test-runner-py-test')).not.toExist()

      # This is an activation event, triggering it will cause the package to be
      # activated.
      atom.commands.dispatch workspaceElement, 'nuclide-test-runner-py-test:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(workspaceElement.querySelector('.nuclide-test-runner-py-test')).toExist()

        nuclideTestRunnerPyTestElement = workspaceElement.querySelector('.nuclide-test-runner-py-test')
        expect(nuclideTestRunnerPyTestElement).toExist()

        nuclideTestRunnerPyTestPanel = atom.workspace.panelForItem(nuclideTestRunnerPyTestElement)
        expect(nuclideTestRunnerPyTestPanel.isVisible()).toBe true
        atom.commands.dispatch workspaceElement, 'nuclide-test-runner-py-test:toggle'
        expect(nuclideTestRunnerPyTestPanel.isVisible()).toBe false

    it "hides and shows the view", ->
      # This test shows you an integration test testing at the view level.

      # Attaching the workspaceElement to the DOM is required to allow the
      # `toBeVisible()` matchers to work. Anything testing visibility or focus
      # requires that the workspaceElement is on the DOM. Tests that attach the
      # workspaceElement to the DOM are generally slower than those off DOM.
      jasmine.attachToDOM(workspaceElement)

      expect(workspaceElement.querySelector('.nuclide-test-runner-py-test')).not.toExist()

      # This is an activation event, triggering it causes the package to be
      # activated.
      atom.commands.dispatch workspaceElement, 'nuclide-test-runner-py-test:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        # Now we can test for view visibility
        nuclideTestRunnerPyTestElement = workspaceElement.querySelector('.nuclide-test-runner-py-test')
        expect(nuclideTestRunnerPyTestElement).toBeVisible()
        atom.commands.dispatch workspaceElement, 'nuclide-test-runner-py-test:toggle'
        expect(nuclideTestRunnerPyTestElement).not.toBeVisible()
