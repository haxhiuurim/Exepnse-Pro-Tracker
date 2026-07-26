//
//  ReceiptScanView.swift
//  iExpense
//

import SwiftUI
import PhotosUI
import UIKit

struct ReceiptScanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var categoryStore: CategoryStore
    @EnvironmentObject private var pro: ProEntitlementManager
    @ObservedObject var viewModel: ExpenseViewModel

    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var result: ReceiptScanResult?
    @State private var merchantOverride: String = ""
    @State private var saveAsSingle = true
    @State private var animateSuccess = false
    @State private var showLimitPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphereBackground()

                if let result {
                    reviewContent(result)
                } else {
                    captureContent
                }

                if isScanning { scanningOverlay }
                if animateSuccess { successOverlay }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(InpensoTheme.slate)
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
            .alert("Free scans used up", isPresented: $showLimitPaywall) {
                Button("Upgrade") { pro.openPaywall() }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("Free includes \(FreeTierLimits.receiptScansPerMonth) receipt scans per month. Upgrade for unlimited OCR.")
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    showCamera = false
                    if let image { Task { await process(image: image) } }
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
        VStack(spacing: InpensoTheme.Space.section) {
            Spacer()

            VStack(spacing: InpensoTheme.Space.md) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(InpensoTheme.ink)

                VStack(spacing: InpensoTheme.Space.xs) {
                    Text("Photograph your receipt")
                        .font(InpensoTheme.brandFont(22, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)
                        .multilineTextAlignment(.center)

                    Text("Reads items, prices, and totals on-device. Nothing leaves your phone.")
                        .font(InpensoTheme.body(14))
                        .foregroundStyle(InpensoTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, InpensoTheme.Space.screen)

                if !pro.isPro {
                    Text("\(pro.receiptScansRemaining) of \(FreeTierLimits.receiptScansPerMonth) free scans left")
                        .font(InpensoTheme.label(12, weight: .semibold))
                        .foregroundStyle(InpensoTheme.muted)
                }
            }

            VStack(spacing: InpensoTheme.Space.sm) {
                Button { beginCapture { showCamera = true } } label: {
                    Text("Take Photo")
                }
                .buttonStyle(InpensoPrimaryButtonStyle())

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text("Choose from Library")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(InpensoSecondaryButtonStyle())
                .disabled(!pro.canScanReceipt)
                .simultaneousGesture(TapGesture().onEnded {
                    if !pro.canScanReceipt { showLimitPaywall = true }
                })
            }
            .padding(.horizontal, InpensoTheme.Space.screen)

            Spacer()
        }
    }

    private func beginCapture(_ action: () -> Void) {
        guard pro.canScanReceipt else {
            showLimitPaywall = true
            return
        }
        action()
    }

    // MARK: - Review

    private func reviewContent(_ result: ReceiptScanResult) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
                    SurfacePanel {
                        VStack(alignment: .leading, spacing: InpensoTheme.Space.sm) {
                            Text("MERCHANT")
                                .font(InpensoTheme.label(10, weight: .semibold))
                                .foregroundStyle(InpensoTheme.muted)
                            TextField("Store name", text: $merchantOverride)
                                .font(InpensoTheme.body(18, weight: .semibold))
                                .foregroundStyle(InpensoTheme.ink)

                            Divider().overlay(InpensoTheme.hairline)

                            HStack {
                                Text("Detected total")
                                    .font(InpensoTheme.label(12))
                                    .foregroundStyle(InpensoTheme.muted)
                                Spacer()
                                Text(result.total ?? result.selectedTotal, format: .currency(code: settingsViewModel.selectedCurrency))
                                    .font(InpensoTheme.displayAmount(20))
                                    .foregroundStyle(InpensoTheme.tide)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: InpensoTheme.Space.xs) {
                        Text("SAVE MODE")
                            .font(InpensoTheme.label(10, weight: .semibold))
                            .foregroundStyle(InpensoTheme.muted)

                        Picker("Save mode", selection: $saveAsSingle) {
                            Text("One spend").tag(true)
                            Text("Each item").tag(false)
                        }
                        .pickerStyle(.segmented)

                        Text(saveAsSingle
                             ? "Saves one transaction with the selected total."
                             : "Creates a separate transaction for each checked item.")
                            .font(InpensoTheme.body(13))
                            .foregroundStyle(InpensoTheme.muted)
                    }

                    VStack(spacing: InpensoTheme.Space.sm) {
                        ForEach(Array(result.items.enumerated()), id: \.element.id) { index, item in
                            itemRow(index: index, item: item)
                        }
                    }
                }
                .padding(.horizontal, InpensoTheme.Space.screen)
                .padding(.vertical, InpensoTheme.Space.md)
                .padding(.bottom, 100)
            }

            VStack(spacing: InpensoTheme.Space.sm) {
                HStack {
                    Text("Selected")
                        .font(InpensoTheme.label(12, weight: .semibold))
                        .foregroundStyle(InpensoTheme.muted)
                    Spacer()
                    Text(result.selectedTotal, format: .currency(code: settingsViewModel.selectedCurrency))
                        .font(InpensoTheme.displayAmount(22))
                        .foregroundStyle(InpensoTheme.ink)
                }

                Button(action: saveSelected) {
                    Text(saveAsSingle ? "Save Spending" : "Save \(result.items.filter(\.isSelected).count) Items")
                }
                .buttonStyle(InpensoPrimaryButtonStyle(enabled: result.selectedTotal > 0))
                .disabled(result.selectedTotal <= 0)
            }
            .padding(.horizontal, InpensoTheme.Space.screen)
            .padding(.vertical, InpensoTheme.Space.md)
            .background(InpensoTheme.panelFill)
            .overlay(alignment: .top) {
                Rectangle().fill(InpensoTheme.hairline).frame(height: 1)
            }
        }
        .onAppear {
            if merchantOverride.isEmpty {
                merchantOverride = result.merchant ?? "Receipt"
            }
        }
    }

    private func itemRow(index: Int, item: ReceiptLineItem) -> some View {
        HStack(spacing: InpensoTheme.Space.sm) {
            Button {
                guard var current = result else { return }
                current.items[index].isSelected.toggle()
                result = current
            } label: {
                Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(item.isSelected ? InpensoTheme.ink : InpensoTheme.muted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Item", text: Binding(
                    get: { result?.items[index].name ?? item.name },
                    set: { newValue in
                        guard var current = result, current.items.indices.contains(index) else { return }
                        current.items[index].name = newValue
                        result = current
                    }
                ))
                .font(InpensoTheme.body(14, weight: .semibold))

                Text(categoryStore.category(for: item.suggestedCategoryID).displayName)
                    .font(InpensoTheme.label(10))
                    .foregroundStyle(InpensoTheme.muted)
            }

            TextField(
                "0.00",
                text: Binding(
                    get: { String(format: "%.2f", result?.items[index].price ?? item.price) },
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
            .font(InpensoTheme.displayAmount(15))
            .frame(width: 72)
        }
        .padding(InpensoTheme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                        .stroke(InpensoTheme.hairline, lineWidth: 1)
                )
        )
        .opacity(item.isSelected ? 1 : 0.5)
    }

    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: InpensoTheme.Space.md) {
                ProgressView().tint(InpensoTheme.ink).scaleEffect(1.2)
                Text("Reading receipt…")
                    .font(InpensoTheme.body(15, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
            }
            .padding(InpensoTheme.Space.xl)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                    .fill(InpensoTheme.panelFill)
            )
        }
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: InpensoTheme.Space.sm) {
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(InpensoTheme.surplus)
                Text("Saved")
                    .font(InpensoTheme.brandFont(20, weight: .semibold))
                    .foregroundStyle(InpensoTheme.ink)
            }
            .padding(InpensoTheme.Space.xl)
            .background(
                RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                    .fill(InpensoTheme.panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                            .stroke(InpensoTheme.hairline, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Actions

    private func process(image: UIImage) async {
        guard pro.canScanReceipt else {
            await MainActor.run { showLimitPaywall = true }
            return
        }
        isScanning = true
        defer { isScanning = false }
        do {
            let scanned = try await ReceiptScannerService.shared.scan(image: image)
            await MainActor.run {
                pro.recordReceiptScan()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
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
