//
//  TagPickerView.swift
//  iExpense
//

import SwiftUI

struct TagPickerView: View {
    @Binding var tags: [String]
    var suggested: [String]
    var isPro: Bool
    var freeLimit: Int
    var onUpgrade: () -> Void

    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
            Text("Tags")
                .font(InpensoTheme.label(13))
                .foregroundStyle(InpensoTheme.muted)

            if !tags.isEmpty {
                FlowTags(tags: tags) { tag in
                    tags.removeAll { $0 == tag }
                }
            }

            HStack {
                TextField("Add tag", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(addDraft)
                Button("Add", action: addDraft)
                    .font(InpensoTheme.label(13, weight: .bold))
                    .foregroundStyle(InpensoTheme.tide)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(InpensoTheme.Space.md)
            .inpensoPanelBackground(radius: InpensoTheme.Radius.md)

            if !suggested.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggested.filter { !tags.contains($0) }.prefix(8), id: \.self) { tag in
                            Button {
                                append(tag)
                            } label: {
                                Text("#\(tag)")
                                    .font(InpensoTheme.label(12, weight: .semibold))
                                    .foregroundStyle(InpensoTheme.slate)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(InpensoTheme.mist, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !isPro {
                Text("Free · up to \(freeLimit) unique tags across your ledger")
                    .font(InpensoTheme.label(11))
                    .foregroundStyle(InpensoTheme.muted)
            }
        }
    }

    private func addDraft() {
        append(draft)
        draft = ""
    }

    private func append(_ raw: String) {
        let cleaned = Expense.normalizedTags([raw]).first
        guard let cleaned else { return }
        guard !tags.contains(cleaned) else { return }
        if !isPro {
            // Enforce unique-tag ceiling via caller-provided suggested universe size check in parent if needed.
            // Local row still allows tags; save path validates.
        }
        tags.append(cleaned)
        if !isPro, tags.count > freeLimit {
            tags = Array(tags.prefix(freeLimit))
            onUpgrade()
        }
    }
}

private struct FlowTags: View {
    let tags: [String]
    var onRemove: (String) -> Void

    var body: some View {
        FlexibleTagWrap(tags: tags, onRemove: onRemove)
    }
}

/// Simple wrapping HStack substitute using LazyVGrid.
private struct FlexibleTagWrap: View {
    let tags: [String]
    var onRemove: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    onRemove(tag)
                } label: {
                    HStack(spacing: 4) {
                        Text("#\(tag)")
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(InpensoTheme.label(12, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(InpensoTheme.tide.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
