---
name: gv-api-db
description: Query the gv-api Postgres database (the one `make gv-api-pgcli` opens) running on the lab box. Use when asked to look at, inspect, count, debug or change data/schema in the gv-api DB, or anything involving "gv-api" + database/tables/pgcli/SQL.
---

# gv-api database access

`gv-api-sql` (in `~/.local/bin`) pipes SQL over ssh into `psql` inside the `db`
container of `/home/ocp/docker/gv/gv-api` on `ssh.lab-ocp.com` (postgres 15, DB `gv-db`).
It is the non-interactive equivalent of `make gv-api-pgcli` from `~`.

```bash
gv-api-sql '\dt'                                  # list tables
gv-api-sql '\d+ some_table'                       # describe a table
gv-api-sql 'select count(*) from some_table'
gv-api-sql <<'SQL'
select ... ;
select ... ;
SQL
```

- **Read-only by default** (`default_transaction_read_only=on`): writes fail with
  `cannot execute ... in a read-only transaction`.
- `gv-api-sql --write "..."` allows INSERT/UPDATE/DELETE/DDL. Only use it when the user
  explicitly asked for that change; show the exact statement first and prefer wrapping
  it in `begin; ... ; commit;`.
- `ON_ERROR_STOP` is on: the first error aborts the batch with a non-zero exit.
- Add `limit` to exploratory selects; for wide rows use `\x on` as the first line.
- Explore the schema (`\dt`, `\d table`) before guessing table or column names.
