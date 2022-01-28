//
//  OverviewView.swift
//  LibreDirect
//

import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack {
            List {
                if store.state.currentGlucose != nil {
                    GlucoseView().frame(maxWidth: .infinity)
                }

                if store.state.isPaired && !store.state.glucoseValues.isEmpty {
                    SnoozeView()
                }

                ChartView()
                ConnectionView()
                SensorView()
            }.listStyle(.grouped)
        }
    }
}
