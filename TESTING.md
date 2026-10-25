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

## Accessibility test plan

These checks are **pending**. The 16 passing unit tests don't cover accessibility, and no accessibility audit has been recorded yet.

Run the checks on the iPhone simulator and a physical iPhone. Use the Ferry Building walkthrough for the normal flow, then repeat the relevant checks with denied location access, no search results, and a failed route request.

| Check | Steps and expected result |
| --- | --- |
| VoiceOver labels | Move through Search, Locate, Reset, Satellite, result cards, Deselect, the origin picker, Driving directions, and Clear. Each control should have a useful name, role, and current state. Icon-only controls must make sense without seeing the icon. |
| VoiceOver reading order | Follow the screen from the header through the map and results. Focus should move in a sensible order, without getting trapped in the map or repeatedly visiting decorative elements. |
| Search and pin selection | Search for Ferry Building, then select it through both its map pin and result card. VoiceOver should identify the place and make the selected destination and details discoverable. The result card should offer an alternative to manipulating the map. |
| Route information | Choose My location or Apple Park and request directions. The selected origin, destination, distance, estimate, and loading state should be readable without interpreting the blue route line. |
| Status and errors | Trigger search progress, an empty result, denied location access, and a route error. Check that changes are announced or readily discoverable and that focus isn't unexpectedly moved away from the current task. Check again after cancelling or retrying. |
| Settings return | With VoiceOver enabled, deny location, use Settings to grant access, and return. The old denial message should clear, focus should remain usable, and Locate should still be reachable. |
| Dynamic Type | Use the largest accessibility text sizes. Check the title, search field, place name/address, status messages, origin picker, and route summary. Essential text must remain available without overlap; controls must remain reachable when the keyboard is open. |
| Contrast and appearance | Check Light Mode, Dark Mode, Increase Contrast, and Reduce Transparency. Text and controls over map imagery and material panels should remain readable. Review any contrast warnings in Accessibility Inspector. |
| Color independence | Enable Differentiate Without Color. Confirm that selection, the current position, and route information are identifiable by labels or other cues rather than color alone. |
| Touch targets | Inspect Reset, Deselect, Search, Cancel, and Clear, including spacing between adjacent controls. Use a 44 × 44 pt hit area as the design target for touch controls; investigate Inspector warnings and confirm usability on a device. |
| Voice Control and Switch Control | Complete search, result selection, origin selection, and route preview without direct map gestures. Check that controls can be identified, activated, and reached through scanning. |
| Reduced motion and layout | Enable Reduce Motion; pan and reset the map. Check portrait and landscape on a smaller screen. Motion should remain comfortable, and the header, results, and route controls should not obscure essential content. |
| Demo and README | Check that screenshot descriptions identify the content and that the written walkthrough explains the same steps as the captioned video. Instructions should not depend only on color or screen position. |

### Running an Inspector audit

In Xcode, open **Xcode → Open Developer Tool → Accessibility Inspector** and select the running app. Audit the initial map, search results, selected place, route preview, and error states. Review labels, hit regions, contrast, traits, and text clipping. Save findings with the affected screen and setting.

Inspector results supplement hands-on testing. A clean audit doesn't establish that the full VoiceOver or Switch Control flow works.

For each manual check, record the device/OS, accessibility setting, steps, actual result, and pass/fail status. Attach a screenshot or short recording when it helps explain a failure. Leave unrun checks marked pending.

References: [Apple's accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Accessibility Inspector](https://developer.apple.com/documentation/accessibility/accessibility-inspector), and [touch-control guidance](https://developer.apple.com/design/tips/).

## Still to test

| Area | Next check |
| --- | --- |
| Route success unit test | Add a controlled successful route response. Current unit tests cover request construction, errors, and cancellation. |
| Request timing | Cancel or replace requests while live responses are pending. Check that loading stops and old results don't reappear. |
| Location failures | Exercise restricted access, approximate location, the 20-second timeout, and permission revocation on a device. |
| Location freshness | Wait more than two minutes after Locate and confirm a new fix is required before routing. |
| Network and routing | Disconnect and reconnect during requests, retry, and try a destination with no driving route. |
| Accessibility | Complete the pending [accessibility test plan](#accessibility-test-plan), including assistive technology and device checks. |
| Physical iPhone | Check GPS behavior and performance outside the simulator. |

No code-coverage percentage has been measured. The passing unit tests and simulator checks don't replace these remaining device and integration checks.
