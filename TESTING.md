# Testing

The latest run passed all **16 XCTest tests** with no failures. Tests were run in Xcode 27.1 on an iPhone 18 Pro simulator with iOS 27.0 on October 25, 2026.

## Running the unit tests

Open `MiniMaps.xcodeproj`, select the **MiniMaps** scheme and an iPhone simulator, then press **Command-U**. Results appear in Xcode's Test navigator.

The test target is `MiniMapsTests`. All tests are in [`MapModelTests.swift`](MiniMapsTests/MapModelTests.swift). They don't need a network connection or a simulated location.

From the repository root, you can also use:

```sh
xcodebuild -project MiniMaps.xcodeproj \
  -scheme MiniMaps \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  test
```

Change the simulator name if needed. The recorded passing run used Xcode's Test action.

## Unit-test catalog

| Test | What it checks |
| --- | --- |
| `testBlankSearchNeverStartsRequest` | Blank input shows a message without starting a search. |
| `testSearchTrimsQueryAndUsesVisibleRegion` | The request uses the trimmed query and visible region; a successful response updates the results. |
| `testEmptySearchResultsShowGuidance` | An empty response shows the no-results message. |
| `testSearchFailureCanRecover` | A failed search stops loading, and a later successful search clears the error. |
| `testReplacedSearchCannotOverwriteNewResults` | An old response cannot replace results from a newer search. |
| `testCancelledSearchIgnoresLateFailure` | A cancelled search cannot show an error when its callback arrives later. |
| `testDirectionsUseExplicitDemoOriginAndDrivingMode` | The directions request uses driving mode, the selected destination, and the fixed origin's latitude. |
| `testCurrentLocationRequiresFreshFix` | Directions do not start when the location is missing or five minutes old. |
| `testFreshLocationIsUsedAsRouteOrigin` | A fresh location supplies the route request's source longitude. |
| `testRouteFailureEndsProgress` | A route error stops loading and shows a message. |
| `testNoRouteResponseShowsGuidance` | An empty route response stops loading and shows a message. |
| `testDestinationChangeCancelsAndIgnoresLateRouteResponse` | Deselecting a destination cancels the route request and ignores a late error. |
| `testOriginChangeCancelsPendingRoute` | Changing the origin cancels the pending request and ignores a late error. |
| `testPermissionGrantClearsStaleDenialWithoutStartingLocation` | Granting access clears the old denial message without starting a location request. |
| `testRestrictedPermissionGrantClearsStaleRestriction` | Granting access clears the old restriction message. |
| `testPermissionRevocationRemovesPreviouslyObtainedFix` | Revoking access removes the saved fix and shows the Settings action. |

## How the tests work

Search and directions are passed into `MapModel` through the `PlaceSearching` and `RouteCalculating` protocols. Tests replace them with `SearchStub` and `RouteStub`, so responses can be returned in any order without calling Apple's services.

For the stale-search test, request A starts first, then B. B completes before A. The test then delivers A's response and checks that B's results remain.

Authorization tests call `updateAuthorization` directly. Location tests supply sample `CLLocation` values. The real location manager is still created, but these tests don't request permission or GPS fixes. The clock and timeout scheduler are not replaced.

The happy paths covered here are successful search handling and construction of directions requests for both origins. A successful `MKRoute` response and map rendering are not unit-tested; those were checked in the simulator.

## Simulator checks

The following checks passed during development:

| Area | Checked behavior |
| --- | --- |
| Launch | The map opens without asking for location access. |
| Location | Locate obtains a simulated San Francisco fix and displays the location marker. |
| Search and selection | Ferry Building appears in search results; tapping its pin opens the place details. |
| Current-location route | My location produces a blue route with distance and travel time. |
| Map style | The route remains visible after switching to satellite imagery. |
| Permissions | Locate triggers the first-use prompt. Denying access shows an explanation and Settings action. Granting access afterward clears the denial state and allows Locate to work. |
| Search recovery | A failed search shows a message; a subsequent search succeeds. |
| Fixed-origin route | Apple Park to Apple Infinite Loop works without location access. |

The [latest demo](demo.mp4) shows Locate, Ferry Building search, pin selection, My location routing, and satellite imagery. Permission was already granted during recording. The permission prompt and denial recovery were checked separately.

To reproduce the video, select **San Francisco, CA, USA** in Xcode's **Simulate Location** menu and follow the [README walkthrough](README.md#follow-the-demo). The recorded route was 1.3 miles with an estimate of about 14 minutes. Those values can change and aren't used as test assertions. The approximately 5 m accuracy shown in the app comes from the simulator, not a real GPS measurement.

## Still to test

| Area | Next check |
| --- | --- |
| Route success unit test | Add a controlled successful route response. Current unit tests cover request construction, errors, and cancellation. |
| Request timing | Cancel or replace requests while live responses are pending. Check that loading stops and old results don't reappear. |
| Location failures | Exercise restricted access, approximate location, the 20-second timeout, and permission revocation on a device. |
| Location freshness | Wait more than two minutes after Locate and confirm a new fix is required before routing. |
| Network and routing | Disconnect and reconnect during requests, retry, and try a destination with no driving route. |
| Layout and accessibility | Check VoiceOver, large text, landscape, smaller screens, and Reset after panning or changing map style. |
| Physical iPhone | Check GPS behavior and performance outside the simulator. |

No code-coverage percentage has been measured. The passing unit tests and simulator checks don't replace these remaining device and integration checks.
