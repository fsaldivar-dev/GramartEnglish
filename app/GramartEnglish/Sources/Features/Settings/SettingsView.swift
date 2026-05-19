import SwiftUI
import BackendClient

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedLevel: String
    @Published var showResetConfirm: Bool = false
    @Published var status: String = ""
    private let client: BackendClient
    let onLevelChanged: (String) -> Void
    let onReset: () -> Void

    init(client: BackendClient, initialLevel: String, onLevelChanged: @escaping (String) -> Void, onReset: @escaping () -> Void) {
        self.client = client
        self.selectedLevel = initialLevel
        self.onLevelChanged = onLevelChanged
        self.onReset = onReset
    }

    /// Apply a specific level. Called both by the auto-apply onChange hook
    /// (with the new picker value) and — kept for completeness — directly.
    func applyLevel(_ level: String? = nil) async {
        let target = level ?? selectedLevel
        do {
            let user = try await client.patchMeLevel(target)
            status = "Nivel actualizado a \(user.currentLevel)"
            onLevelChanged(user.currentLevel)
        } catch {
            status = "No se pudo actualizar el nivel: \(error.localizedDescription)"
        }
    }

    func reset() async {
        do {
            _ = try await client.resetMe()
            onReset()
        } catch {
            status = "Reset failed: \(error.localizedDescription)"
        }
    }
}

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    let appVersion: String
    let onClose: () -> Void

    private let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gear") }
            learningTab.tabItem { Label("Aprendizaje", systemImage: "book") }
            accessibilityTab.tabItem { Label("Accesibilidad", systemImage: "accessibility") }
            aboutTab.tabItem { Label("Acerca de", systemImage: "info.circle") }
        }
        .frame(minWidth: 520, minHeight: 380)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Listo", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    private var generalTab: some View {
        Form {
            Section {
                Text("GramartEnglish funciona enteramente en tu Mac. Ningún dato sale del dispositivo.")
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Versión", value: appVersion)
            }
        }
        .padding()
    }

    private var learningTab: some View {
        Form {
            Section("Nivel CEFR") {
                Picker("Nivel actual", selection: $viewModel.selectedLevel) {
                    ForEach(levels, id: \.self) { lvl in Text(lvl).tag(lvl) }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedLevel) { _, newLevel in
                    // Auto-apply on change so users don't have to remember
                    // to press a separate "Aplicar" button. Race-safe: each
                    // call PATCHes, then onLevelChanged refreshes the Home.
                    Task { await viewModel.applyLevel(newLevel) }
                }
                if !viewModel.status.isEmpty {
                    Text(viewModel.status).foregroundStyle(.secondary).font(.caption)
                }
            }
            Section("Borrar progreso") {
                Text("Elimina todas las lecciones, dominio y placement. No se puede deshacer.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Borrar progreso…", role: .destructive) {
                    viewModel.showResetConfirm = true
                }
                .confirmationDialog(
                    "¿Borrar todo el progreso?",
                    isPresented: $viewModel.showResetConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Borrar", role: .destructive) {
                        Task { await viewModel.reset() }
                    }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Lecciones, dominio y placement se eliminan. El vocabulario se conserva.")
                }
            }
        }
        .padding()
    }

    private var accessibilityTab: some View {
        Form {
            Section("Preferencias del sistema respetadas") {
                Label("Etiquetas VoiceOver en cada elemento interactivo", systemImage: "checkmark")
                Label("Navegación por teclado en toda la app", systemImage: "checkmark")
                Label("Dynamic Type escala el texto de la lección", systemImage: "checkmark")
                Label("Reducir movimiento simplifica las transiciones", systemImage: "checkmark")
                Label("Aumentar contraste refuerza el anillo de foco", systemImage: "checkmark")
            }
            Section {
                Text("Las preferencias de accesibilidad siguen al sistema. Para cambiarlas, abre Ajustes del Sistema → Accesibilidad.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .padding()
    }

    private var aboutTab: some View {
        Form {
            Section {
                Text("GramartEnglish te ayuda a practicar vocabulario a tu nivel CEFR. Las funciones de IA usan Ollama, localmente.")
                LabeledContent("Versión", value: appVersion)
                LabeledContent("Sin conexión", value: "Todos los datos se quedan en este Mac")
            }
        }
        .padding()
    }
}
