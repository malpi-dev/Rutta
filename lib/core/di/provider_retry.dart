/// Riverpod retries failed providers with exponential backoff by default,
/// which keeps a failing screen in "loading" for a long time. Errors are
/// surfaced right away with a manual *Retry* instead.
Duration? noAutomaticRetry(int retryCount, Object error) => null;
