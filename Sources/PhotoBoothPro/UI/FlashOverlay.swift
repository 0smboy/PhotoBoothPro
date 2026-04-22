import SwiftUI

/// Full-window white overlay used to bounce extra light onto the subject.
/// Drive visibility via the `isActive` binding; the view handles its own fade.
struct FlashOverlay: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            if isActive {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
    }
}
