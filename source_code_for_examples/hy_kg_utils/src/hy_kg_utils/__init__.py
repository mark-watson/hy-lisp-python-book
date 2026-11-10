"""hy_kg_utils: tiny knowledge-graph helpers written in Hy."""

import hy  # register the .hy import hook before importing Hy modules

from hy_kg_utils.core import GraphClient, MaybeStr, Row, Triple, query_to_rows

hy.macros.require("hy_kg_utils.macros", None, assignments="EXPORTS")

__version__ = "0.1.0"
__all__ = ["GraphClient", "MaybeStr", "Row", "Triple", "query_to_rows", "__version__"]
