import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            TabView {
                onboardingCard(icon: "timer", title: "Flujo claro", description: "Temporizador limpio, sin distracciones y con transiciones suaves.")
                onboardingCard(icon: "hand.tap", title: "Gestos rápidos", description: "Doble toque para saltar sesión y pulsación larga para cambiar el estilo del reloj.")
                onboardingCard(icon: "checklist", title: "Tareas integradas", description: "Gestiona tareas sin salir del enfoque diario.")
            }
            .tabViewStyle(.page)

            Button("Empezar") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer(minLength: 20)
        }
        .padding()
    }

    private func onboardingCard(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.accent)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(description)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
