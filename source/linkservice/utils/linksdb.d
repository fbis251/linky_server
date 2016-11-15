module linkservice.utils.linksdb;

import std.format, std.datetime;
import d2sqlite3;

import linkservice.models;
import linkservice.common;

const static TABLE_LINKS        = "LINKS";
const static COLUMN_LINK_ID     = "LINK_ID";
const static COLUMN_CATEGORY    = "CATEGORY";
const static COLUMN_IS_ARCHIVED = "IS_ARCHIVED";
const static COLUMN_IS_FAVORITE = "IS_FAVORITE";
const static COLUMN_TIMESTAMP   = "TIMESTAMP";
const static COLUMN_TITLE       = "TITLE";
const static COLUMN_URL         = "URL";
const static COLUMN_USER_ID     = "USER_ID";

// Column IDs, consult schema.sql for order
const static ID_COLUMN_LINK_ID     = 0;
const static ID_COLUMN_CATEGORY    = 1;
const static ID_COLUMN_IS_ARCHIVED = 2;
const static ID_COLUMN_IS_FAVORITE = 3;
const static ID_COLUMN_TIMESTAMP   = 4;
const static ID_COLUMN_TITLE       = 5;
const static ID_COLUMN_URL         = 6;
const static ID_COLUMN_USER_ID     = 7;

class LinksDb {
    private Database sqliteDb;

    this(Database database){
        debugfln("LinksDb()");
        sqliteDb = database;
    }

    Link[] readDatabase(long userId) {
        debugfln("readDatabase(%d)", userId);
        Link[] linksArray;

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
            linksArray ~= rowLink;
        }
        return linksArray;
    }

    Link[] getCategoryLinks(long userId, string category) {
        debugfln("readDatabase(%d)", userId);
        Link[] linksArray;

        // TODO: The string below should not be bound here, is there a way to use binding to prevent sql attacks?
        string query = format("SELECT * FROM %s WHERE %s = %d AND %s = %s;",
            TABLE_LINKS,
            COLUMN_USER_ID,
            userId,
            COLUMN_CATEGORY,
            category);
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
            linksArray ~= rowLink;
        }
        return linksArray;
    }

    Link getLink(long userId, long linkId) {
        debugfln("getLink(%d, %d)", userId, linkId);

        string query = format("SELECT * FROM %s WHERE %s = %d AND %s = %d;",
            TABLE_LINKS,
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
            errorfln("ERROR WHEN SELECTING LINK, error: %s", e.msg);
        }

        throw new LinkNotFoundException(format("Could not find Link with LinkId: %d", linkId));
    }

    bool deleteLink(long userId, long linkId) {
        debugfln("deleteLink(%d, %d)", userId, linkId);

        string query = format("DELETE FROM %s WHERE %s = %d AND %s = %d;",
            TABLE_LINKS,
            COLUMN_LINK_ID,
            linkId,
            COLUMN_USER_ID,
            userId);

        debugfln("Query: %s", query);

        try {
            Statement statement = sqliteDb.prepare(query);
            statement.execute();
            return true;
        } catch (SqliteException e) {
            errorfln("ERROR WHEN DELETING LINK, error: %s", e.msg);
        }

        return false;
    }

    Link insertLink(long userId, Link link) {
        debugfln("insertLink(%d, %s)", userId, link.url);

        // Inserts will always ignore the link ID
        string insert = format("INSERT INTO %s (%s, %s, %s, %s)",
                               TABLE_LINKS,
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
            errorfln("ERROR WHEN INSERTING LINK, error: %s", e.msg);
        }
        Link badLink;
        badLink.linkId = INVALID_LINK_ID;
        return badLink;
    }

    bool setArchived(long userId, long linkId, bool isArchived) {
        debugfln("setArchived(%d, %d, %s)", userId, linkId, isArchived ? "true" : "false");
        return setFavoriteOrArchived(userId, linkId, isArchived, true);
    }

    bool setFavorite(long userId, long linkId, bool isFavorite) {
        debugfln("setFavorite(%d, %d, %s)", userId, linkId, isFavorite ? "true" : "false");
        return setFavoriteOrArchived(userId, linkId, isFavorite, false);
    }

    Link updateLink(long userId, Link link) {
        debugfln("updateLink(%d, %d)", userId, link.linkId);

        string update = format("UPDATE %s SET %s = :%s, %s = :%s, %s = :%s, %s = :%s, %s = :%s WHERE %s = %d AND %s = %d;",
                               TABLE_LINKS,
                               COLUMN_CATEGORY,
                               COLUMN_CATEGORY,
                               COLUMN_IS_ARCHIVED,
                               COLUMN_IS_ARCHIVED,
                               COLUMN_IS_FAVORITE,
                               COLUMN_IS_FAVORITE,
                               COLUMN_TITLE,
                               COLUMN_TITLE,
                               COLUMN_URL,
                               COLUMN_URL,
                               COLUMN_USER_ID,
                               userId,
                               COLUMN_LINK_ID,
                               link.linkId);

        debugfln("Query: %s", update);
        try {
            Statement statement = sqliteDb.prepare(update);
            statement.inject(link.category, link.isArchived, link.isFavorite, link.title, link.url);
            Link updatedLink = getLink(userId, link.linkId);
            debugfln("Updated Link title: %s, url: %s", updatedLink.title, updatedLink.url);
            return updatedLink;
        } catch (SqliteException e) {
            errorfln("ERROR WHEN UPDATING LINK, error: %s", e.msg);
        }
        Link badLink;
        badLink.linkId = INVALID_LINK_ID;
        return badLink;
    }

    private bool setFavoriteOrArchived(long userId, long linkId, bool columnValue, bool setArchived) {
        debugfln("setFavoriteOrArchived(%d, %d, %s, %s)",
                 userId,
                 linkId,
                 columnValue ? "true" : "false",
                 setArchived ? "true" : "false");

        string query = format("UPDATE %s SET %s = %d WHERE %s = %d AND %s = %d;",
            TABLE_LINKS,
            setArchived ? COLUMN_IS_ARCHIVED : COLUMN_IS_FAVORITE,
            columnValue ? 1 : 0,
            COLUMN_USER_ID,
            userId,
            COLUMN_LINK_ID,
            linkId);

        debugfln("Query: %s", query);

        int previousChangeCount = sqliteDb.totalChanges;
        try {
            Statement statement = sqliteDb.prepare(query);
            statement.execute();
            // If the query was successful the total change count will be increased
            bool result = sqliteDb.totalChanges > previousChangeCount;
            debugfln("Result: %s", result ? "true" : "false");
            return result;
        } catch (SqliteException e) {
            errorfln("ERROR WHEN SETTING FAVORITE ON LINK, error: %s", e.msg);
        }

        return false;
    }

    private Link getLastInsertedLink(long userId) {
        debugfln("getLastInsertedLink(%d)", userId);

        string query = format("SELECT * FROM %s WHERE %s = %d AND %s = last_insert_rowid();",
            TABLE_LINKS,
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
            errorfln("ERROR WHEN SELECTING LINK, error: %s", e.msg);
        }

        throw new LinkNotFoundException("Could not get last inserted Link");
    }

    /// Gets a Link from a database row result
    private Link getLinkFromRow(Row row) {
        Link link;
        link.linkId     = row.peek!long(ID_COLUMN_LINK_ID);
        link.category   = row.peek!string(ID_COLUMN_CATEGORY);
        link.isArchived = row.peek!long(ID_COLUMN_IS_ARCHIVED) != 0;
        link.isFavorite = row.peek!long(ID_COLUMN_IS_FAVORITE) != 0;
        link.timestamp  = row.peek!int(ID_COLUMN_TIMESTAMP);
        link.title      = row.peek!string(ID_COLUMN_TITLE);
        link.url        = row.peek!string(ID_COLUMN_URL);
        return link;
    }
}

class LinkNotFoundException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}
