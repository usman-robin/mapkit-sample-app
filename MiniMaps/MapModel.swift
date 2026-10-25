import Combine
import CoreLocation
import MapKit
import SwiftUI


struct PlaceSearchResult {
    let items: [MKMapItem]
    let region: MKCoordinateRegion
}

@MainActor
protocol PlaceSearching: AnyObject {
    func start(_ completion: @escaping @MainActor (Result<PlaceSearchResult, Error>) -> Void)
    func cancel()
}

@MainActor
protocol RouteCalculating: AnyObject {
    func calculate(_ completion: @escaping @MainActor (Result<MKRoute?, Error>) -> Void)
    func cancel()
}

@MainActor
final class LivePlaceSearch: PlaceSearching {
    private let operation: MKLocalSearch
    init(_ request: MKLocalSearch.Request) { operation = MKLocalSearch(request: request) }
    func start(_ completion: @escaping @MainActor (Result<PlaceSearchResult, Error>) -> Void) {
        operation.start { response, error in
            Task { @MainActor in
                if let error { completion(.failure(error)) }
                else if let response { completion(.success(.init(items: response.mapItems, region: response.boundingRegion))) }
                else { completion(.failure(MKError(.unknown))) }
            }
        }
    }
    func cancel() { operation.cancel() }
}

@MainActor
final class LiveDirections: RouteCalculating {
    private let operation: MKDirections
    init(_ request: MKDirections.Request) { operation = MKDirections(request: request) }
    func calculate(_ completion: @escaping @MainActor (Result<MKRoute?, Error>) -> Void) {
        operation.calculate { response, error in
            Task { @MainActor in
                if let error { completion(.failure(error)) }
                else { completion(.success(response?.routes.first)) }
            }
        }
    }
    func cancel() { operation.cancel() }
}

struct Place: Identifiable {
    let id = UUID()
    let item: MKMapItem
    var name: String { item.name ?? "Unnamed place" }
}

/// Owns cancellable MapKit requests. Request IDs prevent old responses replacing new state.
@MainActor
final class MapModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    static let home = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    static let region = MKCoordinateRegion(center: home, span: .init(latitudeDelta: 0.035, longitudeDelta: 0.035))
    @Published var places: [Place] = []
    @Published var selection: UUID? { didSet { if oldValue != selection { cancelRoute() } } }
    @Published var isSearching = false
    @Published var isRouting = false
    @Published var isLocating = false
    @Published var searchMessage: String?
    @Published var routeMessage: String?
    @Published var locationMessage: String?
    @Published var location: CLLocation?
    @Published var route: MKRoute?
    @Published var camera: MapCameraPosition = .region(region)
    @Published var useCurrentLocation = false { didSet { if oldValue != useCurrentLocation { cancelRoute() } } }
    @Published var canOpenSettings = false
    var visibleRegion = region
    var selectedPlace: Place? { places.first { $0.id == selection } }
    private let manager = CLLocationManager()
    private var search: (any PlaceSearching)?
    private var directions: (any RouteCalculating)?
    private var searchID = UUID()
    private var routeID = UUID()
    private var locationTimeout: Task<Void, Never>?

    private let searchFactory: @MainActor (MKLocalSearch.Request) -> any PlaceSearching
    private let directionsFactory: @MainActor (MKDirections.Request) -> any RouteCalculating

    init(searchFactory: @escaping @MainActor (MKLocalSearch.Request) -> any PlaceSearching = { LivePlaceSearch($0) },
         directionsFactory: @escaping @MainActor (MKDirections.Request) -> any RouteCalculating = { LiveDirections($0) }) {
        self.searchFactory = searchFactory
        self.directionsFactory = directionsFactory
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func searchPlaces(_ query: String) {
        cancelSearch()
        cancelRoute()
        selection = nil
        places = []
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { searchMessage = "Enter a place or address to search."; return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = visibleRegion // A relevance hint, not a strict geographic boundary.
        let operation = searchFactory(request)
        search = operation
        let id = searchID
        isSearching = true
        searchMessage = nil
        operation.start { [weak self] result in
            guard let self, self.searchID == id else { return }
            self.isSearching = false
            self.search = nil
            switch result {
            case .failure(let error):
                self.searchMessage = (error as? MKError)?.code == .placemarkNotFound
                    ? "No places found. Try a different name or address."
                    : "Search couldn’t finish. Check your connection and try again."
            case .success(let response):
                self.places = response.items.filter { CLLocationCoordinate2DIsValid($0.placemark.coordinate) }.map { Place(item: $0) }
                if self.places.isEmpty { self.searchMessage = "No places found. Try a different name or address." }
                else { self.camera = .region(response.region) }
            }
        }
    }

    func cancelSearch() {
        searchID = UUID()
        search?.cancel()
        search = nil
        isSearching = false
    }

    func select(_ place: Place) {
        selection = place.id
        camera = .region(.init(center: place.item.placemark.coordinate, span: .init(latitudeDelta: 0.012, longitudeDelta: 0.012)))
    }

    func cancelRoute() {
        routeID = UUID()
        directions?.cancel()
        directions = nil
        isRouting = false
        route = nil
        routeMessage = nil
    }

    func drivingDirections() {
        cancelRoute()
        guard let destination = selectedPlace else { return }
        let origin: CLLocationCoordinate2D
        if useCurrentLocation {
            guard let location, abs(location.timestamp.timeIntervalSinceNow) < 120 else {
                routeMessage = "Tap Locate to get a fresh location, then try directions again."
                return
            }
            origin = location.coordinate
        } else { origin = Self.home }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = destination.item
        request.transportType = .automobile
        let operation = directionsFactory(request)
        directions = operation
        let id = routeID
        isRouting = true
        operation.calculate { [weak self] result in
            guard let self, self.routeID == id else { return }
            self.isRouting = false
            self.directions = nil
            guard case .success(let route?) = result else {
                self.routeMessage = "No driving route available. Try another destination or check your connection."
                return
            }
            self.route = route
            let rect = route.polyline.boundingMapRect
            self.camera = .rect(rect.insetBy(dx: -max(rect.width * 0.5, 200), dy: -max(rect.height * 0.5, 200)))
        }
    }

    func locate() {
        guard !isLocating else { return }
        locationMessage = nil
        canOpenSettings = false
        isLocating = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: requestFix()
        case .denied: locationUnavailable("Location access is denied. Enable it in Settings, or use Apple Park as your route origin.", settings: true)
        case .restricted: locationUnavailable("Location access is restricted by device policy. You can still search and route from Apple Park.")
        @unknown default: locationUnavailable("Location authorization is unavailable.")
        }
    }

    private func requestFix() {
        manager.requestLocation()
        locationTimeout?.cancel()
        locationTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard !Task.isCancelled, let self, self.isLocating else { return }
            self.manager.stopUpdatingLocation()
            self.locationUnavailable("Location timed out. Check Location Services and try again.")
        }
    }

    private func locationUnavailable(_ message: String, settings: Bool = false) {
        locationTimeout?.cancel()
        isLocating = false
        locationMessage = message
        canOpenSettings = settings
    }

    func cancelLocation() {
        locationTimeout?.cancel()
        manager.stopUpdatingLocation()
        isLocating = false
    }

    func refreshLocationAuthorization() {
        updateAuthorization(manager.authorizationStatus)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorization(manager.authorizationStatus)
    }

    /// Refresh status on return from Settings without requesting location implicitly.
    func updateAuthorization(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            let wasDenied = canOpenSettings || locationMessage?.contains("restricted") == true
            canOpenSettings = false
            if isLocating { requestFix() }
            else if wasDenied { locationMessage = "Location access is enabled. Tap Locate to update your position." }
        case .denied, .restricted:
            location = nil
            if useCurrentLocation { cancelRoute() }
            locationUnavailable(status == .denied
                ? "Location access is denied. You can enable it in Settings."
                : "Location access is restricted by device policy.", settings: status == .denied)
        case .notDetermined:
            if !isLocating { locationMessage = nil; canOpenSettings = false }
        @unknown default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isLocating else { return }
        guard let fix = locations.last, fix.horizontalAccuracy >= 0,
              abs(fix.timestamp.timeIntervalSinceNow) < 120 else {
            locationUnavailable("A fresh location wasn’t available. Please try again.")
            return
        }
        locationTimeout?.cancel()
        isLocating = false
        location = fix
        if useCurrentLocation { cancelRoute() }
        camera = .region(.init(center: fix.coordinate, span: .init(latitudeDelta: 0.025, longitudeDelta: 0.025)))
        let accuracy = Int(fix.horizontalAccuracy.rounded())
        locationMessage = manager.accuracyAuthorization == .reducedAccuracy ? "Approximate location received. Routes may start away from your exact position." : "Location updated (accuracy about \(accuracy) m)."
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isLocating else { return }
        locationUnavailable("Your location is unavailable. Check Location Services or the simulator’s location setting and try again.")
    }
}
