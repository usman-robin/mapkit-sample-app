import MapKit
import SwiftUI

struct ContentView: View {
    @StateObject private var model = MapModel()
    @State private var query = ""
    @State private var showsSatellite = false
    @FocusState private var searchFocused: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        Map(position: $model.camera, selection: $model.selection) {
            Marker("Apple Park · demo origin", systemImage: "building.2", coordinate: MapModel.home)
                .tint(.indigo)
            ForEach(model.places) { place in
                Marker(place.name, coordinate: place.item.placemark.coordinate)
                    .tag(place.id)
            }
            if let location = model.location {
                Annotation("Your location", coordinate: location.coordinate) {
                    Image(systemName: "location.circle.fill")
                        .font(.title).foregroundStyle(.blue)
                        .background(.white, in: Circle())
                }
            }
            if let route = model.route {
                MapPolyline(route.polyline).stroke(.blue, lineWidth: 6)
            }
        }
        .mapStyle(showsSatellite ? .hybrid : .standard)
        .mapControls { MapCompass(); MapPitchToggle(); MapScaleView() }
        .onMapCameraChange(frequency: .onEnd) { model.visibleRegion = $0.region }
        .safeAreaInset(edge: .top, spacing: 0) { searchHeader }
        .safeAreaInset(edge: .bottom, spacing: 0) { resultsPanel }
        .onDisappear { model.cancelSearch(); model.cancelRoute(); model.cancelLocation() }
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Usman’s Mapkit Demo").font(.headline)
                Spacer()
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    model.cancelRoute()
                    withAnimation { model.camera = .region(MapModel.region) }
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Reset map to Apple Park")
            }
            HStack {
                TextField("Search places or addresses", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit(search)
                    .accessibilityIdentifier("placeSearch")
                if model.isSearching {
                    Button("Cancel") { model.cancelSearch() }
                } else {
                    Button("Search", action: search)
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            HStack {
                Button {
                    searchFocused = false
                    model.locate()
                } label: {
                    Label(model.isLocating ? "Locating…" : "Locate", systemImage: "location")
                }
                .disabled(model.isLocating)
                if model.isLocating { Button("Cancel") { model.cancelLocation() } }
                Spacer()
                Toggle("Satellite", isOn: $showsSatellite).fixedSize()
            }
            .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.isSearching { ProgressView("Searching…") }
            if let message = model.searchMessage { status(message) }
            if let message = model.locationMessage {
                HStack(alignment: .top) {
                    status(message)
                    if model.canOpenSettings {
                        Button("Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }
            }
            if let place = model.selectedPlace {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name).font(.headline)
                        Text(place.item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Deselect", systemImage: "xmark.circle.fill") { model.selection = nil }
                        .labelStyle(.iconOnly)
                }
                Picker("Route origin", selection: $model.useCurrentLocation) {
                    Text("Apple Park").tag(false)
                    Text("My location").tag(true)
                }.pickerStyle(.segmented)
                HStack {
                    if model.isRouting {
                        ProgressView("Finding route…")
                        Spacer()
                        Button("Cancel") { model.cancelRoute() }
                    } else {
                        Button("Driving directions", systemImage: "car.fill") { model.drivingDirections() }
                            .buttonStyle(.borderedProminent)
                        if model.route != nil { Button("Clear") { model.cancelRoute() } }
                    }
                }
                if let route = model.route {
                    Text("\(Measurement(value: route.distance, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))) · about \(max(1, Int(ceil(route.expectedTravelTime / 60)))) min")
                        .font(.subheadline)
                    Text("Route preview only. Follow road signs and conditions.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let message = model.routeMessage { status(message) }
            } else if !model.places.isEmpty {
                Text("\(model.places.count) places · select a result or map marker")
                    .font(.subheadline.weight(.semibold))
            } else if !model.isSearching && model.searchMessage == nil {
                Text("Search for a place to explore and preview a driving route.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if !model.places.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(model.places) { place in
                            Button { searchFocused = false; model.select(place) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(place.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Text(place.item.placemark.locality ?? "Place").font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(width: 155, alignment: .leading).padding(10)
                                .background(model.selection == place.id ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Select \(place.name)")
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    private func status(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(.secondary)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private func search() {
        searchFocused = false
        model.searchPlaces(query)
    }
}
