"""Initialize the orders schema before an API rollout."""
import psycopg


def migrate():
    with psycopg.connect(connect_timeout=5) as conn:
        # Serializes two jobs for this schema, including first-time role creation.
        conn.execute("SELECT pg_advisory_xact_lock(4004)")
        if not conn.execute("SELECT 1 FROM pg_roles WHERE rolname = 'orders_api'").fetchone():
            conn.execute("CREATE ROLE orders_api LOGIN")
        conn.execute("GRANT rds_iam TO orders_api")
        conn.execute("CREATE SCHEMA IF NOT EXISTS orders")
        conn.execute("""
            CREATE TABLE IF NOT EXISTS orders.items (
                id uuid PRIMARY KEY,
                item text NOT NULL CHECK (length(item) BETWEEN 1 AND 120)
            )
        """)
        conn.execute("GRANT USAGE ON SCHEMA orders TO orders_api")
        conn.execute("GRANT SELECT, INSERT ON orders.items TO orders_api")


if __name__ == "__main__":
    migrate()
