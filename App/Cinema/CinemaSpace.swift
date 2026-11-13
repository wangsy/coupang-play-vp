import RealityKit
import SwiftUI

/// The cinema room: a black sphere around the viewer, so only the (enlarged) web window is lit
/// (cinema spec C2, decision D1). The immersion is progressive — the Digital Crown fades it back to the room.
struct CinemaSpace: View {
    let model: BrowserModel

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
        .onDisappear {
            model.cinemaSpaceIsOpen = false
            EventLog.shared.log(.media, "cinema space disappeared")
            model.exitCinemaFromSystem() // no-op when the app closed it on purpose
        }
    }
}
