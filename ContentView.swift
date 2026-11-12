import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = Store()
    @State private var picking = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextEditor(text: $store.template).frame(minHeight: 120)
                } header: { Text("Текст сообщения") }
                  footer: { Text("Можно использовать {name} и {city}") }

                Section("Файл контактов") {
                    Button("Выбрать Excel (.xlsx)") { picking = true }
                    if !store.contacts.isEmpty {
                        Text("Получателей в файле: \(store.contacts.count)")
                    }
                    if !store.cities.isEmpty {
                        Picker("Город", selection: $store.city) {
                            Text("Все").tag("")
                            ForEach(store.cities, id: \.self) { Text($0).tag($0) }
                        }
                    }
                }

                if let first = store.pending.first, !store.template.isEmpty {
                    Section("Пример сообщения") { Text(store.render(first)) }
                }

                Section {
                    ForEach(store.pending) { c in row(c) }
                } header: {
                    Text("Осталось: \(store.pending.count) · Отмечено: \(store.marked.count)")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Рассылка")
            .toolbar {
                Menu {
                    Button("Снять все отметки", role: .destructive) { store.marked = [] }
                    Button("Очистить список", role: .destructive) { store.contacts = [] }
                } label: { Image(systemName: "ellipsis.circle") }
            }
            .fileImporter(isPresented: $picking,
                          allowedContentTypes: [UTType(filenameExtension: "xlsx") ?? .data]) { result in
                load(result)
            }
            .alert("Ошибка", isPresented: .constant(errorText != nil)) {
                Button("OK") { errorText = nil }
            } message: { Text(errorText ?? "") }
        }
    }

    private func row(_ c: Contact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(c.name).font(.headline)
            Text("@\(c.username)" + (c.city.isEmpty ? "" : " · \(c.city)"))
                .font(.footnote).foregroundStyle(.secondary)
            HStack {
                if let url = store.url(for: c) {
                    Link(destination: url) { Label("Открыть чат", systemImage: "paperplane") }
                        .buttonStyle(.borderless)
                }
                Spacer()
                Button { store.marked.insert(c.id) } label: {
                    Label("Отметить", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }

    private func load(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let list = try parseXLSX(data: try Data(contentsOf: url))
            if list.isEmpty { errorText = "В файле не найдено получателей с Telegram."; return }
            store.contacts = list
            store.city = ""
        } catch {
            errorText = error.localizedDescription
        }
    }
}
