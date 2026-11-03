# Solutions — Rescu Assessment

## Part C — Written Deliverables

### RES-101 · Search shows results for the wrong query

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

### RES-102 · Crash after leaving My orders

#### Root Cause
`PickupCountdown` started a periodic timer in `initState()`, but didn’t keep a reference to the timer or cancel it when the widget was removed. After leaving My orders, the timer continued firing and called `setState()` on a disposed widget, causing the crash.

#### Why This Fix Is the Right One
- **Timer cleanup:** The widget stores the timer and cancels it in `dispose()`. This stops its callbacks when the widget leaves the tree.

#### Alternatives Considered & Rejected

1. **Check `mounted` before calling `setState()` (Rejected):**
   - This could prevent the exception, but the periodic timer would keep running after the widget was removed. Cancelling the timer releases the resource and prevents further callbacks.

#### Edge Cases Considered

- **Leaving the screen while the timer is active:** Handled. `dispose()` cancels the timer.
- **Opening the screen again:** Handled. A new countdown widget starts and calculates the remaining time using the current time.
- **Countdown reaches the pickup time:** The timer continues refreshing once per second so the widget can show “Pickup window is open.” It is not stopped at that point.

### RES-103 · Requests pile up the longer you browse

#### Root Cause

Each `DealDetailsController` subscribed to `cartService.itemCount` using `ever()`. When the deal page closed, its controller did not remove that listener. The cart service continued holding the old subscriptions, so a later cart change triggered availability checks for deals whose pages had already been closed.

#### Why This Fix Is the Right One

- **Dispose the listener with its owner:** The controller stores the `Worker` returned by `ever()` and disposes it in `onClose()`. This removes the cart subscription when the controller is closed.
- **Keep availability checking on the active page:** While the deal page is open, cart changes still trigger `_recheckAvailability()` for that deal.

#### Alternatives Considered & Rejected

1. **Check whether the controller is active inside the callback (Rejected):**
   - This might prevent some work, but the listener would remain subscribed and continue receiving cart changes. Disposing the `Worker` removes the listener itself.

#### Edge Cases Considered

- **Several deal pages opened and closed:** Handled. Each controller disposes its own worker when `onClose()` runs.
- **Cart changes while a deal page is open:** Handled. Its worker remains active and rechecks that deal’s availability.
- **Controller retained by GetX after the route closes:** Depends on GetX’s dependency and route configuration. If the controller is retained, `onClose()` runs only when GetX deletes it, so its worker remains active until then. This fix relies on the route binding’s controller being deleted when its route is popped.
- **In-flight availability request when the controller closes:** Not cancelled. The request may finish after closure; this fix prevents future checks from that listener but does not abort an already-started repository request.

### RES-104 · Duplicate deals in the home feed

#### Root Cause

`loadMore()` and `refreshDeals()` could run at the same time.

Before the fix, `loadMore()` incremented `_page`, fetched that page, and appended its results after the request completed. If the user refreshed while that request was still running, `refreshDeals()` reset `_page` to 1 and replaced the feed with page 1. The earlier pagination request could then finish and append its old results to the refreshed feed. Since it didn’t know a refresh had happened, the feed could show duplicate deals or an incorrect number of items.

#### Why This Fix Is the Right One

- **Feed versioning:** `_feedVersion` identifies the current feed cycle. Refresh increments it. Each request saves the current version and checks it after awaiting the repository call. A response from an older feed cycle is ignored.
- **Advance the page only after success:** `loadMore()` calculates `requestedPage = _page + 1`, then updates `_page` only after a successful response for the current feed. A failed or stale request doesn’t advance pagination.
- **Filter duplicate IDs:** Before appending, `loadMore()` checks each returned deal ID against the IDs already in `deals`.
- **Reset pagination state in `finally`:** The active request clears `_isFetchingMore` and signals completion whether the request succeeds or fails, provided it still belongs to the current feed version.

#### Alternatives Considered & Rejected

1. **Use `_isFetchingMore` by itself (Rejected):**
   - It prevents two pagination requests from running at once, but it cannot stop a request already in progress from appending results after refresh. And let user refresh is more practical than let it load next page that might use more time

2. **Cancel the old request (Not used):**
   - The repository doesn’t expose request cancellation. Version checking lets the request finish while preventing its stale response from changing the feed.

#### Edge Cases Considered

- **Refresh while page 2 is loading — handled:** Refresh increments `_feedVersion`. When the old page 2 response arrives, its saved version no longer matches, so it is ignored.
- **Scroll to the bottom again after refresh — handled:** `_page` is reset to 1, so pagination requests page 2 again for the refreshed feed.
- **Repeated pagination calls — handled:** `_isFetchingMore` prevents another page request while the current one is loading.
- **Pagination request fails — handled:** `_page` advances only after success, so a later attempt can retry the same page.
- **Response contains deal IDs already in the feed — handled:** Duplicate IDs are filtered before appending.
- **Refresh request fails — handled:** The failure is logged and the refresh controller is notified; existing feed items remain visible.
- **Cancel an in-flight network request — not handled:** The repository doesn’t provide cancellation. The response is allowed to finish but is ignored if refresh made it stale.