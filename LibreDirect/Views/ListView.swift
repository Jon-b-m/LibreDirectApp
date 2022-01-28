//
//  ListView.swift
//  LibreDirect
//

import SwiftUI

struct ListView: View {
    // MARK: Internal

    @EnvironmentObject var store: AppStore
    @State var value: Int = 0
    @State var showingAddBloodGlucoseView = false
    @State var showingAddBloodGlucoseAlert = false
    @State var showingDeleteGlucoseValuesAlert = false
    @State var glucoseValues: [Glucose] = []

    var body: some View {
        List {
            if showingAddBloodGlucoseView {
                Section(
                    content: {
                        NumberSelectorView(key: LocalizedString("Now"), value: value, step: 1, displayValue: value.asGlucose(unit: store.state.glucoseUnit, withUnit: true)) { value in
                            self.value = value
                        }
                    },
                    header: {
                        Label("Add glucose value", systemImage: "drop.fill")
                    },
                    footer: {
                        HStack {
                            Button(action: {
                                withAnimation {
                                    showingAddBloodGlucoseView = false
                                }
                            }) {
                                Label("Cancel", systemImage: "multiply")
                            }

                            Spacer()

                            Button(
                                action: {
                                    showingAddBloodGlucoseAlert = true
                                },
                                label: {
                                    Label("Add", systemImage: "checkmark")
                                }
                            ).alert(isPresented: $showingAddBloodGlucoseAlert) {
                                Alert(
                                    title: Text("Are you sure you want to add the new blood glucose value?"),
                                    primaryButton: .destructive(Text("Add")) {
                                        withAnimation {
                                            let glucose = Glucose(id: UUID(), timestamp: Date(), glucose: value, type: .bgm)
                                            store.dispatch(.addGlucoseValues(glucoseValues: [glucose]))

                                            showingAddBloodGlucoseView = false
                                        }
                                    },
                                    secondaryButton: .cancel()
                                )
                            }
                        }
                    }
                )
            }

            Section(
                content: {
                    ForEach(glucoseValues) { glucose in
                        HStack {
                            Text(glucose.timestamp.toLocalDateTime())
                            Spacer()

                            if glucose.type == .bgm {
                                Image(systemName: "drop.fill")
                                    .foregroundColor(Color.ui.red)
                            }

                            if let glucoseValue = glucose.glucoseValue {
                                Text(glucoseValue.asGlucose(unit: store.state.glucoseUnit, withUnit: true, precise: isPrecise(glucose: glucose)))
                                    .if(glucoseValue < store.state.alarmLow || glucoseValue > store.state.alarmHigh) { text in
                                        text.foregroundColor(Color.ui.red)
                                    }
                            } else {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(Color.ui.red)
                            }
                        }
                    }.onDelete { offsets in
                        AppLog.info("onDelete: \(offsets)")

                        let ids = offsets.map { i in
                            glucoseValues[i].id
                        }

                        DispatchQueue.main.async {
                            ids.forEach { id in
                                store.dispatch(.removeGlucose(id: id))
                            }
                        }
                    }
                },
                header: {
                    HStack {
                        Label("Glucose values", systemImage: "drop")
                        Spacer()

                        if !showingAddBloodGlucoseView {
                            Button(
                                action: {
                                    withAnimation {
                                        value = 100
                                        showingAddBloodGlucoseView = true
                                    }
                                },
                                label: {
                                    Label("Add", systemImage: "plus")
                                }
                            )
                        }
                    }
                },
                footer: {
                    if !glucoseValues.isEmpty {
                        Button(
                            action: {
                                showingDeleteGlucoseValuesAlert = true
                            },
                            label: {
                                Label("Delete all", systemImage: "trash.fill")
                            }
                        ).alert(isPresented: $showingDeleteGlucoseValuesAlert) {
                            Alert(
                                title: Text("Are you sure you want to delete all glucose values?"),
                                primaryButton: .destructive(Text("Delete")) {
                                    withAnimation {
                                        store.dispatch(.clearGlucoseValues)
                                    }
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }
                }
            )
        }
        .listStyle(.grouped)
        .onAppear {
            AppLog.info("onAppear")
            self.glucoseValues = store.state.glucoseValues.reversed()
        }
        .onChange(of: store.state.glucoseValues) { glucoseValues in
            AppLog.info("onChange")
            self.glucoseValues = glucoseValues.reversed()
        }
    }

    // MARK: Private

    private func isPrecise(glucose: Glucose) -> Bool {
        if glucose.type == .none {
            return false
        }

        if store.state.glucoseUnit == .mgdL || glucose.type == .bgm {
            return false
        }

        guard let glucoseValue = glucose.glucoseValue else {
            return false
        }

        return glucoseValue.isAlmost(store.state.alarmLow, store.state.alarmHigh)
    }
}
