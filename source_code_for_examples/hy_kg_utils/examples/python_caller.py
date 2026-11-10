"""Standalone Python script importing the Hy package hy_kg_utils."""

import hy
from hy_kg_utils import GraphClient, query_to_rows


def main() -> None:
    print("=== Calling hy_kg_utils from plain Python ===")
    client = GraphClient(name="python-caller")
    client.add_many(
        [
            ("python", "imports", "hy_kg_utils"),
            ("hy_kg_utils", "exposes", "GraphClient"),
            ("hy_kg_utils", "exposes", "query_to_rows"),
        ]
    )
    for row in query_to_rows(client):
        print(f"  {row['subject']} --[{row['predicate']}]--> {row['object']}")
    client.close()
    print(f"Client closed: {client.closed}")

    print("\n=== Evaluating a Hy macro from Python via hy.eval ===")
    forms = hy.read_many(
        "(do (require hy_kg_utils [with-graph])"
        "    (import hy_kg_utils.core [query->rows])"
        '    (with-graph [g [#("hy.eval" "runs" "with-graph")]]'
        "      (query->rows g)))"
    )
    print(" ", hy.eval(forms))


if __name__ == "__main__":
    main()
