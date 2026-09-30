"""Database and document tools for the forensic agent."""

import re
from typing import Any
import psycopg
from psycopg.rows import dict_row
from langchain_core.tools import tool

from backend.src.config import get_settings

settings = get_settings()

FORBIDDEN_SQL_PATTERNS = re.compile(
    r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|CREATE|GRANT|REVOKE|EXEC|EXECUTE)\b",
    re.IGNORECASE,
)


@tool
def execute_sql_query(query: str) -> dict[str, Any]:
    """Execute a read-only SQL SELECT query against the financial declarations database.

    Args:
        query: A standard PostgreSQL SELECT statement.
    """
    clean_query = query.strip().rstrip(";")

    # Guardrail: Enforce SELECT-only semantics
    if FORBIDDEN_SQL_PATTERNS.search(clean_query):
        return {
            "error": "Security Violation: Non-SELECT or DDL/DML operations are strictly blocked."
        }

    if not clean_query.lower().startswith("select") and not clean_query.lower().startswith("with"):
        return {"error": "Query must start with SELECT or WITH (Common Table Expression)."}

    conninfo = str(settings.DATABASE_URL)
    try:
        with psycopg.connect(conninfo, row_factory=dict_row) as conn:
            with conn.cursor() as cur:
                # Set transaction to read-only for database-level protection
                cur.execute("SET TRANSACTION READ ONLY;")
                cur.execute(clean_query)
                rows = cur.fetchall()
                return {"row_count": len(rows), "rows": rows}
    except Exception as exc:
        return {"error": f"PostgreSQL Execution Error: {str(exc)}"}


@tool
def verify_pdf_exists(filename: str) -> dict[str, Any]:
    """Verify whether a cited declaration PDF file physically exists in local storage.

    Args:
        filename: The base PDF file name (e.g., 'EMP-1049_2024.pdf').
    """
    clean_name = re.sub(r"[^a-zA-Z0-9_\-\.]", "", filename)
    target_path = settings.PDF_STORAGE_PATH / clean_name

    exists = target_path.is_file()
    return {
        "filename": clean_name,
        "exists": exists,
        "absolute_path": str(target_path) if exists else None,
    }


ALL_TOOLS = [execute_sql_query, verify_pdf_exists]