import Foundation

final class Store: ObservableObject {
    private let d = UserDefaults.standard

    @Published var template: String { didSet { d.set(template, forKey: "template") } }
    @Published var contacts: [Contact] {
        didSet { d.set(try? JSONEncoder().encode(contacts), forKey: "contacts") }
    }
    @Published var marked: Set<String> { didSet { d.set(Array(marked), forKey: "marked") } }
    @Published var city: String = ""   // "" = все города

    init() {
        template = d.string(forKey: "template") ?? ""
        marked = Set(d.stringArray(forKey: "marked") ?? [])
        if let data = d.data(forKey: "contacts"),
           let c = try? JSONDecoder().decode([Contact].self, from: data) {
            contacts = c
        } else {
            contacts = []
        }
    }

    var cities: [String] {
        Array(Set(contacts.map(\.city).filter { !$0.isEmpty })).sorted()
    }

    var pending: [Contact] {
        contacts.filter {
            !marked.contains($0.id) &&
            (city.isEmpty || $0.city.lowercased() == city.lowercased())
        }
    }

    func render(_ c: Contact) -> String {
        template
            .replacingOccurrences(of: "{name}", with: c.name)
            .replacingOccurrences(of: "{city}", with: c.city)
    }

    func url(for c: Contact) -> URL? {
        let text = render(c).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return URL(string: "https://t.me/\(c.username)?text=\(text)")
    }
}
