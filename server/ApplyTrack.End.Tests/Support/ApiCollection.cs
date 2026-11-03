namespace ApplyTrack.End.Tests.Support;

/// <summary>One shared API for all API tests. The database is migrated only once.</summary>
[CollectionDefinition("Api")]
public sealed class ApiCollection : ICollectionFixture<ApiFactory>;
