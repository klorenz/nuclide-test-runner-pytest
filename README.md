# nuclide-test-runner-pytest package

This is a [py.test](http://pytest.org) test runner plugin for Atom.  This plugin cannot run
on its own.  It is a test runner service provider for
[Nuclide IDE's Test Runner](https://atom.io/packages/nuclide-test-runner).

![Screenshot](https://raw.githubusercontent.com/klorenz/nuclide-test-runner-pytest/master/screenshot.png)

If you want to run  tests in atom, you have to install nuclide-test-runner also:

```shell
    apm install nuclide-test-runner
```

You do not need other nuclide packages.

For best experience, you also should install
[language-ansi](https://atom.io/packages/language-ansi):
```shell
    apm install language-ansi
```

The shipped ANSI highlighting of nuclide test runner has bugs.
