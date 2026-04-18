import AppKit
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case calendar
    case payments
    case students
    case sessions
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .calendar:
            return "Calendar"
        case .payments:
            return "Payments"
        case .students:
            return "Students"
        case .sessions:
            return "Sessions"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "house.fill"
        case .calendar:
            return "calendar.day.timeline.left"
        case .payments:
            return "sterlingsign.circle.fill"
        case .students:
            return "person.3.fill"
        case .sessions:
            return "rectangle.stack.badge.play.fill"
        case .settings:
            return "slider.horizontal.3"
        }
    }

}

enum AppTheme {
    static let accent = Color(red: 0.17, green: 0.90, blue: 0.54)
    static let accentSecondary = Color(red: 0.09, green: 0.55, blue: 0.34)
    static let appBackground = Color(red: 0.03, green: 0.04, blue: 0.06)
    static let sidebarBackground = Color(red: 0.05, green: 0.07, blue: 0.10)
    static let contentBackground = Color(red: 0.07, green: 0.09, blue: 0.13)
    static let panelBackground = Color(red: 0.10, green: 0.12, blue: 0.17)
    static let panelBackgroundSoft = Color(red: 0.12, green: 0.15, blue: 0.20)
    static let panelBorder = Color.white.opacity(0.08)
    static let mutedText = Color.white.opacity(0.68)
}

struct AppSidebar: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)

                    Image(systemName: "graduationcap.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("TutorTable")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            VStack(spacing: 10) {
                ForEach(AppSection.allCases) { section in
                    AppSidebarButton(
                        section: section,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [AppTheme.sidebarBackground, AppTheme.sidebarBackground.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1)
        }
    }
}

struct AppSidebarButton: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.05))
                        .frame(width: 42, height: 42)

                    Image(systemName: section.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : AppTheme.mutedText)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(section.title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.20) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.40) : Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .appInteractiveButton()
    }
}

struct TutorTablePanelGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            configuration.label
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            configuration.content
                .foregroundStyle(.white)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppTheme.panelBorder, lineWidth: 1)
        )
    }
}

struct AppInteractiveButtonModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    @State private var cursorIsActive = false
    let scaleAmount: CGFloat

    init(scaleAmount: CGFloat = 1.018) {
        self.scaleAmount = scaleAmount
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered && isEnabled ? scaleAmount : 1)
            .shadow(
                color: AppTheme.accent.opacity(isHovered && isEnabled ? 0.16 : 0),
                radius: isHovered && isEnabled ? 18 : 0,
                x: 0,
                y: isHovered && isEnabled ? 10 : 0
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                if hovering && isEnabled && !cursorIsActive {
                    NSCursor.pointingHand.push()
                    cursorIsActive = true
                } else if (!hovering || !isEnabled) && cursorIsActive {
                    NSCursor.pop()
                    cursorIsActive = false
                }
            }
            .onDisappear {
                guard cursorIsActive else {
                    return
                }
                NSCursor.pop()
                cursorIsActive = false
            }
    }
}

extension View {
    func appInteractiveButton(scaleAmount: CGFloat = 1.018) -> some View {
        modifier(AppInteractiveButtonModifier(scaleAmount: scaleAmount))
    }
}
