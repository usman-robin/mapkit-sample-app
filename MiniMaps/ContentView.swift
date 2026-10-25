import MapKit
import SwiftUI

/// Milestone 1: camera control, annotations, and map presentation.
struct ContentView: View {
    private static let applePark = CLLocationCoordinate2D(
        latitude: 37.3349, longitude: -122.0090
    )
    private static let initialRegion = MKCoordinateRegion(
        center: applePark,
        span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)
    )

    // Binding the camera lets both gestures and our Reset button move the map.
    @State private var position: MapCameraPosition = .region(initialRegion)
    @State private var showsSatellite = false

    var body: some View {
        Map(position: $position) {
            Marker("Apple Park", systemImage: "building.2", coordinate: Self.applePark)
                .tint(.indigo)
        }
        .mapStyle(showsSatellite ? .hybrid : .standard)
        .mapControls {
            MapCompass()
            MapPitchToggle()
            MapScaleView()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MiniMaps")
                        .font(.title2.bold())
                    Text("A MapKit exploration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation {
                        position = .region(Self.initialRegion)
                    }
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Returns the map to Apple Park")
            }
            .padding()
            .background(.regularMaterial)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                Toggle("Satellite imagery", isOn: $showsSatellite)
                Text("Drag to explore, pinch to zoom, or use two fingers to rotate and tilt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(.regularMaterial)
        }
    }
}
