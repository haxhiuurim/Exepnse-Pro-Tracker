//
//  ReceiptScanView.swift
//  iExpense
//
//  Capture or pick a receipt photo, OCR with Vision, review items, save spends.
//

import SwiftUI
import PhotosUI
import UIKit

struct ReceiptScanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var result: ReceiptScanResult?
    @State private var merchantOverride: String = ""
    @State private var saveAsSingle = true
    @State private var animateSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground(intensity: 0.6)

                if let result {
                    reviewContent(result)
                } else {
                    captureContent
                }

                if isScanning {
                    scanningOverlay
                }

                if animateSuccess {
                    successOverlay
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Scan issue", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    showCamera = false
                    if let image {
                        Task { await process(image: image) }
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await process(image: image)
                    }
                }
            }
        }
    }

    // MARK: - Capture

    private var captureContent: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(InpensoTheme.tide.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(InpensoTheme.tide)
                }

                Text("Photograph your receipt")
                    .font(InpensoTheme.brandFont(26, weight: .bold))
                    .foregroundStyle(InpensoTheme.ink)
                    .multilineTextAlignment(.center)

                Text("Inpenso reads items, prices, and totals on-device — nothing leaves your phone.")
                    .font(InpensoTheme.body(15))
                    .foregroundStyle(InpensoTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Take photo", systemImage: "camera.fill")
                }
                .buttonStyle(InpensoPrimaryButtonStyle())

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose from library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(InpensoSecondaryButtonStyle())
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Review

    private func reviewContent(_ result: ReceiptScanResult) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SurfacePanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Merchant")
                                .font(InpensoTheme.label(12, weight: .bold))
                                .foregroundStyle(InpensoTheme.muted)
                            TextField("Store name", text: $merchantOverride)
                                .font(InpensoTheme.body(18, weight: .semibold))
                                .foregroundStyle(InpensoTheme.ink)

                            HStack {
                                Text("Detected total")
                                    .font(InpensoTheme.label(13))
                                    .foregroundStyle(InpensoTheme.muted)
                                Spacer()
                                Text(result.total ?? result.selectedTotal, format: .currency(code: settingsViewModel.selectedCurrency))
                                    .font(InpensoTheme.displayAmount(20))
                                    .foregroundStyle(InpensoTheme.tide)
                            }
                        }
                    }

                    Picker("Save mode", selection: $saveAsSingle) {
                        Text("One spend").tag(true)
                        Text("Each item").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 2)

                    Text(saveAsSingle
                         ? "Saves one grocery spend with the selected total."
                         : "Creates a separate transaction for every checked item.")
                        .font(InpensoTheme.body(13))
                        .foregroundStyle(InpensoTheme.muted)

                    ForEach(Array(result.items.enumerated()), id: \.element.id) { index, item in
                        itemRow(index: index, item: item)
                    }
                }
                .padding(20)
                .padding(.bottom, 100)
            }

            VStack(spacing: 10) {
                HStack {
                    Text("Selected")
                        .font(InpensoTheme.label(13, weight: .semibold))
                        .foregroundStyle(InpensoTheme.muted)
                    Spacer()
                    Text(result.selectedTotal, format: .currency(code: settingsViewModel.selectedCurrency))
                        .font(InpensoTheme.displayAmount(22))
                        .foregroundStyle(InpensoTheme.ink)
                }

                Button(action: saveSelected) {
                    Text(saveAsSingle ? "Save spending" : "Save \(result.items.filter(\.isSelected).count) items")
                }
                .buttonStyle(InpensoPrimaryButtonStyle(enabled: result.selectedTotal > 0))
                .disabled(result.selectedTotal <= 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            if merchantOverride.isEmpty {
                merchantOverride = result.merchant ?? "Receipt"
            }
        }
    }

    private func itemRow(index: Int, item: ReceiptLineItem) -> some View {
        HStack(spacing: 12) {
            Button {
                guard var current = result else { return }
                current.items[index].isSelected.toggle()
                result = current
            } label: {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isSelected ? InpensoTheme.tide : InpensoTheme.muted)
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField("Item", text: Binding(
                    get: { result?.items[index].name ?? item.name },
                    set: { newValue in
                        guard var current = result, current.items.indices.contains(index) else { return }
                        current.items[index].name = newValue
                        result = current
                    }
                ))
                .font(InpensoTheme.body(15, weight: .semibold))

                Text(categoryStore.category(for: item.suggestedCategoryID).displayName)
                    .font(InpensoTheme.label(11))
                    .foregroundStyle(InpensoTheme.muted)
            }

            TextField(
                "0.00",
                text: Binding(
                    get: {
                        String(format: "%.2f", result?.items[index].price ?? item.price)
                    },
                    set: { newValue in
                        guard var current = result, current.items.indices.contains(index) else { return }
                        if let value = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                            current.items[index].price = value
                            result = current
                        }
                    }
                )
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(InpensoTheme.displayAmount(16))
            .frame(width: 72)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(item.isSelected ? 0.85 : 0.45))
        )
        .opacity(item.isSelected ? 1 : 0.55)
    }

    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(InpensoTheme.tide)
                    .scaleEffect(1.3)
                Text("Reading receipt…")
                    .font(InpensoTheme.body(16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(InpensoTheme.surplus)
                Text("Saved")
                    .font(InpensoTheme.brandFont(24))
                    .foregroundStyle(InpensoTheme.ink)
            }
            .padding(32)
            .background(InpensoTheme.foam, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    // MARK: - Actions

    private func process(image: UIImage) async {
        isScanning = true
        defer { isScanning = false }
        do {
            let scanned = try await ReceiptScannerService.shared.scan(image: image)
            await MainActor.run {
                result = scanned
                merchantOverride = scanned.merchant ?? "Receipt"
                HapticFeedback.success()
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                HapticFeedback.error()
            }
        }
    }

    private func saveSelected() {
        guard var current = result else { return }
        let selected = current.items.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        let merchant = merchantOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        let storeName = merchant.isEmpty ? "Receipt" : merchant

        if saveAsSingle {
            let total = selected.reduce(0.0) { $0 + $1.price }
            let categoryID = selected.first?.suggestedCategoryID ?? Category.food.categoryID
            let category = Category.category(from: categoryID) ?? .food
            let notes = selected.map { "\($0.name): \($0.price)" }.joined(separator: "\n")
            _ = viewModel.addExpense(
                title: storeName,
                price: total,
                date: Date(),
                category: category,
                type: .expense,
                categoryID: categoryID,
                notes: notes
            )
        } else {
            let batch = selected.map { item -> Expense in
                let category = Category.category(from: item.suggestedCategoryID) ?? .food
                return Expense(
                    title: item.name,
                    price: item.price,
                    date: Date(),
                    category: category,
                    type: .expense,
                    categoryID: item.suggestedCategoryID,
                    notes: "From \(storeName)"
                )
            }
            viewModel.addExpenses(batch)
        }

        HapticFeedback.success()
        withAnimation { animateSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            dismiss()
        }

        // silence unused mutation warning by touching current
        _ = current
    }
}

// MARK: - Camera wrapper

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void

        init(onImage: @escaping (UIImage?) -> Void) {
            self.onImage = onImage
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImage(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onImage(info[.originalImage] as? UIImage)
        }
    }
}
