#!python3

import sqlite3


from . import library


db = None


def main(filename):
    global db
    # connection = sqlite3.connect(filename, autocommit=True)
    connection = sqlite3.connect(filename)
    db = connection.cursor()
    library.run()

@library.rpc("query")
def query(q, values=None):
    global db

    values = values or ()
    response = db.execute(q, values)
    return response.fetchall()


@library.rpc("mutation")
def mutate(q, values=None):
    global db

    values = values or ()
    response = db.execute(q, values)
    return response.fetchall()
