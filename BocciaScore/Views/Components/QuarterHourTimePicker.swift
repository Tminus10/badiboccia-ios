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

    /// UIDatePicker's compact style doesn't report a usable intrinsic size to SwiftUI (it collapsed to an
    /// empty, untappable spot), so give SwiftUI the size the picker actually needs.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView picker: UIDatePicker, context: Context) -> CGSize? {
        picker.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
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
