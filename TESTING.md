# Test plan — Usman's Mapkit Demo

Run on an iPhone simulator and, before sharing widely, a physical iPhone. Search results, traffic estimates, and imagery depend on Apple services and can change.

| Scenario | Steps | Expected |
| --- | --- | --- |
| Search | Search for Apple Infinite Loop near Cupertino | Result cards and selectable markers appear; camera fits results |
| Empty input | Enter spaces | Search button disabled; submitting from keyboard shows input guidance |
| No matches | Search a random nonexistent name | No-results message or a recoverable service error; no stale markers |
| Search replacement | Start A, then submit B before A completes | Only B can populate the results |
| Cancel search | Cancel while progress is shown | Progress ends; late responses do not restore results |
| Selection | Tap a marker, then a different result card | Destination and highlight update; previous route is cleared |
| Demo driving route | Select a Cupertino result; choose Apple Park; tap Driving directions | Blue polyline, distance and time; no location permission prompt |
| Route cancellation | Cancel a pending route; change destination/origin | No obsolete overlay appears |
| Missing fix | Choose My location without Locate, then request directions | Guidance asks for a fresh location |
| First location request | Fresh install; tap Locate | When-in-use prompt only after this action |
| Denied | Choose Don't Allow | App remains usable; explanation and Settings action |
| Restricted | Device policy restricts location | Explanation; search and Apple Park routing still work |
| Location success | Set simulator location, tap Locate and allow | Location marker, camera update, accuracy message |
| Approximate | Disable Precise Location in app Settings | Approximate-location explanation; routing uses delivered coordinate |
| Timeout/unavailable | Simulator location None or disabled system services; tap Locate | Recoverable error or 20-second timeout; retry possible |
| Revocation | Revoke permission after receiving location | Previously obtained fix removed; current-location route cleared |
| Stale fix | Wait over two minutes before requesting current-location route | Requests a new fix rather than routing from stale data |
| Network failure | Disconnect network; search and request a route | Recoverable service error, no indefinite progress |
| No driving route | Choose an unreachable or overseas destination | Route error without crashing |
| Accessibility | VoiceOver, largest Dynamic Type, landscape | Controls named; inspect layout and map visibility |
| Reset and style | Pan, toggle Satellite, Reset | Camera returns to Apple Park; pending route cancelled |

## Evidence and limits

Build and runtime results are recorded in README after verification. A screenshot proves the visible state only; it does not establish cancellation, offline handling, or authorization behavior. Restricted authorization and physical-device GPS accuracy require separate device testing.

## Request lifecycle

Search and route requests each have a generation UUID. Cancel, destination changes, origin changes, and replacement requests invalidate the previous generation. Completion handlers return to the main actor and check that UUID before publishing state. Location uses a one-shot request, ignores callbacks after cancellation, validates timestamp/accuracy, and times out after 20 seconds. No background location entitlement is requested.

## Observed simulator checks — October 25, 2026

- PASS: build and launch through Xcode 27.1 on iPhone 18 Pro / iOS 27.0.
- PASS: initial map displays without requesting location permission.
- PASS: search for Apple Infinite Loop returns two results; result-card selection displays destination details.
- PASS: driving route from Apple Park displays a blue overlay, distance, and time (2.7 mi / about 8 min during this session).
- PASS: changing to satellite preserves the visible route.
- PASS: Locate triggers the system when-in-use prompt; Don't Allow displays denied guidance and a Settings button while the Apple Park route remains usable.
- PASS: a failed search displays retry guidance and the next valid search succeeds.
- NOT YET VERIFIED: approximate location fixes, restricted policy, rapid cancellation races, no-route cases, offline transitions, accessibility extremes, physical-device behavior.

## Automated XCTest results

16 tests passed, 0 failures, in Xcode on October 25, 2026 at 11:46 AM PDT. Run with Command-U using the shared MiniMaps scheme. Search/directions protocols let tests deliver success, failure, and deliberately late callbacks without network access. Permission/system behavior and real map rendering remain simulator/device integration checks.

## Settings-return regression

When changing Location Services from Never to While Using in iOS Settings, return to the app. The prior denial message must be replaced, the Settings action must disappear, and no location request should start until Locate is tapped. Authorization is refreshed on foreground activation as well as through the Core Location delegate. Regression tests cover grant after denial, grant after restriction, and revocation of a previously obtained fix.

- PASS: While Using permission saved in Settings; Locate obtained simulated San Francisco coordinates and displayed accuracy about 5 m after the Settings-return refresh fix. This is simulator evidence, not real GPS accuracy.
