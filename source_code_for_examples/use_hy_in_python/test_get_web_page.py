"""Tests for get_web_page.hy, written in Python -- run with:  uv run pytest

These tests are plain Python on purpose: they show that once `hy` is
imported, a Hy module can be imported and tested like any Python module.
"""

import hy  # noqa: F401  -- enables importing .hy modules

import get_web_page


class FakeResponse:
    def __init__(self, body):
        self.body = body

    def read(self):
        return self.body


def test_hy_names_are_mangled_for_python():
    # Hy's get-raw-data-from-web is visible from Python as get_raw_data_from_web
    assert callable(get_web_page.get_raw_data_from_web)
    assert callable(get_web_page.get_web_page_from_disk)


def test_get_raw_data_from_web_sends_user_agent(monkeypatch):
    captured = []

    def fake_urlopen(req):
        captured.append(req)
        return FakeResponse(b"<html>hi</html>")

    monkeypatch.setattr(get_web_page, "urlopen", fake_urlopen)
    assert get_web_page.get_raw_data_from_web("http://example.com") == b"<html>hi</html>"
    req = captured[0]
    assert req.full_url == "http://example.com"
    assert req.get_header("User-agent") == "HyLangBook/1.0"


def test_get_raw_data_from_web_custom_agent(monkeypatch):
    captured = []
    monkeypatch.setattr(
        get_web_page,
        "urlopen",
        lambda req: captured.append(req) or FakeResponse(b""),
    )
    get_web_page.get_raw_data_from_web("http://example.com", {"User-Agent": "Test/2.0"})
    assert captured[0].get_header("User-agent") == "Test/2.0"


def test_get_web_page_from_disk(tmp_path):
    page = tmp_path / "page.html"
    page.write_text("<p>cached</p>")
    assert get_web_page.get_web_page_from_disk(str(page)) == "<p>cached</p>"


def test_main_hy_prints_page(monkeypatch, capsys):
    monkeypatch.setattr(get_web_page, "urlopen", lambda req: FakeResponse(b"page body"))
    get_web_page.main_hy()
    assert "page body" in capsys.readouterr().out
