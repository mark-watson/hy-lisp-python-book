"""Python test module proving seamless Python -> Hy package interop."""

import hy
import hy_kg_utils
from hy_kg_utils import GraphClient, query_to_rows


def test_python_imports_hy_package():
    client = GraphClient(name="from-python")
    assert client.add("hy", "runs-on", "cpython") is True
    assert client.add_many([("hy", "exports", "wheels"), ("uv", "builds", "wheels")]) == 2

    rows = query_to_rows(client, s="hy")
    assert rows == [
        {"subject": "hy", "predicate": "exports", "object": "wheels"},
        {"subject": "hy", "predicate": "runs-on", "object": "cpython"},
    ]
    client.close()
    assert client.closed is True


def test_hy_name_mangling_and_eval():
    mangled = hy.mangle("query->rows")
    assert mangled == "hyx_query_XgreaterHthan_signXrows"
    assert hy.unmangle(mangled) == "query->rows"
    assert hy.mangle("query-to-rows") == "query_to_rows"
    assert getattr(hy_kg_utils.core, mangled) is query_to_rows

    expr = hy.read_many(
        "(do (require hy_kg_utils [with-graph]) "
        "(import hy_kg_utils.core [query->rows]) "
        '(with-graph [g [#("python" "calls" "hy")]] (query->rows g)))'
    )
    result = hy.eval(expr)
    assert result == [{"subject": "python", "predicate": "calls", "object": "hy"}]
