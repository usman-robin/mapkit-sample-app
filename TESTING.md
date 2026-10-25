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
