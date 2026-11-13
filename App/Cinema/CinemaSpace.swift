import RealityKit
import SwiftUI

/// The cinema room: a black sphere around the viewer, so only the (enlarged) web window is lit
/// (cinema spec C2, decision D1). The immersion is progressive — the Digital Crown fades it back to the room.
struct CinemaSpace: View {
    let model: BrowserModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        RealityView { content in
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 40),
                materials: [UnlitMaterial(color: .black)]
            )
            sphere.scale = SIMD3(x: -1, y: 1, z: 1) // inside-out: render the faces that look inward
            content.add(sphere)
        }
        .onAppear {
            model.cinemaSpaceIsOpen = true
            EventLog.shared.log(.media, "cinema space appeared")
        }
        .onChange(of: model.windowClosedDuringCinema) {
            // The user closed the window (its close button) during cinema: with no window there are no controls.
            // Treat it as "end fullscreen": bring the window back, then close the room (decision D4).
            // Closing the room ends the page's fullscreen via `exitCinemaFromSystem` (onDisappear below).
            EventLog.shared.log(.media, "window closed during cinema → reopen window, close cinema space")
            openWindow(id: "browser")
            Task { await dismissImmersiveSpace() }
        }
        .onDisappear {
            model.cinemaSpaceIsOpen = false
            EventLog.shared.log(.media, "cinema space disappeared")
            model.exitCinemaFromSystem() // no-op when the app closed it on purpose
        }
    }
}
