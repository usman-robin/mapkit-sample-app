import XCTest
import MapKit
@testable import MiniMaps

@MainActor
final class MapModelTests: XCTestCase {
    private final class SearchStub: PlaceSearching {
        var cancelled = false
        var completion: (@MainActor (Result<PlaceSearchResult, Error>) -> Void)?
        func start(_ completion: @escaping @MainActor (Result<PlaceSearchResult, Error>) -> Void) { self.completion = completion }
        func cancel() { cancelled = true }
        func succeed(_ items: [MKMapItem] = []) { completion?(.success(.init(items: items, region: MapModel.region))) }
        func fail() { completion?(.failure(URLError(.notConnectedToInternet))) }
    }
    private final class RouteStub: RouteCalculating {
        var cancelled = false
        var completion: (@MainActor (Result<MKRoute?, Error>) -> Void)?
        func calculate(_ completion: @escaping @MainActor (Result<MKRoute?, Error>) -> Void) { self.completion = completion }
        func cancel() { cancelled = true }
        func fail() { completion?(.failure(URLError(.notConnectedToInternet))) }
    }
    private func item(_ name: String) -> MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: MapModel.home))
        item.name = name
        return item
    }
    private func selectedModel(route: RouteStub, capture: ((MKDirections.Request) -> Void)? = nil) -> MapModel {
        let model = MapModel(directionsFactory: { request in capture?(request); return route })
        let place = Place(item: item("Destination"))
        model.places = [place]
        model.selection = place.id
        return model
    }

    func testBlankSearchNeverStartsRequest() {
        var started = false
        let model = MapModel(searchFactory: { _ in started = true; return SearchStub() })
        model.searchPlaces("  \n ")
        XCTAssertFalse(started)
        XCTAssertFalse(model.isSearching)
        XCTAssertNotNil(model.searchMessage)
    }
    func testSearchTrimsQueryAndUsesVisibleRegion() {
        var request: MKLocalSearch.Request?
        let stub = SearchStub()
        let model = MapModel(searchFactory: { request = $0; return stub })
        model.visibleRegion = MKCoordinateRegion(center: .init(latitude: 40, longitude: -74), span: .init(latitudeDelta: 1, longitudeDelta: 1))
        model.searchPlaces("  coffee  ")
        XCTAssertEqual(request?.naturalLanguageQuery, "coffee")
        XCTAssertEqual(request?.region.center.latitude, 40)
        XCTAssertTrue(model.isSearching)
        stub.succeed([item("Coffee")])
        XCTAssertFalse(model.isSearching)
        XCTAssertEqual(model.places.first?.name, "Coffee")
    }
    func testEmptySearchResultsShowGuidance() {
        let stub = SearchStub()
        let model = MapModel(searchFactory: { _ in stub })
        model.searchPlaces("nowhere")
        stub.succeed()
        XCTAssertTrue(model.places.isEmpty)
        XCTAssertEqual(model.searchMessage, "No places found. Try a different name or address.")
    }
    func testSearchFailureCanRecover() {
        let stub = SearchStub()
        let model = MapModel(searchFactory: { _ in stub })
        model.searchPlaces("coffee")
        stub.fail()
        XCTAssertNotNil(model.searchMessage)
        XCTAssertFalse(model.isSearching)
        model.searchPlaces("library")
        stub.succeed([item("Library")])
        XCTAssertNil(model.searchMessage)
        XCTAssertEqual(model.places.first?.name, "Library")
    }
    func testReplacedSearchCannotOverwriteNewResults() {
        let old = SearchStub(), new = SearchStub()
        var count = 0
        let model = MapModel(searchFactory: { _ in count += 1; return count == 1 ? old : new })
        model.searchPlaces("old")
        model.searchPlaces("new")
        XCTAssertTrue(old.cancelled)
        new.succeed([item("New")])
        old.succeed([item("Old")])
        XCTAssertEqual(model.places.map(\.name), ["New"])
    }
    func testCancelledSearchIgnoresLateFailure() {
        let stub = SearchStub()
        let model = MapModel(searchFactory: { _ in stub })
        model.searchPlaces("coffee")
        model.cancelSearch()
        stub.fail()
        XCTAssertTrue(stub.cancelled)
        XCTAssertFalse(model.isSearching)
        XCTAssertNil(model.searchMessage)
    }
    func testDirectionsUseExplicitDemoOriginAndDrivingMode() {
        let stub = RouteStub()
        var request: MKDirections.Request?
        let model = selectedModel(route: stub, capture: { request = $0 })
        model.drivingDirections()
        XCTAssertTrue(model.isRouting)
        XCTAssertEqual(request?.transportType, .automobile)
        XCTAssertEqual(request?.source?.placemark.coordinate.latitude, MapModel.home.latitude)
        XCTAssertEqual(request?.destination?.name, "Destination")
    }
    func testCurrentLocationRequiresFreshFix() {
        let stub = RouteStub()
        var started = false
        let model = selectedModel(route: stub, capture: { _ in started = true })
        model.useCurrentLocation = true
        model.drivingDirections()
        XCTAssertFalse(started)
        XCTAssertNotNil(model.routeMessage)
        model.location = CLLocation(coordinate: MapModel.home, altitude: 0, horizontalAccuracy: 10, verticalAccuracy: 10, timestamp: Date(timeIntervalSinceNow: -300))
        model.drivingDirections()
        XCTAssertFalse(started)
        XCTAssertFalse(model.isRouting)
    }
    func testFreshLocationIsUsedAsRouteOrigin() {
        let stub = RouteStub()
        var request: MKDirections.Request?
        let model = selectedModel(route: stub, capture: { request = $0 })
        model.useCurrentLocation = true
        model.location = CLLocation(latitude: 37.3, longitude: -122.1)
        model.drivingDirections()
        XCTAssertEqual(request?.source?.placemark.coordinate.longitude, -122.1)
        XCTAssertTrue(model.isRouting)
    }
    func testRouteFailureEndsProgress() {
        let stub = RouteStub()
        let model = selectedModel(route: stub)
        model.drivingDirections()
        stub.fail()
        XCTAssertFalse(model.isRouting)
        XCTAssertNil(model.route)
        XCTAssertNotNil(model.routeMessage)
    }
    func testNoRouteResponseShowsGuidance() {
        let stub = RouteStub()
        let model = selectedModel(route: stub)
        model.drivingDirections()
        stub.completion?(.success(nil))
        XCTAssertFalse(model.isRouting)
        XCTAssertNotNil(model.routeMessage)
    }
    func testDestinationChangeCancelsAndIgnoresLateRouteResponse() {
        let stub = RouteStub()
        let model = selectedModel(route: stub)
        model.drivingDirections()
        model.selection = nil
        stub.fail()
        XCTAssertTrue(stub.cancelled)
        XCTAssertFalse(model.isRouting)
        XCTAssertNil(model.routeMessage)
    }
    func testOriginChangeCancelsPendingRoute() {
        let stub = RouteStub()
        let model = selectedModel(route: stub)
        model.drivingDirections()
        model.useCurrentLocation = true
        stub.fail()
        XCTAssertTrue(stub.cancelled)
        XCTAssertNil(model.routeMessage)
        XCTAssertFalse(model.isRouting)
    }
}
