import SwiftUI

/// The four top-level destinations, in tab-bar order.
enum AppTab: Int, CaseIterable, Identifiable {
    case chats, status, groups, settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .chats: "Chats"
        case .status: "Status"
        case .groups: "Groups"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .chats: "bubble.left.and.bubble.right"
        case .status: "circle.dashed"
        case .groups: "person.3"
        case .settings: "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .chats: "bubble.left.and.bubble.right.fill"
        case .status: "circle.dashed.inset.filled"
        case .groups: "person.3.fill"
        case .settings: "gearshape.fill"
        }
    }
}

/// A floating, glass-material tab bar with a sliding selection pill, filled/outline
/// icon swaps, a spring "pop" on tap, and an optional unread badge — replaces the
/// system `TabView` chrome (hidden via `.toolbar(.hidden, for: .tabBar)`) while
/// `TabView` itself keeps managing per-tab navigation state underneath it.
struct CustomTabBar: View {
    @Binding var selection: AppTab
    var unreadCount: Int = 0

    @Namespace private var pillNamespace
    @State private var bouncingTab: AppTab?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        )
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func tabButton(for tab: AppTab) -> some View {
        let isSelected = selection == tab

        Button {
            select(tab)
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .matchedGeometryEffect(id: "selectedPill", in: pillNamespace)
                            .frame(width: 46, height: 32)
                            .shadow(color: .blue.opacity(0.35), radius: 8, y: 3)
                    }

                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Color.secondary)
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(bouncingTab == tab ? 1.18 : 1.0)
                        .overlay(alignment: .topTrailing) {
                            if tab == .chats && unreadCount > 0 {
                                unreadBadge
                            }
                        }
                }
                .frame(width: 46, height: 32)

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var unreadBadge: some View {
        Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, unreadCount > 9 ? 4 : 0)
            .frame(minWidth: 15, minHeight: 15)
            .background(Color.red, in: Circle())
            .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
            .offset(x: 10, y: -8)
    }

    private func select(_ tab: AppTab) {
        guard tab != selection else { return }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            selection = tab
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) {
            bouncingTab = tab
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                bouncingTab = nil
            }
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color(.systemGroupedBackground).ignoresSafeArea()
        CustomTabBar(selection: .constant(.chats), unreadCount: 3)
            .padding(.bottom, 12)
    }
}
