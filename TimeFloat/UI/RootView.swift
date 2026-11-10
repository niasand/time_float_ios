import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: FloatingClockSession
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack(alignment: .topLeading) {
            SettingsView()
            if session.isEnabled {
                FloatingOverlayRepresentable(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(session.hidesInAppClock ? 0 : 1)
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
        return view
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FloatingOverlayView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? uiView.bounds.width, height: proposal.height ?? uiView.bounds.height)
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
    }
}
