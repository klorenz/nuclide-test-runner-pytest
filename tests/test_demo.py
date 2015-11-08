def test_passes():
    assert True, "This passes :)"

def test_fails():
    assert False, "This fails :)"

import pytest

@pytest.mark.skipif(True, reason="for some reason")
def test_is_skipped():
    assert False, "this should not run"
