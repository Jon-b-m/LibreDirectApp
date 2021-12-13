//
//  SensorPairing.swift
//  LibreDirect
//
//  Special thanks to: guidos
//

import Combine
import CoreNFC
import Foundation

// MARK: - Libre2Pairing

final class Libre2Pairing: NSObject, NFCTagReaderSessionDelegate {
    // MARK: Internal
    
    func clean() {
        self.updatesHandler = nil
    }
    
    func pairSensor(updatesHandler: @escaping SensorConnectionHandler){
        self.updatesHandler = updatesHandler

        self.session = NFCTagReaderSession(pollingOption: .iso15693, delegate: self, queue: self.nfcQueue)
        self.session?.alertMessage = LocalizedString("Hold the top edge of your iPhone close to the sensor.", comment: "")
        self.session?.begin()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError, readerError.code != .readerSessionInvalidationErrorUserCanceled {
            session.invalidate(errorMessage: "Connection failure: \(readerError.localizedDescription)")

            AppLog.error("Reader session didInvalidateWithError: \(readerError.localizedDescription))")
            self.updatesHandler?(SensorErrorUpdate(errorMessage: readerError.localizedDescription))
        } else {
            AppLog.info("Reader session didInvalidate")
            self.updatesHandler?(SensorConnectorUpdate())
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        Task {
            guard let firstTag = tags.first else {
                AppLog.error("No tag")
                
                self.updatesHandler?(SensorErrorUpdate(errorMessage: "No tag"))
                return
            }

            guard case .iso15693(let tag) = firstTag else {
                AppLog.error("No ISO15693 tag")
                
                self.updatesHandler?(SensorErrorUpdate(errorMessage: "No ISO15693 tag"))
                return
            }

            let blocks = 43
            let requestBlocks = 3

            let requests = Int(ceil(Double(blocks) / Double(requestBlocks)))
            let remainder = blocks % requestBlocks
            var dataArray = [Data](repeating: Data(), count: blocks)

            try await session.connect(to: firstTag)

            let patchInfo = try await tag.customCommand(requestFlags: .highDataRate, customCommandCode: 0xA1, customRequestParameters: Data())
            guard patchInfo.count >= 6 else { // patchInfo should have length 6, which sometimes is not the case, as there are occuring crashes in nfcCommand and Libre2BLEUtilities.streamingUnlockPayload
                AppLog.error("Invalid patchInfo (patchInfo not > 6)")
                
                self.updatesHandler?(SensorErrorUpdate(errorMessage: "Invalid patchInfo (patchInfo not > 6)"))
                return
            }

            let sensorUID = Data(tag.identifier.reversed()) // get sensorUID and patchInfo and send to delegate
            for i in 0 ..< requests {
                let requestFlags: NFCISO15693RequestFlag = [.highDataRate, .address]
                let blockRange = NSRange(UInt8(i * requestBlocks) ... UInt8(i * requestBlocks + (i == requests - 1 ? (remainder == 0 ? requestBlocks : remainder) : requestBlocks) - (requestBlocks > 1 ? 1 : 0)))

                let blockArray = try await tag.readMultipleBlocks(requestFlags: requestFlags, blockRange: blockRange)

                for j in 0 ..< blockArray.count {
                    dataArray[i * requestBlocks + j] = blockArray[j]
                }

                if i == requests - 1 {
                    var fram = Data()

                    for (_, data) in dataArray.enumerated() {
                        if !data.isEmpty {
                            fram.append(data)
                        }
                    }

                    let subCmd: Subcommand = .enableStreaming
                    let cmd = self.nfcCommand(subCmd, unlockCode: self.unlockCode, patchInfo: patchInfo, sensorUID: sensorUID)

                    let streamingCommandResponse = try await tag.customCommand(requestFlags: .highDataRate, customCommandCode: Int(cmd.code), customRequestParameters: cmd.parameters)

                    var streamingEnabled = false
                    if subCmd == .enableStreaming, streamingCommandResponse.count == 6 {
                        streamingEnabled = true
                    }

                    session.invalidate()

                    guard streamingEnabled else {
                        AppLog.error("Streaming not enabled")
                        
                        self.updatesHandler?(SensorErrorUpdate(errorMessage: "Streaming not enabled"))
                        return
                    }

                    let decryptedFram = SensorUtility.decryptFRAM(uuid: sensorUID, patchInfo: patchInfo, fram: fram)
                    if let decryptedFram = decryptedFram {
                        AppLog.info("Success (from decrypted fram)")
                        self.updatesHandler?(SensorUpdate(sensor: Sensor(uuid: sensorUID, patchInfo: patchInfo, fram: decryptedFram)))

                    } else {
                        AppLog.info("Success (from fram)")
                        self.updatesHandler?(SensorUpdate(sensor: Sensor(uuid: sensorUID, patchInfo: patchInfo, fram: fram)))
                    }
                }
            }
        }
    }

    // MARK: Private

    private var session: NFCTagReaderSession?
    private var updatesHandler: SensorConnectionHandler?

    private let nfcQueue = DispatchQueue(label: "libre-direct.nfc-queue")
    private let unlockCode: UInt32 = 42

    private func nfcCommand(_ code: Subcommand, unlockCode: UInt32, patchInfo: Data, sensorUID: Data) -> NFCCommand {
        var parameters = Data([code.rawValue])

        var b: [UInt8] = []
        var y: UInt16

        if code == .enableStreaming {
            // Enables Bluetooth on Libre 2. Returns peripheral MAC address to connect to.
            // unlockCode could be any 32 bit value. The unlockCode and sensor Uid / patchInfo
            // will have also to be provided to the login function when connecting to peripheral.
            b = [
                UInt8(unlockCode & 0xFF),
                UInt8((unlockCode >> 8) & 0xFF),
                UInt8((unlockCode >> 16) & 0xFF),
                UInt8((unlockCode >> 24) & 0xFF)
            ]
            y = UInt16(patchInfo[4 ... 5]) ^ UInt16(b[1], b[0])
        } else {
            y = 0x1B6A
        }

        if !b.isEmpty {
            parameters += b
        }

        if code.rawValue < 0x20 {
            let d = SensorUtility.usefulFunction(uuid: sensorUID, x: UInt16(code.rawValue), y: y)
            parameters += d
        }

        return NFCCommand(code: 0xA1, parameters: parameters)
    }
}

// MARK: - NFCCommand

private struct NFCCommand {
    let code: UInt8
    let parameters: Data
}

// MARK: - Subcommand

private enum Subcommand: UInt8, CustomStringConvertible {
    case activate = 0x1B
    case enableStreaming = 0x1E

    // MARK: Internal

    var description: String {
        switch self {
        case .activate:
            return "activate"
        case .enableStreaming:
            return "enable BLE streaming"
        }
    }
}
