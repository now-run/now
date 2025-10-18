module now.nodes.sqlite3;

import std.string : fromStringz, toStringz;

import sqlite;

import now;


MethodsMap sqlite3Methods;

// --------------------------------
class SqliteQuery : Item
{
    Sqlite3 db;
    string sql;
    sqlite3_stmt[] statements;

    this(Sqlite3 db, string sql)
    {
        this.type = ObjectType.Sqlite3Query;
        this.typeName = "sqlite3_query";
        this.db = db;
        this.sql = sql;

        this.parseStatements();
    }

    sqlite3_stmt[] parseStatements()
    {
        char* zSql = cast(char*) sql.toStringz;
        char *zLeftover;
        int rc = SQLITE_OK;

        while (rc == SQLITE_OK && zSql) {
            sqlite3_stmt* pStmt = 0;
            auto rc = sqlite3_prepare_v2(
                db, zSql, -1, &pStmt, &zLeftover
            );
            assert (rc == SQLITE_OK || pStmt == 0);
            if (rc != SQLITE_OK)
            {
                // This is the same as `goto exec_out`:
                break;
            }
            if (pStmt == 0) {
                /* this happens for a comment or white-space */
                zSql = zLeftover;
                continue;
            }
        }
        return statements;
    }

    override ExitCode next(Escopo escopo, Output output)
    {
        int rc;
        // if (!sqlite3SafetyCheckOk(db)) return SQLITE_MISUSE_BKPT;

        sqlite3_mutex_enter(db.mutex);
        // sqlite3Error(db, SQLITE_OK);

        auto statements = parseStatements(sql);

statements_loop:
        foreach (statement; statements)
        {
            string[] columns;
            int[] columnTypes;

            while (true) {
                rc = sqlite3_step(statement);

                // Load column names only once per statement:
                if (columns.length == 0 && rc.among(SQLITE_ROW, SQLITE_DONE))
                {
                    auto nCol = sqlite3_column_count(statement);
                    foreach (i; 0..nCol)
                    {
                        columns ~= sqlite3_column_name(statement, i).to!string;
                        columnTypes ~= sqlite3_column_type(statement, i);
                    }
                }

                // Handle each row
                if (rc == SQLITE_ROW)
                {
                    foreach (i; 0..nCol)
                    {
                        char* value = sqlite3_column_text(statement, i);
                        if (!value && columnTypes[i] != SQLITE_NULL)
                        {
                            sqlite3OomFault(db);
                            rc = sqlite3VdbeFinalize(cast(Vdbe *)statement);
                            break statements_loop;
                        }
                        // TODO: save values already as items!
                        values ~= value.to!string;
                    }
                }
                else
                {
                    rc = sqlite3VdbeFinalize(cast(Vdbe *)statement);
                    zSql = zLeftover.stripLeft;
                    break;
                }
            }
        }

        rc = sqlite3ApiExit(db, rc);
        if (rc != SQLITE_OK)
        {
            auto pzErrMsg = sqlite3DbStrDup(0, sqlite3_errmsg(db));
            if (*pzErrMsg == 0)
            {
                rc = SQLITE_NOMEM_BKPT;
                sqlite3Error(db, SQLITE_NOMEM);
            }
        }

        assert (rc == (rc & db.errMask));
        sqlite3_mutex_leave(db.mutex);

        return rc;
    }
}
// --------------------------------

int dCallback(void *zList, int argc, char **argv, char **azColName)
{
    Dict dict = new Dict();
    foreach (i; 0..argc)
    {
        auto value = argv[i];
        if (value is null)
        {
            dict[azColName[i].to!string] = none;
        }
        else
        {
            dict[azColName[i].to!string] = new String(value.to!string);
        }
    }

    auto list = cast(List)zList;
    list.items ~= dict;
    log("sqlite3.callback: dict=", dict);

    // printf("%s = %s\n", azColName[i], argv[i] ? argv[i] : "NULL");
    // printf("\n");
    return 0;
}

extern(C) static int callback(void *zList, int argc, char **argv, char **azColName)
{
    try
    {
        return dCallback(zList, argc, argv, azColName);
    }
    catch (Exception ex)
    {
        return 1; // ?
    }
}


class Sqlite3 : Item
{
    string path;
    sqlite3* db;

    this(string path)
    {
        this.path = path;
        this.type = ObjectType.Sqlite3;
        this.typeName = "sqlite3";
        this.methods = sqlite3Methods;

        auto rc = sqlite3_open(path.toStringz, &this.db);
        if (rc)
        {
            throw new Exception(
                "Can't open database "
                ~ path
                ~ ": "
                ~ sqlite3_errmsg(this.db).to!string
            );
            // sqlite3_close(this.db);
        }
    }
    override string toString()
    {
        return "sqlite3://" ~ this.path;
    }
    List exec (string command)
    {
        char* zErrMsg;

        List list = new List([]);

        auto rc = sqlite3_exec(
            this.db,
            command.toStringz,
            &callback,
            cast(void*)list,
            &zErrMsg
        );
        if (rc)
        {
            string errorMessage = fromStringz(zErrMsg).to!string;
            sqlite3_free(zErrMsg);

            // sqlite3_close(this.db);

            throw new Exception(
                "Error while exec-ing on database "
                ~ this.path
                ~ ": "
                ~ errorMessage
            );
        }
        return list;
    }
}
