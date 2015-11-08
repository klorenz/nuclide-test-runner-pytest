import sys
def test_fails():
    sys.stderr.write("stderr\n")
    sys.stdout.write("stdout\n")
    assert False, "fails also"
