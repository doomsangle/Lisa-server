import sqlite3
import os
import threading
from contextlib import contextmanager
from .config import get_settings

settings = get_settings()
os.makedirs(os.path.dirname(os.path.abspath(settings.DB_PATH)), exist_ok=True)

_local = threading.local()


def _dict_row_factory(cursor, row):
    return {cursor.description[i][0]: row[i] for i in range(len(cursor.description))}


def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(settings.DB_PATH, check_same_thread=False, timeout=30.0)
    conn.row_factory = _dict_row_factory
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


@contextmanager
def get_conn():
    conn = getattr(_local, "conn", None)
    if conn is None:
        conn = _connect()
        _local.conn = conn
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
