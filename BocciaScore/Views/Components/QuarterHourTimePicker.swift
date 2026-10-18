import SwiftUI
import UIKit

/// A compact time picker whose minutes go in quarter hours (00, 15, 30, 45). SwiftUI's
/// DatePicker has no minute interval, so this wraps UIDatePicker. Always in Swiss time.
struct QuarterHourTimePicker: View {
    let title: LocalizedStringKey
    @Binding var selection: Date

    var body: some View {
        LabeledContent(title) {
            CompactTimePicker(selection: $selection)
                .fixedSize()
        }
    }
}

private struct CompactTimePicker: UIViewRepresentable {
    @Binding var selection: Date

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .compact
        picker.minuteInterval = 15
        picker.timeZone = SwissTime.timeZone
        picker.setContentHuggingPriority(.required, for: .horizontal)
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.selection = $selection
        if picker.date != selection {
            picker.date = selection
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    @MainActor
    final class Coordinator: NSObject {
        var selection: Binding<Date>

        init(selection: Binding<Date>) {
            self.selection = selection
        }

        @objc func changed(_ picker: UIDatePicker) {
            selection.wrappedValue = picker.date
        }
    }
}
