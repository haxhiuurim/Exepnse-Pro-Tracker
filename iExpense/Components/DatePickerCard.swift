//
//  DatePickerCard.swift
//  iExpense
//

import SwiftUI

struct DatePickerCard: View {
    let title: String
    @Binding var selectedDate: Date
    @Binding var isExpanded: Bool
    var maxDate: Date = Date()
    var dateRange: ClosedRange<Date>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: InpensoTheme.Space.md) {
            Text(title.uppercased())
                .font(InpensoTheme.label(11, weight: .semibold))
                .foregroundStyle(InpensoTheme.muted)
                .padding(.horizontal, InpensoTheme.Space.md)

            Button {
                withAnimation(InpensoTheme.Motion.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: InpensoTheme.Space.sm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)

                    Text(formattedDate())
                        .font(InpensoTheme.body(16, weight: .semibold))
                        .foregroundStyle(InpensoTheme.ink)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(InpensoTheme.muted)
                }
                .padding(.horizontal, InpensoTheme.Space.md)
                .padding(.vertical, InpensoTheme.Space.sm + 2)
                .background(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.md, style: .continuous)
                        .fill(InpensoTheme.mist)
                )
                .padding(.horizontal, InpensoTheme.Space.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Group {
                    if let range = dateRange {
                        DatePicker("", selection: $selectedDate, in: range, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .tint(InpensoTheme.ink)
                            .padding(.horizontal, InpensoTheme.Space.md)
                            .onChange(of: selectedDate) { HapticFeedback.selection() }
                    } else {
                        DatePicker("", selection: $selectedDate, in: ...maxDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .tint(InpensoTheme.ink)
                            .padding(.horizontal, InpensoTheme.Space.md)
                            .onChange(of: selectedDate) { HapticFeedback.selection() }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, InpensoTheme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                .fill(InpensoTheme.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: InpensoTheme.Radius.lg, style: .continuous)
                        .stroke(InpensoTheme.hairline, lineWidth: 1)
                )
        )
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }
}

#Preview {
    ZStack {
        AtmosphereBackground()
        DatePickerCard(
            title: "Date",
            selectedDate: .constant(Date()),
            isExpanded: .constant(false)
        )
        .padding(InpensoTheme.Space.screen)
    }
}
