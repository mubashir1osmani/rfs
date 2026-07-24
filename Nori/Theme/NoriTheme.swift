import SwiftUI

extension Color {
    static let noriBackground = Color(red: 0.03, green: 0.07, blue: 0.055)
    static let noriSurface = Color(red: 0.065, green: 0.11, blue: 0.09)
    static let noriRaised = Color(red: 0.09, green: 0.15, blue: 0.12)
    static let noriBorder = Color(red: 0.16, green: 0.25, blue: 0.21)
    static let noriText = Color(red: 0.95, green: 0.98, blue: 0.96)
    static let noriMuted = Color(red: 0.56, green: 0.64, blue: 0.60)
    static let noriMint = Color(red: 0.66, green: 0.96, blue: 0.78)
    static let noriGreen = Color(red: 0.35, green: 0.85, blue: 0.54)
    static let noriViolet = Color(red: 0.72, green: 0.65, blue: 1.0)
    static let noriPeach = Color(red: 1.0, green: 0.67, blue: 0.57)
    static let noriYellow = Color(red: 0.98, green: 0.82, blue: 0.48)
    static let noriBlue = Color(red: 0.55, green: 0.78, blue: 1.0)
}

extension TaskItem.Category {
    var color: Color {
        switch self {
        case .work: .noriMint
        case .school: .noriViolet
        case .personal: .noriYellow
        }
    }
}

extension AssistantAction.Kind {
    var color: Color {
        switch self {
        case .task: .noriMint
        case .calendar: .noriBlue
        case .meeting: .noriViolet
        case .email: .noriPeach
        }
    }

    var title: String {
        switch self {
        case .task: "NEW TASK"
        case .calendar: "TIME BLOCK"
        case .meeting: "MEETING INVITE"
        case .email: "EMAIL DRAFT"
        }
    }

    var systemImage: String {
        switch self {
        case .task: "checkmark"
        case .calendar: "calendar"
        case .meeting: "person.2"
        case .email: "envelope"
        }
    }
}

struct NoriCardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.noriSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.noriBorder, lineWidth: 1)
            }
    }
}

extension View {
    func noriCard(padding: CGFloat = 16) -> some View {
        modifier(NoriCardModifier(padding: padding))
    }
}
