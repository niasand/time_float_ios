import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: FloatingClockSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var dragBase: CGPoint?

    var body: some View {
        ZStack(alignment: .topLeading) {
            SettingsView()
            if session.isEnabled {
                floatingCard
                    .offset(x: session.origin.x, y: session.origin.y)
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
            } else if phase == .background {
                session.sceneWentBackground()
            }
        }
    }

    private var floatingCard: some View {
        ZStack(alignment: .topLeading) {
            PipHostRepresentable(session: session)
            ForEach(session.layout.chips, id: \.caption) { chip in
                Button {
                    session.logCaption(chip.caption)
                } label: {
                    Color.white.opacity(0.001)
                }
                .buttonStyle(.plain)
                .frame(width: chip.rect.width, height: chip.rect.height)
                .offset(x: chip.rect.minX, y: chip.rect.minY)
            }
        }
        .frame(width: session.layout.size.width, height: session.layout.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    if dragBase == nil { dragBase = session.origin }
                    session.move(to: CGPoint(
                        x: (dragBase?.x ?? 0) + value.translation.width,
                        y: (dragBase?.y ?? 0) + value.translation.height
                    ))
                }
                .onEnded { _ in
                    dragBase = nil
                    session.finishMove()
                }
        )
        .accessibilityLabel("悬浮时钟")
    }
}

struct PipHostRepresentable: UIViewRepresentable {
    let session: FloatingClockSession

    func makeUIView(context: Context) -> PipHostView {
        let view = PipHostView()
        session.attach(host: view)
        return view
    }

    func updateUIView(_ uiView: PipHostView, context: Context) {
        session.attach(host: uiView)
    }
}
