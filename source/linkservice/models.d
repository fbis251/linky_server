module linkservice.models;

/// A response for an Add request, indicating the success or failure of the add request
struct AddLinkResponse {
    bool successful; /// Whether or not the last request was successful
    Link link; /// The Link that was just added, useful because it contains the unique linkId
}

/// A URL and its metadata such as title, timestamp, category, etc
struct Link {
    /// .
    ulong linkId;
    /// .
    string category;
    /// .
    bool isArchived;
    /// .
    bool isFavorite;
    /// .
    int timestamp;
    /// .
    string title;
    /// .
    string url;
}

/// A request sent to /api/login
struct LoginRequest {
    /// The username to use during login
    string username;
    /// The password to use during login
    string password;
}

/// Sent to the client indicating the success of the login procedure, plus an authentication token
struct LoginResponse {
    /// The user ID of the account that successfully authenticated
    long userId;
    /// The authentication string a client should use when requesting a user's data
    string authString;
    /// The username of the account that successfully authenticated
    string username;
}

/// A response that contains the user's last update timestamp
struct UserInfoResponse {
    /// A timestamp for the last link update (adds, edits, removals, etc)
    int lastUpdateTimestamp;
}
