const std = @import("std");
const c = @import("c.zig");

/// Couchbase error types mapped to Zig errors
pub const Error = error{
    /// Generic error
    GenericError,
    /// Connection errors
    ConnectionFailed,
    ConnectionTimeout,
    NetworkError,
    CannotConnect,
    /// Authentication errors
    AuthenticationFailed,
    InvalidCredentials,
    /// Document errors
    DocumentNotFound,
    DocumentExists,
    DocumentLocked,
    /// Timeout errors
    Timeout,
    DurabilityTimeout,
    /// Server errors
    ServerError,
    TemporaryFailure,
    OutOfMemory,
    NotSupported,
    InternalError,
    /// Bucket/Scope/Collection errors
    BucketNotFound,
    ScopeNotFound,
    CollectionNotFound,
    /// Query errors
    QueryError,
    PlanningFailure,
    IndexNotFound,
    PreparedStatementFailure,
    PreparedStatementNotFound,
    QueryCancelled,
    /// Durability errors
    DurabilityImpossible,
    DurabilityAmbiguous,
    DurabilitySyncWriteInProgress,
    /// Subdocument errors
    SubdocPathNotFound,
    SubdocPathExists,
    SubdocPathMismatch,
    SubdocPathInvalid,
    SubdocValueTooDeep,
    /// Encoding errors
    EncodingError,
    DecodingError,
    InvalidArgument,
    /// Transaction errors
    TransactionNotActive,
    TransactionFailed,
    TransactionTimeout,
    TransactionConflict,
    TransactionRollbackFailed,
    /// Other
    Unknown,
};

/// Status codes from libcouchbase
pub const StatusCode = enum(c_int) {
    _,
};

/// Convert libcouchbase status code to Zig error
pub fn fromStatusCode(rc: c.lcb_STATUS) Error!void {
    if (rc == c.LCB_SUCCESS) return;

    const rc_int: c_int = @intCast(rc);
    
    // Map known error codes (values from libcouchbase)
    if (rc == c.LCB_ERR_AUTHENTICATION_FAILURE) return error.AuthenticationFailed;
    if (rc == c.LCB_ERR_BUSY) return error.TemporaryFailure;
    if (rc == c.LCB_ERR_INVALID_ARGUMENT) return error.InvalidArgument;
    if (rc == c.LCB_ERR_NO_MEMORY) return error.OutOfMemory;
    if (rc == c.LCB_ERR_GENERIC) return error.GenericError;
    if (rc == c.LCB_ERR_TEMPORARY_FAILURE) return error.TemporaryFailure;
    if (rc == c.LCB_ERR_DOCUMENT_EXISTS) return error.DocumentExists;
    if (rc == c.LCB_ERR_DOCUMENT_NOT_FOUND) return error.DocumentNotFound;
    if (rc == c.LCB_ERR_ENCODING_FAILURE) return error.EncodingError;
    if (rc == c.LCB_ERR_TIMEOUT) return error.Timeout;
    if (rc == c.LCB_ERR_DOCUMENT_LOCKED) return error.DocumentLocked;
    if (rc == c.LCB_ERR_BUCKET_NOT_FOUND) return error.BucketNotFound;
    
    // Durability errors (if defined)
    if (rc_int == 0xD0) return error.DurabilityAmbiguous;
    if (rc_int == 0xD1) return error.DurabilityImpossible;
    if (rc_int == 0xD2) return error.DurabilitySyncWriteInProgress;
    
    // Subdoc errors (if defined)
    if (rc_int >= 0xC0 and rc_int <= 0xCF) return error.SubdocPathNotFound;
    
    // Collection errors (if defined)
    if (rc_int == 0x88) return error.CollectionNotFound;
    if (rc_int == 0x8C) return error.ScopeNotFound;
    
    return error.Unknown;
}

/// Get error description string
pub fn getErrorDescription(rc: c.lcb_STATUS) []const u8 {
    const desc = c.lcb_strerror_short(rc);
    return std.mem.span(desc);
}
