//
//  CategoryManagementView.swift
//  iExpense
//

import SwiftUI
import UniformTypeIdentifiers

struct CategoryManagementView: View {
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var categoryToEdit: FinanceCategory?
    @State private var showingEditor = false
    @State private var targetedCategoryID: String?
    @State private var draggedCategoryID: String?

    private let listRowInsets = EdgeInsets(
        top: InpensoTheme.Space.sm,
        leading: InpensoTheme.Space.screen,
        bottom: InpensoTheme.Space.sm,
        trailing: InpensoTheme.Space.screen
    )

    var body: some View {
        List {
            visibleSection

            if !categoryStore.hiddenCategories.isEmpty {
                hiddenSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AtmosphereBackground())
        .listRowSeparatorTint(InpensoTheme.hairline)
        .navigationTitle("Categories")
        .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(InpensoTheme.ink)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    categoryToEdit = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(InpensoTheme.ink)
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            CategoryEditorView(category: categoryToEdit)
                .environmentObject(categoryStore)
                .environmentObject(settingsViewModel)
        }
    }

    // MARK: - Sections

    private var visibleSection: some View {
        Section {
            ForEach(categoryStore.visibleCategories) { category in
                categoryRow(
                    category,
                    isHidden: false,
                    canReset: !category.isCustom && categoryStore.hasBuiltInOverride(for: category.id)
                )
                .listRowInsets(listRowInsets)
                .listRowBackground(InpensoTheme.panelFill)
                .overlay(alignment: .leading) {
                    if draggedCategoryID != nil && targetedCategoryID == category.id {
                        Rectangle()
                            .fill(InpensoTheme.ink)
                            .frame(height: 2)
                            .padding(.horizontal, InpensoTheme.Space.screen)
                    }
                }
                .onDrag {
                    draggedCategoryID = category.id
                    return NSItemProvider(object: category.id as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: CategoryReorderDropDelegate(
                        destinationCategoryID: category.id,
                        draggedCategoryID: $draggedCategoryID,
                        targetedCategoryID: $targetedCategoryID,
                        moveCategory: { sourceID, destinationID in
                            categoryStore.moveCategory(sourceID, to: destinationID)
                        },
                        clearDragState: clearDragState
                    )
                )
                .onDisappear {
                    if draggedCategoryID == category.id {
                        clearDragState()
                    }
                }
            }
        } header: {
            sectionHeader("Visible", subtitle: "Drag to reorder")
        }
    }

    private var hiddenSection: some View {
        Section {
            ForEach(categoryStore.hiddenCategories) { category in
                categoryRow(
                    category,
                    isHidden: true,
                    canReset: !category.isCustom && categoryStore.hasBuiltInOverride(for: category.id)
                )
                .listRowInsets(listRowInsets)
                .listRowBackground(InpensoTheme.panelFill)
                .opacity(0.72)
            }
        } header: {
            sectionHeader("Hidden", subtitle: nil)
        }
    }

    private func sectionHeader(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.xxs) {
            Text(title)
                .font(InpensoTheme.sectionLabel())
                .foregroundStyle(InpensoTheme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(InpensoTheme.label(12))
                    .foregroundStyle(InpensoTheme.muted)
            }
        }
        .padding(.horizontal, InpensoTheme.Space.screen)
        .padding(.vertical, InpensoTheme.Space.xs)
        .textCase(.none)
        .listRowInsets(EdgeInsets())
        .background(InpensoTheme.foam)
    }

    private func categoryRow(_ category: FinanceCategory, isHidden: Bool, canReset: Bool) -> some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            Image(systemName: category.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(category.color)
                .frame(width: 36, height: 36)
                .background(
                    category.color.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                )

            Text(category.displayName)
                .font(InpensoTheme.body(15, weight: .medium))
                .foregroundStyle(isHidden ? InpensoTheme.muted : InpensoTheme.ink)

            Spacer(minLength: InpensoTheme.Space.xs)

            if isHidden {
                Button("Restore") {
                    restore(category)
                }
                .font(InpensoTheme.label(13, weight: .semibold))
                .foregroundStyle(InpensoTheme.tide)
                .buttonStyle(.plain)
            } else {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(InpensoTheme.muted)

                categoryMenu(category: category, isHidden: isHidden, canReset: canReset)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            edit(category)
        }
    }

    private func categoryMenu(category: FinanceCategory, isHidden: Bool, canReset: Bool) -> some View {
        Menu {
            Button {
                edit(category)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            if isHidden {
                Button {
                    restore(category)
                } label: {
                    Label("Restore", systemImage: "eye")
                }
            } else {
                Button(role: .destructive) {
                    hide(category)
                } label: {
                    Label("Hide", systemImage: "eye.slash")
                }
            }

            if canReset {
                Divider()
                Button(role: .destructive) {
                    categoryStore.resetBuiltInOverride(for: category.id)
                } label: {
                    Label("Reset defaults", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(InpensoTheme.muted)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }

    private func clearDragState() {
        draggedCategoryID = nil
        targetedCategoryID = nil
    }

    private func edit(_ category: FinanceCategory) {
        categoryToEdit = category
        showingEditor = true
    }

    private func hide(_ category: FinanceCategory) {
        categoryStore.hideCategory(category)
        normalizeDefaultCategory()
    }

    private func restore(_ category: FinanceCategory) {
        categoryStore.restoreCategory(category)
    }

    private func normalizeDefaultCategory() {
        let preferredCategoryID = categoryStore.preferredCategoryID(for: settingsViewModel.defaultCategoryID)
        if preferredCategoryID != settingsViewModel.defaultCategoryID {
            settingsViewModel.defaultCategoryID = preferredCategoryID
        }
    }
}

// MARK: - Editor

private struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

    let category: FinanceCategory?

    @State private var name: String
    @State private var iconName: String
    @State private var colorHex: String
    @State private var showingValidation = false

    private let icons = [
        "tag.fill", "briefcase.fill", "banknote.fill", "creditcard.fill",
        "gift.fill", "cart.fill", "fork.knife", "house.fill",
        "car.fill", "tram.fill", "airplane", "heart.fill",
        "cross.case.fill", "book.fill", "graduationcap.fill", "gamecontroller.fill",
        "music.note", "pawprint.fill", "leaf.fill", "hammer.fill"
    ]

    private let colors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#AF52DE", "#FF2D55", "#5856D6", "#00C7BE",
        "#30B0C7", "#FFCC00", "#8E8E93", "#A2845E"
    ]

    init(category: FinanceCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _iconName = State(initialValue: category?.iconName ?? "tag.fill")
        _colorHex = State(initialValue: category?.colorHex ?? "#007AFF")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name", text: $name)
                } header: {
                    editorHeader("Details")
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: InpensoTheme.Space.sm) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(iconName == icon ? .white : InpensoTheme.ink)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                            .fill(iconName == icon ? InpensoTheme.ink : InpensoTheme.mist)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, InpensoTheme.Space.xs)
                    .listRowInsets(EdgeInsets(
                        top: InpensoTheme.Space.sm,
                        leading: InpensoTheme.Space.screen,
                        bottom: InpensoTheme.Space.sm,
                        trailing: InpensoTheme.Space.screen
                    ))
                } header: {
                    editorHeader("Icon")
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: InpensoTheme.Space.sm) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                colorHex = color
                            } label: {
                                RoundedRectangle(cornerRadius: InpensoTheme.Radius.sm, style: .continuous)
                                    .fill(Color(hex: color) ?? InpensoTheme.muted)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if colorHex == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, InpensoTheme.Space.xs)
                    .listRowInsets(EdgeInsets(
                        top: InpensoTheme.Space.sm,
                        leading: InpensoTheme.Space.screen,
                        bottom: InpensoTheme.Space.sm,
                        trailing: InpensoTheme.Space.screen
                    ))
                } header: {
                    editorHeader("Color")
                }

                if let category {
                    Section {
                        if categoryStore.isHidden(category.id) {
                            Button {
                                categoryStore.restoreCategory(category)
                                dismiss()
                            } label: {
                                Label("Restore category", systemImage: "eye")
                            }
                        } else {
                            Button(role: .destructive) {
                                categoryStore.hideCategory(category)
                                normalizeDefaultCategory()
                                dismiss()
                            } label: {
                                Label("Hide from pickers", systemImage: "eye.slash")
                            }
                        }

                        if !category.isCustom && categoryStore.hasBuiltInOverride(for: category.id) {
                            Button(role: .destructive) {
                                categoryStore.resetBuiltInOverride(for: category.id)
                                dismiss()
                            } label: {
                                Label("Reset to defaults", systemImage: "arrow.counterclockwise")
                            }
                        }
                    } header: {
                        editorHeader("Actions")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AtmosphereBackground())
            .listRowBackground(InpensoTheme.panelFill)
            .listRowSeparatorTint(InpensoTheme.hairline)
            .navigationTitle(category == nil ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(InpensoTheme.foam, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(InpensoTheme.ink)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(InpensoTheme.muted)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .font(InpensoTheme.label(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
                }
            }
            .alert("Category name is required", isPresented: $showingValidation) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func editorHeader(_ title: String) -> some View {
        Text(title)
            .font(InpensoTheme.sectionLabel())
            .foregroundStyle(InpensoTheme.muted)
            .textCase(nil)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showingValidation = true
            return
        }

        if var category {
            category.name = trimmedName
            category.iconName = iconName
            category.colorHex = colorHex
            categoryStore.updateCategory(category)
        } else {
            categoryStore.addCategory(name: trimmedName, iconName: iconName, colorHex: colorHex)
        }

        dismiss()
    }

    private func normalizeDefaultCategory() {
        let preferredCategoryID = categoryStore.preferredCategoryID(for: settingsViewModel.defaultCategoryID)
        if preferredCategoryID != settingsViewModel.defaultCategoryID {
            settingsViewModel.defaultCategoryID = preferredCategoryID
        }
    }
}

private struct CategoryReorderDropDelegate: DropDelegate {
    let destinationCategoryID: String
    @Binding var draggedCategoryID: String?
    @Binding var targetedCategoryID: String?
    let moveCategory: (String, String) -> Void
    let clearDragState: () -> Void

    func dropEntered(info: DropInfo) {
        guard let sourceCategoryID = draggedCategoryID,
              sourceCategoryID != destinationCategoryID else {
            return
        }

        targetedCategoryID = destinationCategoryID

        withAnimation(InpensoTheme.Motion.snappy) {
            moveCategory(sourceCategoryID, destinationCategoryID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if targetedCategoryID == destinationCategoryID {
            targetedCategoryID = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        clearDragState()
        return true
    }
}

#Preview {
    NavigationView {
        CategoryManagementView()
            .environmentObject(SettingsViewModel())
            .environmentObject(CategoryStore())
    }
}
