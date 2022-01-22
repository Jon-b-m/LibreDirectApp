//
//  GlucoseSettingsView.swift
//  LibreDirect
//

import SwiftUI

// MARK: - GlucoseSettingsView

struct GlucoseSettingsView: View {
    // MARK: Internal

    @EnvironmentObject var store: AppStore

    var body: some View {
        Section(
            content: {
                HStack {
                    Text("Glucose unit")
                    Spacer()

                    Picker("", selection: selectedGlucoseUnit) {
                        Text(GlucoseUnit.mgdL.localizedString).tag(GlucoseUnit.mgdL.rawValue)
                        Text(GlucoseUnit.mmolL.localizedString).tag(GlucoseUnit.mmolL.rawValue)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                NumberSelectorView(key: LocalizedString("Lower limit"), value: store.state.alarmLow, step: 5, max: store.state.alarmHigh, displayValue: store.state.alarmLow.asGlucose(unit: store.state.glucoseUnit, withUnit: true)) { value -> Void in
                    store.dispatch(.setAlarmLow(lowerLimit: value))
                }

                NumberSelectorView(key: LocalizedString("Upper limit"), value: store.state.alarmHigh, step: 5, min: store.state.alarmLow, displayValue: store.state.alarmHigh.asGlucose(unit: store.state.glucoseUnit, withUnit: true)) { value -> Void in
                    store.dispatch(.setAlarmHigh(upperLimit: value))
                }
            },
            header: {
                Label("Glucose settings", systemImage: "cross.case")
            }
        )
    }

    // MARK: Private

    private var selectedGlucoseUnit: Binding<String> {
        Binding(
            get: { store.state.glucoseUnit.rawValue },
            set: { store.dispatch(.setGlucoseUnit(unit: GlucoseUnit(rawValue: $0)!)) }
        )
    }
}
