import SwiftUI

/// Full-screen list of sites the availability card measures.
struct ServiceWatchlistView: View {
    var model: ServiceAvailabilityModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode
    @State private var editorRoute: ServiceSiteEditorRoute?

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if model.sites.isEmpty {
                        Text(ui("No sites yet"))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.sites) { site in
                        siteRow(site)
                    }
                    .onDelete { offsets in
                        model.remove(at: offsets)
                    }
                } footer: {
                    Text(ui("Edit to rename a site, change its link, or remove it."))
                }
            }
            .navigationTitle(ui("Sites"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: beginAdd) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(ui("Add a site"))

                    Button(ui("Done")) { dismiss() }
                }
            }
            .sheet(item: $editorRoute) { route in
                ServiceSiteEditor(route: route) { name, link in
                    switch route {
                    case .add:
                        model.addSite(name: name, link: link)
                    case .edit(let site):
                        model.updateSite(id: site.id, name: name, link: link)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func siteRow(_ site: ServiceProbeSite) -> some View {
        if isEditing {
            Button {
                editorRoute = .edit(site)
            } label: {
                siteLabel(site, showsChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            siteLabel(site, showsChevron: false)
        }
    }

    private func siteLabel(_ site: ServiceProbeSite, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(site.name)
                    .foregroundStyle(.primary)
                Text(verbatim: displayLink(site.link))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func beginAdd() {
        editorRoute = .add
    }

    private func displayLink(_ url: String) -> String {
        url.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }
}

enum ServiceSiteEditorRoute: Identifiable {
    case add
    case edit(ServiceProbeSite)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let site):
            site.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .add:
            ui("Add a site")
        case .edit:
            "Edit site"
        }
    }

    var confirmTitle: String {
        switch self {
        case .add:
            "Add"
        case .edit:
            ui("Save")
        }
    }
}

/// Name and link for a watched site. Confirm lives in the toolbar, not in the form.
private struct ServiceSiteEditor: View {
    let route: ServiceSiteEditorRoute
    let onSave: (String, String) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var link: String
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case link
    }

    init(route: ServiceSiteEditorRoute, onSave: @escaping (String, String) -> String?) {
        self.route = route
        self.onSave = onSave
        switch route {
        case .add:
            _name = State(initialValue: "")
            _link = State(initialValue: "")
        case .edit(let site):
            _name = State(initialValue: site.name)
            _link = State(initialValue: Self.editableLink(site.link))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(ui("Name"), text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .link }

                    TextField(
                        "Link",
                        text: $link,
                        prompt: Text(ui("youtube.com")).foregroundStyle(.secondary)
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .textContentType(.none)
                    .foregroundStyle(.primary)
                    .focused($focusedField, equals: .link)
                    .submitLabel(.done)
                    .onSubmit(save)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color(.systemRed))
                    }
                } footer: {
                    Text(ui("Name is optional."))
                }
            }
            .navigationTitle(route.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ui("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(route.confirmTitle, action: save)
                        .disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: link) { _, _ in
                errorMessage = nil
            }
            .onChange(of: name) { _, _ in
                errorMessage = nil
            }
            .onAppear {
                focusedField = route.id == "add" ? .link : .name
            }
        }
    }

    private func save() {
        if let error = onSave(name, link) {
            errorMessage = error
            return
        }
        dismiss()
    }

    private static func editableLink(_ stored: String) -> String {
        stored
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }
}
