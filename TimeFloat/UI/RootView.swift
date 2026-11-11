import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: FloatingClockSession
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack(alignment: .topLeading) {
            SettingsView()
            if session.isEnabled {
                // Do not fade this view. Its sample-buffer layer is the PiP source and must stay
                // at alpha 1 in the window. The in-app drawing is hidden separately once PiP is up.
                FloatingOverlayRepresentable(session: session)
                    .ignoresSafeArea()
                    .allowsHitTesting(!session.hidesInAppClock)
            }
            if let banner = session.banner {
                VStack {
                    Spacer()
                    Text(banner)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.82), in: Capsule())
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { session.updateViewport(proxy.size) }
                    .onChange(of: proxy.size) { _, newSize in
                        session.updateViewport(newSize)
                    }
            }
        )
        .onAppear { session.bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                session.sceneBecameActive()
            } else if phase == .inactive || phase == .background {
                session.sceneWentBackground()
            }
        }
    }

}

struct FloatingOverlayRepresentable: UIViewRepresentable {
    let session: FloatingClockSession

    func makeUIView(context: Context) -> FloatingOverlayView {
        let view = FloatingOverlayView()
        view.clamp = { [weak session] point in
            session?.clampedOrigin(point) ?? point
        }
        view.onMoveEnd = { [weak session] origin in
            session?.move(to: origin)
            session?.finishMove()
        }
        view.card.onCaptionTap = { [weak session] caption in
            session?.logCaption(caption)
        }
        session.attach(host: view.card)
        session.attachOverlay(view)
        view.place(origin: session.origin, size: session.layout.size)
        view.card.setChips(session.layout.chips)
        view.card.setInlineChromeHidden(session.hidesInAppClock)
        return view
    }

    func updateUIView(_ uiView: FloatingOverlayView, context: Context) {
        session.attach(host: uiView.card)
        session.attachOverlay(uiView)
        uiView.clamp = { [weak session] point in
            session?.clampedOrigin(point) ?? point
        }
        if !uiView.isDragging {
            uiView.place(origin: session.origin, size: session.layout.size)
        }
        uiView.card.setChips(session.layout.chips)
        uiView.card.setInlineChromeHidden(session.hidesInAppClock)
    }
}
