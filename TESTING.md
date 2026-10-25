# Test plan — Usman's Mapkit Demo

## Latest recorded walkthrough

The current `demo.mp4` is a 36-second edited capture of the iPhone 18 Pro simulator running iOS 27.0. It shows:

1. Locate with a simulated San Francisco position and previously granted permission.
2. Search for Ferry Building using `MKLocalSearch`.
3. Tap the Ferry Building map pin to display its details.
4. Select My location as the origin.
5. Request driving directions and display the polyline, distance, and estimate.
6. Switch to satellite imagery; finish with a closing card.

Configure **San Francisco, CA, USA** through Xcode's debug-toolbar Simulate Location menu before reproducing this flow. The recorded route was 1.3 miles / about 14 minutes. Service data and travel estimates may vary; tests must not require those exact values. The reported approximately 5 m accuracy came from a simulated fix.

The video does not demonstrate first-use authorization, denial recovery, spoken navigation, or turn-by-turn instructions.

## Observed integration checks — October 25, 2026

| Check | Evidence / result |
| --- | --- |
| Build and launch | PASS in Xcode 27.1, iPhone 18 Pro / iOS 27.0 |
| Permission-free launch | PASS: initial map appears without requesting authorization |
| Granted location | PASS: Locate obtains simulated San Francisco coordinates and displays an accuracy message |
| Search | PASS: Ferry Building result appears on the map and in the results strip |
| Annotation selection | PASS: tapping its pin opens the destination details |
| Current-location route | PASS: My location origin produces a blue driving-route overlay with distance and time |
| Satellite | PASS: same route remains visible after switching imagery |
| First permission prompt | PASS in a separate check: prompt follows a Locate tap |
| Denied authorization | PASS in a separate check: explanation and Settings action; Apple Park routing remains usable |
| Grant after denial | PASS: Settings shows While Using, refreshed app no longer shows denial, Locate obtains a simulated fix |
| Recoverable search error | PASS in an earlier check: error guidance followed by successful retry |
| Fixed-origin alternative | PASS in an earlier check: Apple Park to Apple Infinite Loop; not the latest video flow |

These observations establish specific simulator behavior only. Screenshots do not establish race safety, complete offline recovery, or real GPS accuracy.

## Automated XCTest coverage

**16 tests passed, 0 failures**, in Xcode on October 25, 2026 at 11:46 AM PDT. Run **Command-U** with the shared MiniMaps scheme. Tests inject search and directions services and deliver controlled responses without using Apple's network services.

| Area | Automated coverage |
| --- | --- |
| Search validation | Whitespace input, trimmed query, visible-region hint |
| Search results | Success, empty response, error, successful retry |
| Search lifecycle | Cancellation and deliberately out-of-order callbacks |
| Route request | Driving transport mode, chosen destination, Apple Park origin |
| Location origin | Missing/stale fix rejection and fresh-coordinate use |
| Route failure | Service error and empty route response end progress |
| Route invalidation | Destination/origin changes cancel work and ignore late failure |
| Authorization state | Denied/restricted → granted clears stale guidance without requesting a fix; revocation removes the previous fix |

These tests cover model behavior. They do not prove real system permission delivery, rendered geometry, successful route integration, or physical GPS quality. Route success and rendering were checked in the simulator.

## Running the unit tests

1. Open `MiniMaps.xcodeproj` in Xcode.
2. Select the shared **MiniMaps** scheme and an installed iPhone simulator.
3. Press **Command-U**, or choose **Product → Test**.
4. Open Xcode's Test navigator (**Command-6**) to inspect individual tests and failures. The latest recorded run completed with **16 tests passed and zero failures**.

The test target is **MiniMapsTests**; its source is [`MapModelTests.swift`](MiniMapsTests/MapModelTests.swift). Simulator location configuration is not required for these unit tests. It is required when reproducing the live demo.

For command-line execution from the repository root, using the simulator name available on your Mac:

```sh
xcodebuild -project MiniMaps.xcodeproj \
  -scheme MiniMaps \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  test
```

The command is a reproduction instruction. The recorded passing run was executed through Xcode, rather than through the restricted command-line environment used during development.

## Test design

`MapModel` accepts factories for the `PlaceSearching` and `RouteCalculating` protocols. Production factories create real `MKLocalSearch` and `MKDirections` wrappers. The tests supply `SearchStub` and `RouteStub`, capture requests, and control when callbacks return.

For example, the replacement-search test starts request A, starts B, completes B, and then delivers A's obsolete response. It checks that A was cancelled and only B's results remain. This verifies stale-response handling without relying on network timing.

The tests and model execute on the main actor. Authorization tests call the model's authorization-state method directly; location-origin tests provide sample `CLLocation` values. They do not interact with the system permission dialog or obtain real GPS fixes. The real location manager is still constructed, and the clock/timeout scheduler is not injected.

## Unit-test catalog

| Test method | Path | What the assertions verify |
| --- | --- | --- |
| `testBlankSearchNeverStartsRequest` | Input validation | Whitespace-only input does not create a search request, leaves progress off, and shows guidance. |
| `testSearchTrimsQueryAndUsesVisibleRegion` | Happy path | Query is trimmed, the visible region is passed to the request, and a successful response publishes the expected place and ends progress. |
| `testEmptySearchResultsShowGuidance` | Empty response | An empty successful response leaves no places and displays no-results guidance. |
| `testSearchFailureCanRecover` | Error and recovery | A simulated network failure ends progress and shows guidance; a later successful search replaces it with results. |
| `testReplacedSearchCannotOverwriteNewResults` | Async lifecycle | Replacing a search cancels the old operation, and its late response cannot overwrite the newer results. |
| `testCancelledSearchIgnoresLateFailure` | Cancellation | Explicit cancellation calls the service's cancel method and a late failure does not restore progress or error guidance. |
| `testDirectionsUseExplicitDemoOriginAndDrivingMode` | Happy request path | The request uses automobile transport, the selected destination, and Apple Park's latitude as its fixed origin; routing progress starts. |
| `testCurrentLocationRequiresFreshFix` | Missing/stale input | No directions request starts with a missing fix or a timestamp five minutes old; guidance is shown. |
| `testFreshLocationIsUsedAsRouteOrigin` | Happy request path | A fresh sample location supplies the source longitude and starts routing. |
| `testRouteFailureEndsProgress` | Service failure | A failed calculation ends progress, retains no route, and shows guidance. |
| `testNoRouteResponseShowsGuidance` | Empty route | A successful response containing no route ends progress and shows guidance. |
| `testDestinationChangeCancelsAndIgnoresLateRouteResponse` | Async lifecycle | Deselecting the destination cancels its pending route and ignores a late failure. |
| `testOriginChangeCancelsPendingRoute` | Async lifecycle | Changing the origin cancels its pending route and ignores a late failure. |
| `testPermissionGrantClearsStaleDenialWithoutStartingLocation` | Authorization recovery | Denied → authorized clears the Settings action, replaces stale denial guidance, and does not start locating automatically. |
| `testRestrictedPermissionGrantClearsStaleRestriction` | Authorization recovery | Restricted → authorized replaces the restriction guidance and leaves the Settings action hidden. |
| `testPermissionRevocationRemovesPreviouslyObtainedFix` | Authorization revocation | Revoking access removes an existing fix, exposes the Settings action, and leaves locating off. |

### Happy-path coverage and boundaries

The unit suite verifies successful search result handling and construction of requests for both route origins. Successful route calculation, visible annotations, polyline rendering, distance/time presentation, and satellite behavior were checked separately in the simulator and recorded in the demo.

There is no unit assertion for a successful `MKRoute` response or real route geometry. The suite also does not test the real 20-second timeout, actual permission callbacks, location accuracy, spoken navigation, or performance. No code-coverage percentage has been measured or claimed. See the matrix below for remaining integration/device work.

## Remaining integration/device matrix

| Scenario | Steps | Expected |
| --- | --- | --- |
| Rapid replacement | Search A then B; request route then change origin/destination | No obsolete results or routes; generation logic is already unit-tested |
| Native cancellation | Cancel requests while a real service response is pending | Progress ends and no late UI update |
| No results | Search a nonexistent name | Clear no-results or recoverable service error; no stale markers |
| Missing fix | Choose My location before Locate | Guidance to obtain a fresh fix |
| Stale fix | Wait more than two minutes after Locate, then request a route | Request a fresh fix rather than using old coordinates |
| Restricted policy | Device policy restricts location | Explanation; search and Apple Park routing remain available |
| Approximate location | Disable Precise Location | Approximate-location explanation and use of delivered coordinate |
| Unavailable/timeout | Disable the simulator location source or system services | Recoverable error or 20-second timeout; retry remains possible |
| Revocation | Revoke access after a successful fix | Fix and current-location route removed; model state is unit-tested |
| Network transition | Disconnect/reconnect during search and directions | Recoverable failure, no indefinite progress, subsequent retry works |
| No driving route | Request an unreachable destination | Recoverable route error |
| Accessibility/layout | VoiceOver, large Dynamic Type, landscape, smaller devices | Named usable controls and adequate map visibility |
| Real-device location | Test on physical iPhone in different conditions | Validate freshness, accuracy, permission changes, and performance |
| Reset and style | Pan, switch imagery, Reset | Return to Apple Park and cancel pending route |

## Request lifecycle and Settings-return regression

Search and route generation UUIDs invalidate cancelled/replaced work. Callbacks return to the main actor and check their generation before updating state. Destination and origin changes invalidate the current route.

Location uses one-shot requests, validates timestamp and horizontal accuracy, ignores callbacks when no request is active, and times out after 20 seconds. Authorization is refreshed both through the Core Location delegate and when the app becomes active. Returning from Settings clears stale denial/restriction guidance without implicitly requesting a location fix.

No background location permission or location history is used.
