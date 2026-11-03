# Solutions — Rescu Assessment

## Part C — Written Deliverables

### 1. RES-101 · Search shows results for the wrong query

#### Root Cause
Two interacting issues caused the bug:
1. **Asynchronous Race Condition (Out-of-Order Resolution):** In `SearchDealsController`, `onQueryChanged(query)` triggered `_search(query)` immediately on every keystroke. 5 concurrent asynchronous requests are dispatched; `"sushi"` finishes first and updates the UI, but moments later the older, slower requests for `"s"` and `"su"` resolve and overwrite `results` with stale data.
2. **Lack of Debouncing:** Every single keystroke immediately fired an HTTP request, flooding the simulated backend and amplifying the out-of-order execution.

#### Why This Fix Is the Right One
- **Request Versioning:** Every search invocation captures an incremented `_searchVersion`. This ensures that only the response matching the latest query can update `results` or dismiss `isLoading`.
- **Debouncing:** Pauses 300ms after the last keystroke before firing an API call

#### Alternatives Considered & Rejected
1. **"Debounce Only" (Rejected):**
   - *Why rejected:* Debouncing only spaces out request *dispatch*; it does not eliminate network race conditions.
2. **HTTP `CancelToken` / Backend Request Abort (Rejected):**
   - *Why rejected:* `FakeApiService` simulates a backend API without cancellation support, and ground rules prohibit modifying `FakeApiService`. Discarding stale responses at the controller boundary is the correct architectural pattern.

#### Edge Cases Considered
- **Rapid text clearing (Backspace / Clear):** Handled. When `trimmed.isEmpty`, `_debounceTimer` is cancelled immediately, `_searchVersion` is bumped to invalidate any in-flight response, and `results` / `hasSearched` are reset instantly.
- **Controller teardown mid-flight (`onClose`):** Handled. `_debounceTimer?.cancel()` runs on controller disposal to prevent post-dispose callbacks.
- **Loading state desynchronization:** Handled. `isLoading.value = false` only executes if `version == _searchVersion` in the `finally` block, ensuring the spinner does not disappear prematurely while a newer request is still in-flight.
- **Errors from outdated queries:** Handled. Stale requests that fail do not log errors or trigger error snackbars.
- **Redundant whitespace changes:** Handled. Strings are trimmed before evaluation so trailing spaces do not trigger new network requests.
- **Offline / automatic retry (Decided not to handle):** Search-as-you-type should not automatically retry stale queries on failure, as doing so would cause ghost queries when connectivity recovers. Users naturally retry by typing.
