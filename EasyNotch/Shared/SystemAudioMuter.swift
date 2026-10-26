import AudioToolbox
import Foundation

/// Mutes every other app's sound while it's active, so an alarm is the only thing you hear.
///
/// It uses a Core Audio "process tap" that covers all apps except EasyNotch and mutes them.
/// The tap exists only between `mute()` and `unmute()`. Needs macOS 14.2 or later and the
/// "Screen & System Audio Recording" permission (the same one Spatial Audio uses).
@available(macOS 14.2, *)
@MainActor
final class SystemAudioMuter {
    enum Failure: Error {
        case step(String, OSStatus)
    }

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    var isMuting: Bool { tapID != kAudioObjectUnknown }

    /// Starts muting the other apps. Does nothing if already muting.
    func mute() throws {
        guard !isMuting else { return }
        do {
            let ownProcess = try Self.processObject(for: getpid())
            let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [ownProcess])
            description.muteBehavior = .muted
            description.isPrivate = true
            try Self.check(AudioHardwareCreateProcessTap(description, &tapID), "create the tap")

            // A private device that carries the tap and runs it. The output device is its clock.
            let outputUID = try Self.defaultOutputDeviceUID()
            let aggregate: [String: Any] = [
                kAudioAggregateDeviceNameKey: "EasyNotch Alarm Mute",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
                kAudioAggregateDeviceTapListKey: [[
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: description.uuid.uuidString,
                ]],
            ]
            try Self.check(
                AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID),
                "create the aggregate device"
            )
            // The tap only takes effect while the device runs. We don't need its audio.
            try Self.check(
                AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, nil) { _, _, _, _, _ in },
                "create the audio callback"
            )
            try Self.check(AudioDeviceStart(aggregateID, ioProcID), "start the mute")
        } catch {
            unmute()
            throw error
        }
    }

    /// Lets the other apps play again. Safe to call more than once.
    func unmute() {
        if let ioProcID, aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        ioProcID = nil
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    // MARK: - Core Audio helpers

    private static func check(_ status: OSStatus, _ step: String) throws {
        guard status == noErr else { throw Failure.step(step, status) }
    }

    /// The Core Audio process object for a process ID.
    private static func processObject(for pid: pid_t) throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid = pid
        var process = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address,
                UInt32(MemoryLayout<pid_t>.size), &pid, &size, &process
            ),
            "find EasyNotch's audio process"
        )
        return process
    }

    /// The unique ID of the device that plays sound right now.
    private static func defaultOutputDeviceUID() throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device),
            "find the output device"
        )

        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)
        try check(AudioObjectGetPropertyData(device, &uidAddress, 0, nil, &uidSize, &uid), "read the output device")
        return uid as String
    }
}
