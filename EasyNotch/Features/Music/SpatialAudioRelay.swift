import AppKit
import AudioToolbox
import AVFoundation
import CoreMedia

/// Plays Spotify's sound through EasyNotch, so AirPods can apply Spatial Audio to it.
///
/// How it works:
/// 1. A Core Audio "process tap" takes Spotify's sound and mutes Spotify's own copy.
/// 2. A private aggregate device carries the tap, using the output device as its clock.
/// 3. The tapped sound is read in small chunks and played through an
///    `AVSampleBufferAudioRenderer`. Audio played this way can be spatialized.
///
/// Needs macOS 14.2 or later, and the "Screen & System Audio Recording" permission.
/// Audio arrives in real time, so the callbacks must stay quick; the heavy work happens on `queue`.
@available(macOS 14.2, *)
nonisolated final class SpatialAudioRelay: @unchecked Sendable {
    enum Failure: Error {
        case spotifyNotFound
        case unsupportedFormat
        case step(String, OSStatus)
    }

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private let renderer = AVSampleBufferAudioRenderer()
    private let synchronizer = AVSampleBufferRenderSynchronizer()
    /// Everything that touches the renderer runs here, one step at a time.
    private let queue = DispatchQueue(label: "com.seanl.easynotch.spatialaudio")

    // The fields below are read and written only on `queue`, except where `start` sets them up
    // before any audio arrives.
    private var running = false
    private var formatDescription: CMAudioFormatDescription?
    private var sampleRate: Int32 = 48_000
    private var bytesPerFrame = 8
    /// Frames sent so far; gives each chunk its place in time.
    private var framesSent: Int64 = 0
    private var playbackStarted = false

    /// The audio format of the tap. Set before the audio callback starts.
    private var tapFormat = AudioStreamBasicDescription()

    /// Starts relaying Spotify (`spotifyPID`) through the output device `outputUID`.
    func start(spotifyPID: pid_t, outputUID: String) throws {
        do {
            let process = try Self.processObject(for: spotifyPID)

            let description = CATapDescription(stereoMixdownOfProcesses: [process])
            description.muteBehavior = .muted
            description.isPrivate = true
            try Self.check(AudioHardwareCreateProcessTap(description, &tapID), "create the tap")

            tapFormat = try Self.tapFormat(of: tapID)
            guard tapFormat.mFormatID == kAudioFormatLinearPCM,
                  tapFormat.mFormatFlags & kAudioFormatFlagIsFloat != 0,
                  tapFormat.mBitsPerChannel == 32
            else { throw Failure.unsupportedFormat }
            // The chunks we send out are always interleaved 32-bit floats.
            bytesPerFrame = Int(tapFormat.mChannelsPerFrame) * 4
            sampleRate = Int32(tapFormat.mSampleRate)
            let outputFormat = AudioStreamBasicDescription(
                mSampleRate: tapFormat.mSampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                mBytesPerPacket: UInt32(bytesPerFrame),
                mFramesPerPacket: 1,
                mBytesPerFrame: UInt32(bytesPerFrame),
                mChannelsPerFrame: tapFormat.mChannelsPerFrame,
                mBitsPerChannel: 32,
                mReserved: 0
            )
            var format: CMAudioFormatDescription?
            var outputFormatCopy = outputFormat
            try Self.check(
                CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &outputFormatCopy,
                                               layoutSize: 0, layout: nil, magicCookieSize: 0,
                                               magicCookie: nil, extensions: nil, formatDescriptionOut: &format),
                "describe the audio format"
            )
            formatDescription = format

            // A private device that carries the tap and uses the output device as its clock.
            let aggregate: [String: Any] = [
                kAudioAggregateDeviceNameKey: "EasyNotch Spatial Audio",
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

            try Self.check(
                AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, nil) { [weak self] _, input, _, _, _ in
                    self?.receive(input)
                },
                "create the audio callback"
            )
            queue.sync {
                running = true
                framesSent = 0
                playbackStarted = false
                renderer.allowedAudioSpatializationFormats = .monoStereoAndMultichannel
                synchronizer.addRenderer(renderer)
                synchronizer.setRate(0, time: .zero)
            }
            try Self.check(AudioDeviceStart(aggregateID, ioProcID), "start the audio")
        } catch {
            stop()
            throw error
        }
    }

    /// Stops relaying and gives back everything Core Audio handed us. Safe to call more than once.
    func stop() {
        if let ioProcID, aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        self.ioProcID = nil
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        queue.sync {
            running = false
            synchronizer.setRate(0, time: .zero)
            synchronizer.removeRenderer(renderer, at: .zero)
            renderer.flush()
            formatDescription = nil
        }
    }

    // MARK: - Audio

    /// Called by Core Audio many times a second. Copies the chunk and passes it on quickly.
    private func receive(_ input: UnsafePointer<AudioBufferList>) {
        let samples = Self.interleaved(input, format: tapFormat)
        queue.async { [weak self] in self?.enqueue(samples) }
    }

    /// Runs on `queue`: wraps one chunk of samples in a sample buffer and queues it for playback.
    private func enqueue(_ samples: Data) {
        guard running, let formatDescription else { return }
        let frames = samples.count / bytesPerFrame
        guard frames > 0 else { return }

        var block: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: samples.count,
            blockAllocator: nil, customBlockSource: nil, offsetToData: 0,
            dataLength: samples.count, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block
        )
        guard let block else { return }
        samples.withUnsafeBytes { bytes in
            _ = CMBlockBufferReplaceDataBytes(
                with: bytes.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: samples.count
            )
        }

        // Each chunk starts where the previous one ended, so playback never has gaps or overlaps.
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: sampleRate),
            presentationTimeStamp: CMTime(value: framesSent, timescale: sampleRate),
            decodeTimeStamp: .invalid
        )
        var sample: CMSampleBuffer?
        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault, dataBuffer: block, dataReady: true,
            makeDataReadyCallback: nil, refcon: nil, formatDescription: formatDescription,
            sampleCount: frames, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample
        )
        framesSent += Int64(frames)
        if let sample {
            renderer.enqueue(sample)
        }

        // Wait for a fifth of a second of audio before starting, so the first notes don't stutter.
        if !playbackStarted, framesSent >= Int64(sampleRate / 5) {
            playbackStarted = true
            synchronizer.setRate(1, time: .zero)
        }
    }

    /// Turns a chunk from Core Audio into one run of interleaved 32-bit float samples.
    /// Runs on Core Audio's thread, so it only reads and copies.
    private static func interleaved(_ input: UnsafePointer<AudioBufferList>, format: AudioStreamBasicDescription) -> Data {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let channels = Int(format.mChannelsPerFrame)
        let isInterleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
        guard let first = buffers.first, channels > 0 else { return Data() }

        if isInterleaved {
            guard let data = first.mData else { return Data() }
            return Data(bytes: data, count: Int(first.mDataByteSize))
        }

        // One buffer per channel: weave them together, frame by frame.
        let frames = Int(first.mDataByteSize) / 4
        var output = [Float](repeating: 0, count: frames * channels)
        for (channel, buffer) in buffers.enumerated() where channel < channels {
            guard let source = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            for frame in 0..<frames {
                output[frame * channels + channel] = source[frame]
            }
        }
        return output.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    // MARK: - Core Audio helpers

    private static func check(_ status: OSStatus, _ step: String) throws {
        guard status == noErr else { throw Failure.step(step, status) }
    }

    /// The Core Audio process object for a running app, found by its process ID.
    private static func processObject(for pid: pid_t) throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid = pid
        var process = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address,
            UInt32(MemoryLayout<pid_t>.size), &pid, &size, &process
        )
        guard status == noErr, process != kAudioObjectUnknown else { throw Failure.spotifyNotFound }
        return process
    }

    private static func tapFormat(of tap: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(AudioObjectGetPropertyData(tap, &address, 0, nil, &size, &format), "read the tap format")
        return format
    }

    /// The unique ID of the device that plays sound right now, and its name.
    static func defaultOutputDevice() -> (uid: String, name: String)? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown
        else { return nil }
        guard let uid = stringProperty(device, kAudioDevicePropertyDeviceUID),
              let name = stringProperty(device, kAudioObjectPropertyName)
        else { return nil }
        return (uid, name)
    }

    private static func stringProperty(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        // Core Audio hands back a retained CFString, so read it as Unmanaged and take ownership.
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr,
              let value
        else { return nil }
        return value.takeRetainedValue() as String
    }
}
