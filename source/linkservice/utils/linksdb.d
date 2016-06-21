module linkservice.utils.linksdb;

import std.format, std.datetime;
import d2sqlite3;

import linkservice.models;
import linkservice.common;

const static TABLE_NAME = "LINKS";
const static COLUMN_LINK_ID = "LINK_ID";
const static COLUMN_CATEGORY = "CATEGORY";
const static COLUMN_IS_ARCHIVED = "IS_ARCHIVED";
const static COLUMN_IS_FAVORITE = "IS_FAVORITE";
const static COLUMN_TIMESTAMP = "TIMESTAMP";
const static COLUMN_TITLE = "TITLE";
const static COLUMN_URL = "URL";
const static COLUMN_USER_ID = "USER_ID";

class LinksDb {
    Database sqliteDb;

    this(Database database){
        sqliteDb = database;
    }

    LinksList readDatabase(long userId) {
        LinksList linksList;

        string query = format("SELECT * FROM LINKS WHERE %s = %d", COLUMN_USER_ID, userId);
        ResultRange results = sqliteDb.execute(query);
        foreach (Row row; results) {
            Link rowLink = getLinkFromRow(row);
            debugfln("ID: %2d, USER: %2d, Timestamp: %s, Title: %s, URL: %s, Category: %s",
                    rowLink.linkId,
                    userId,
                    SysTime(unixTimeToStdTime(rowLink.timestamp)),
                    rowLink.title,
                    rowLink.url,
                    rowLink.category);
            linksList.linksList ~= rowLink;
        }
        return linksList;
    }

    Link getLink(long userId, long linkId) {
        // TODO: Perform validation for user etc
        string query = format("SELECT * FROM %s WHERE %s = %d AND %s = %d;",
            TABLE_NAME,
            COLUMN_USER_ID,
            userId,
            COLUMN_LINK_ID,
            linkId);

        debugfln("Query: %s", query);

        try {
            ResultRange results = sqliteDb.execute(query);
            foreach (Row row; results) {
                return getLinkFromRow(row);
            }
        } catch (SqliteException e) {
            errorfln("ERROR WHEN SELECTING LINK ", e.msg);
        }

        throw new LinkNotFoundException(format("Could not find Link with LinkId: %d", linkId));
    }

    bool deleteLink(long userId, long linkId) {
        // TODO: Perform validation for user etc
        string query = format("DELETE FROM %s WHERE %s = %d;",
            TABLE_NAME,
            COLUMN_LINK_ID,
            linkId);

        debugfln("Query: %s", query);

        try {
            Statement statement = sqliteDb.prepare(query);
            statement.execute();
            return true;
        } catch (SqliteException e) {
            errorfln("ERROR WHEN DELETING LINK ", e.msg);
        }

        return false;
    }

    Link insertLink(long userId, Link link) {
        debugfln("Inserting: %s", link.url);
        // Inserts will always ignore the link ID
        string insert = format("INSERT INTO %s (%s, %s, %s, %s)",
                               TABLE_NAME,
                               COLUMN_USER_ID,
                               COLUMN_URL,
                               COLUMN_TITLE,
                               COLUMN_CATEGORY);
        string values = format("VALUES(:%s, :%s, :%s, :%s);",
                               COLUMN_USER_ID,
                               COLUMN_URL,
                               COLUMN_TITLE,
                               COLUMN_CATEGORY);

        string query = "SELECT * FROM %s WHERE %s = last_insert_rowid();";
        debugfln("Query: %s %s", insert, values);
        try {
            Statement statement = sqliteDb.prepare(insert ~ values ~ query);
            statement.inject(userId, link.url, link.title, link.category);
            Link lastLink = getLastInsertedLink(userId);
            debugfln("Last inserted link: %s", lastLink.url);
            return lastLink;
        } catch (SqliteException e) {
            errorfln("ERROR WHEN INSERTING LINK ", e.msg);
        }
        Link badLink;
        badLink.linkId = INVALID_LINK_ID;
        return badLink;
    }

    private Link getLastInsertedLink(long userId) {
        debugfln("Getting last inserted link");
        // TODO: Perform validation for user etc
        string query = format("SELECT * FROM %s WHERE %s = %d AND %s = last_insert_rowid();",
            TABLE_NAME,
            COLUMN_USER_ID,
            userId,
            COLUMN_LINK_ID);

        debugfln("Query: %s", query);

        try {
            ResultRange results = sqliteDb.execute(query);
            foreach (Row row; results) {
                return getLinkFromRow(row);
            }
        } catch (SqliteException e) {
            errorfln("ERROR WHEN SELECTING LINK ", e.msg);
        }

        throw new LinkNotFoundException("Could not get last inserted Link");
    }

    /// Gets a Link from a database row result
    private Link getLinkFromRow(Row row) {
        Link link;
        link.linkId = row.peek!long(0);
        link.category = row[COLUMN_CATEGORY].as!string;
        link.timestamp = row[COLUMN_TIMESTAMP].as!int;
        link.title = row[COLUMN_TITLE].as!string;
        link.url = row[COLUMN_URL].as!string;
        link.isArchived = (row[COLUMN_IS_ARCHIVED].as!long != 0);
        link.isFavorite = (row[COLUMN_IS_FAVORITE].as!long != 0);
        return link;
    }
}

class LinkNotFoundException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}
