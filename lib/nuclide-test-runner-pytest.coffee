{CompositeDisposable, Disposable, Emitter} = require 'atom'
{spawn} = require('child_process')
path = require 'path'

TEST_ID = 0
TESTRUNS = {}
Status = {
  PASSED: 1
  FAILED: 2
  SKIPPED: 3
  FATAL: 4
  TIMEOUT: 5
}

class PyTestRunner
  constructor: (@projectRoot, @basename=null) ->
    @emitter = new Emitter

  collectTestSummary: (runId, resolve, reject) ->
    # current module name
    module = null
    # buffer unfinished lines
    buffer = ''
    # current lines till line is finished
    current = []

    args = ['--collect-only'].concat @basename? and [ '-k', @basename] or []

    TESTRUNS[runId].currentProcess = pytest =
      spawn 'py.test', args, cwd: @projectRoot

    TESTRUNS[runId].summaryInfo = summaryInfo = []

    pytest.stderr.on 'data', (data) ->
      data = data.toString('utf8')
      console.log "stderr data", data
      @emitter.emit 'stderr-data', {runId, data}

    pytest.stdout.on 'data', (data) ->
      data = data.toString('utf8')

      console.log "stdout data", data

      lines = (buffer + data).split /\r?\n/
      buffer = lines[lines.length-1]
      current = []
      number = 0
      for line in lines[...-1]
        console.log "line", line
        if m = line.match /^<Module '(.*)'>$/
          module = m[1]
        if m = line.match /^\s+<Function '(.*)'>$/
          testInfo = {
            className: module,
            fileName: module,
            id: number++,
            name: m[1],
          }
          console.log testInfo
          summaryInfo.push testInfo
        if m = line.match /^=+\s+ERROR\s+=+$/
          @emitter.emit 'stdout-data', {runId, data}

    pytest.on 'close', (code) ->
      console.log "close", summaryInfo
      resolve(summaryInfo)

    pytest.on 'error', (error) ->
      console.log "error", error
      reject(error)

  runPyTest: (runId) => new Promise (resolve, reject) =>
    args = ['-vvv', '--color=yes'].concat @basename? and [ '-k', @basename] or []

    TESTRUNS[runId].currentProcess = pytest =
      spawn 'py.test', args, cwd: @projectRoot

    summaryInfo = {}
    for info in TESTRUNS[runId].summaryInfo
      summaryInfo["#{info.className}::#{info.name}"] = info

    # buffer unfinished lines
    buffer = ''
    # current lines till line is finished
    current = []

    ESC = String.fromCharCode(0x1B)

    gotOutput = false

    startedTime = new Date().getTime()

    failedTests = {}
    testDetails = []

    pytest.stderr.on 'data', (data) =>
      gotOutput = true

      data = data.toString('utf8')
      console.log "py.test stderr data", data
      @emitter.emit 'stderr-data', {runId, data}
      programStarted = true

    pytest.on 'close', (code) =>
      debugger

      console.log "py.test close", code
      delete TESTRUNS[runId]

    pytest.on 'error', (error) =>
      @emitter.emit 'error', {runId, error}
      console.log "py.test close", error

      unless programStarted
        atom.notifications.addError detail: """
          #{error}

          You might have to install py.test:
            pip install --user pytest
          """, stack: error.stack, dismissable: true

      reject(runId)

    pytest.stdout.on 'end', =>
      for k, testInfo of failedTests
        console.log "end emit", {runId, testInfo}
        @emitter.emit 'did-run-test', {runId, testInfo}
      resolve(runId)

    pytest.stdout.on 'data', (data) =>
      gotOutput = true

      data = data.toString('utf8')

      console.log "py.test stdout data", data

      @emitter.emit 'stdout-data', {runId, data}

      lines = (buffer + data).split /\r?\n/
      buffer = lines[lines.length-1]

      isTests = false
      isFailures = false

      for line in lines[...-1]
        cleanLine = line.replace(/\x33\[\d{1,2}m/g, '')

        console.log "line", line
        console.log "cleanLine", cleanLine

        if not isTests and cleanLine.match /^$/
          isTests = true
          continue

        # after first empty line test really starts
        continue unless isTests

        # failures are listed after FAILURES
        if cleanLine.match /^===+\s+FAILURES\s+===+$/
          isFailures = true
          continue

        if isFailures
          # a failure for a single test run
          if m = cleanLine.match /^___+\s+(.*)\s+__+$/
            # if there was a failure before, test details
            if testDetails.length
              debugger
              _details = testDetails.join("\n")
              _key = "#{fileName}::#{testName}"

              if _key of failedTests
                failedTests["#{fileName}::#{testName}"].details = _details
              else
                console.error "could not find #{_key} in" , failedTests

              testDetails = []

            testName = m[1]
            fileName = null

          if (not fileName?) and (m = cleanLine.match /^((.*):(\d):\s+(.*))/)
            fileName = m[2]

          testDetails.push line
          continue

        if m = cleanLine.match /(.*)\s+(PASSED|FAILED|SKIPPED)$/
          current.push m[1]
          result = m[2]
          testname = current.join("$").replace(/\x1b\[\d{1,2}[m;]/g, '').replace(/^\$/, '').replace(/\$$/, '')
          current = []

          endedTime = new Date().getTime()
          console.log "testname", testname

          testInfo = {
            details: ""
            durationSecs: (endedTime - startedTime) / 1000
            endedTime: endedTime
            name: testname
            numFailures:   result is   "FAILED"  and 1 or 0
            numAssertions: result is   "PASSED"  and 1 or 0
            numMethods:    result isnt "SKIPPED" and 1 or 0
            numSkipped:    result is   "SKIPPED" and 1 or 0
            status: Status[result]
            summary: "this is the summary\nfoo\nbar"
            test_json: summaryInfo[testname]
          }

          debugger

          startedTime = endedTime

          if testInfo.numFailures
            failedTests[testname] = testInfo
          else
            console.log "emit", {runId, testInfo}
            @emitter.emit 'did-run-test', {runId, testInfo}

        else
          current.push line


  run: (path) ->
    console.log "request test for #{path}"

    # this is a hack for having nice ANSI coloring of py.test output
    if p = atom.packages.getActivePackage('language-ansi')
      e = document.querySelector('.nuclide-test-runner-panel atom-text-editor')
      e.getModel().setGrammar(p.grammars[0])

    buffer = ""
    current = []

    runId = ++TEST_ID
    didStart = false

    TESTRUNS[runId] = {
      currentProcess: null
      summaryInfo: null
    }

    summaryInfo = []

    new Promise (resolve, reject) =>
      @collectTestSummary(runId, resolve, reject)
    .then (summaryInfo) =>
      TESTRUNS[runId].summaryInfo = summaryInfo
      @emitter.emit 'did-run-summary', {summaryInfo}
    .then =>
      console.log "did start"
      @emitter.emit 'did-start', runId
      @runPyTest(runId)
    .then =>
      console.log "did end"
      @emitter.emit 'did-end', runId
    .catch (error) =>
      console.log error

    Promise.resolve(runId)

  stop: (runId) ->
    console.log "request stop #{path}"
    @shallStop = true
    @TESTRUNS[runId].currentProcess?.kill('SIGINT')

  onDidStart: (callback) ->
    @emitter.on "did-start", callback

  onDidRunTest: (callback) ->
    @emitter.on "did-run-test", callback

  onDidRunSummary: (callback) ->
    @emitter.on "did-run-summary", callback

  onStdoutData: (callback) ->
    @emitter.on "stdout-data", callback

  onStderrData: (callback) ->
    @emitter.on "stderr-data", callback

  onError: (callback) ->
    @emitter.on "error", callback

  onDidEnd: (callback) ->
    @emitter.on "did-end", callback


# Private: return test class summary object
#
# TestClassSummary =
#    className: string;
#    fileName: string;
#    id: number;
#    name: string;
#
testClassSummary = (obj) -> obj

# TestRunInfo =
#     details?: string;
#     durationSecs: number;
#     endedTime?: number;
#     name: string;
#     numAssertions: number;
#     numFailures: number;
#     numMethods: number;
#     numSkipped: number;
#     status: number;
#     summary?: string;
#     test_json?: TestClassSummary;
#
testRunInfo = (obj) -> obj

module.exports =
  activate: ->
  deactivate: ->

  provideTestRunner: (service) ->
    # runPyTest "--version",
    #   error:

    return {
      label: "py.test"
      getByUri: (uri) ->
        console.log "request test runner for uri #{uri}"

        basepath = null
        for p in atom.project.getPaths()
          if not path.relative(p, uri).match /^\.\./
            basepath = p

        if basepath is null
          return null

        return new PyTestRunner(basepath)
    }
