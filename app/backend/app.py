import os

import mysql.connector
from flask import Flask, g, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)


def get_db():
    if "db" not in g:
        g.db = mysql.connector.connect(
            host=os.environ["MYSQL_HOST"],
            user=os.environ["MYSQL_USER"],
            password=os.environ["MYSQL_PASSWORD"],
            database=os.environ["MYSQL_DATABASE"],
            connection_timeout=5,
        )
    return g.db


@app.teardown_appcontext
def close_db(error=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


@app.errorhandler(mysql.connector.Error)
def database_error(error):
    app.logger.error("Database operation failed: %s", error)
    return jsonify({"message": "Database temporarily unavailable"}), 503


@app.route("/users", methods=["GET"])
def get_users():
    db = get_db()
    with db.cursor(dictionary=True) as cursor:
        cursor.execute("SELECT * FROM users")
        users = cursor.fetchall()
    return jsonify(users)


@app.route("/users", methods=["POST"])
def add_user():
    data = request.get_json()
    db = get_db()
    with db.cursor() as cursor:
        cursor.execute(
            "INSERT INTO users (name, email) VALUES (%s, %s)",
            (data["name"], data["email"]),
        )
    db.commit()
    return jsonify({"message": "User added"}), 201


@app.route("/users/<int:id>", methods=["DELETE"])
def delete_user(id):
    db = get_db()
    with db.cursor() as cursor:
        cursor.execute("DELETE FROM users WHERE id = %s", (id,))
    db.commit()
    return jsonify({"message": "User deleted"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)