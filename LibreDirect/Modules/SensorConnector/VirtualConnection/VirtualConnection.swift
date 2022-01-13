//
//  VirtualConnection.swift
//  LibreDirect
//

import Combine
import Foundation
import Combine

// MARK: - VirtualLibreConnection

final class VirtualLibreConnection: SensorBLEConnection {
    // MARK: Lifecycle

    init(subject: PassthroughSubject<AppAction, AppError>) {
        AppLog.info("init")
        self.subject = subject
    }

    // MARK: Internal

    weak var subject: PassthroughSubject<AppAction, AppError>?

    func pairSensor() {
        let sensor = Sensor(
            uuid: Data(hexString: "e9ad9b6c79bd93aa")!,
            patchInfo: Data(hexString: "448cd1")!,
            factoryCalibration: FactoryCalibration(i1: 1, i2: 2, i3: 4, i4: 8, i5: 16, i6: 32),
            family: .unknown,
            type: .virtual,
            region: .european,
            serial: "OBIR2PO",
            state: .starting,
            age: initAge,
            lifetime: 24 * 60,
            warmupTime: warmupTime
        )

        sendUpdate(sensor: sensor, wasCoupled: true)
    }

    func connectSensor(sensor: Sensor) {
        let fireDate = Date().toRounded(on: 1, .minute).addingTimeInterval(60)
        let timer = Timer(fire: fireDate, interval: glucoseInterval, repeats: true) { _ in
            AppLog.info("fires at \(Date())")

            self.sendNextGlucose()
        }

        RunLoop.main.add(timer, forMode: .common)

        sendUpdate(connectionState: .connected)
    }

    func disconnectSensor() {
        timer?.invalidate()
        timer = nil

        sendUpdate(connectionState: .disconnected)
    }

    // MARK: Private

    private var initAge = 0
    private var warmupTime = 5
    private var age = 0
    private let glucoseInterval = TimeInterval(60)
    private var sensor: Sensor?
    private var timer: Timer?
    private var direction: VirtualLibreDirection = .up
    private var nextGlucose = 100
    private var nextRotation = 112
    private var lastGlucose = 100

    private func sendNextGlucose() {
        AppLog.info("direction: \(direction)")

        let currentGlucose = nextGlucose
        AppLog.info("currentGlucose: \(currentGlucose)")

        age = age + 1

        sendUpdate(age: age, state: age > warmupTime ? .ready : .starting)

        if age > warmupTime {
            let badQuality: GlucoseQuality = Int.random(in: 0 ..< 100) < 2
                ? .INVALID_DATA
                : .OK

            sendUpdate(sensorSerial: sensor?.serial ?? "", nextReading: SensorReading(id: UUID(), timestamp: Date(), glucoseValue: Double(currentGlucose), quality: badQuality))
        }

        let nextAddition = direction == .up ? 1 : -1

        nextGlucose = currentGlucose + (nextAddition * Int.random(in: 0 ..< 12))
        lastGlucose = currentGlucose

        AppLog.info("nextGlucose: \(nextGlucose)")

        if direction == .up, currentGlucose > nextRotation {
            direction = .down
            nextRotation = Int.random(in: 50 ..< 80)

            AppLog.info("nextRotation: \(nextRotation)")
        } else if direction == .down, currentGlucose < nextRotation {
            direction = .up
            nextRotation = Int.random(in: 160 ..< 240)

            AppLog.info("nextRotation: \(nextRotation)")
        }
    }
}

// MARK: - VirtualLibreDirection

private enum VirtualLibreDirection: String {
    case up = "Up"
    case down = "Down"
}
