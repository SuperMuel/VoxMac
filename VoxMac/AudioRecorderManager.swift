//
//  AudioRecorderManager.swift
//  VoxMac
//
//  Created by Samuel MALLET on 20/07/2025.
//

import Foundation
import AVFoundation

class AudioRecorderManager: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    
    func startRecording() async throws -> URL {
        guard await requestMicrophonePermission() else {
            throw AudioRecorderError.microphonePermissionDenied
        }
        
        let audioURL = createAudioFileURL()
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            Log.info("Recording started at: \(audioURL.path)", category: .audio)
            return audioURL
        } catch {
            throw AudioRecorderError.failedToStartRecording(error)
        }
    }
    
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder, recorder.isRecording else {
            Log.notice("No active recording to stop", category: .audio)
            return nil
        }
        
        recorder.stop()
        let url = recorder.url
        Log.info("Recording stopped, saved to: \(url.path)", category: .audio)
        return url
    }
    
    private func createAudioFileURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let fileName = "voxmac_recording_\(Date().timeIntervalSince1970).m4a"
        return documentsPath.appendingPathComponent(fileName)
    }
    
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                continuation.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            case .denied, .restricted:
                continuation.resume(returning: false)
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }
}

extension AudioRecorderManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            Log.info("Recording finished successfully", category: .audio)
        } else {
            Log.error("Recording failed", category: .audio)
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            Log.error(error, context: "Recording encode error", category: .audio)
        }
    }
}

enum AudioRecorderError: LocalizedError {
    case microphonePermissionDenied
    case failedToStartRecording(Error)
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        case .failedToStartRecording(let error):
            return "Failed to start recording: \(error.localizedDescription)"
        }
    }
}
