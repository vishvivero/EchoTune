//
//  SileroVADEngine.swift
//  EchoTune
//
//  Phase 6C: Silero VAD v5 Integration
//  ML-based voice activity detection using Silero VAD v5 ONNX model
//

import Foundation
import CoreML
import AVFoundation

/// Silero VAD v5 Engine for advanced voice activity detection
/// Uses ONNX model from https://github.com/snakers4/silero-vad
class SileroVADEngine {
    static let shared = SileroVADEngine()

    // MARK: - Configuration

    struct Config {
        let sampleRate: Double = 16000.0 // Silero VAD expects 16kHz audio
        let frameSize: Int = 512 // 32ms at 16kHz
        let threshold: Float = 0.5 // Speech probability threshold
        let minSilenceDuration: Int = 0 // frames
        let speechPadMs: Int = 30 // padding around speech segments
    }

    let config = Config()

    // MARK: - Model State

    private var model: MLModel?
    private var isModelLoaded: Bool = false

    // State variables (must persist between calls)
    private var h: MLMultiArray?  // Hidden state
    private var c: MLMultiArray?  // Cell state

    private init() {
        loadModel()
    }

    // MARK: - Model Loading

    /// Load Silero VAD v5 model
    private func loadModel() {
        debugLog("🧠 Silero VAD v5: Model loading...")

        let fileManager = FileManager.default
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDirectory = appSupportDirectory.appendingPathComponent("EchoTune/Models", isDirectory: true)
        let compiledModelName = "silero_vad_v5"
        let compiledModelExtension = "mlmodelc"
        let uncompiledModelName = "silero_vad_v5"
        let uncompiledModelExtension = "mlmodel"

        // 1. Try loading from main bundle
        if let bundleModelURL = Bundle.main.url(forResource: compiledModelName, withExtension: compiledModelExtension) {
            do {
                let compiledModel = try MLModel(contentsOf: bundleModelURL)
                self.model = compiledModel
                initializeState()
                isModelLoaded = true
                debugLog("✅ Silero VAD v5 model loaded successfully from Bundle")
                return
            } catch {
                debugLog("⚠️ Failed to load Silero VAD v5 model from Bundle: \(error)")
            }
        }

        // 2. Try loading from Application Support/EchoTune/Models/silero_vad_v5.mlmodelc
        let appSupportCompiledURL = modelsDirectory.appendingPathComponent("\(compiledModelName).\(compiledModelExtension)")
        if fileManager.fileExists(atPath: appSupportCompiledURL.path) {
            do {
                let compiledModel = try MLModel(contentsOf: appSupportCompiledURL)
                self.model = compiledModel
                initializeState()
                isModelLoaded = true
                debugLog("✅ Silero VAD v5 model loaded successfully from Application Support")
                return
            } catch {
                debugLog("⚠️ Failed to load Silero VAD v5 model from Application Support: \(error)")
            }
        }

        // 3. Try to compile from silero_vad_v5.mlmodel in Application Support if it exists
        let appSupportUncompiledURL = modelsDirectory.appendingPathComponent("\(uncompiledModelName).\(uncompiledModelExtension)")
        if fileManager.fileExists(atPath: appSupportUncompiledURL.path) {
            debugLog("🧠 Silero VAD v5: Found uncompiled model at \(appSupportUncompiledURL.path). Compiling...")
            do {
                let tempCompiledURL = try MLModel.compileModel(at: appSupportUncompiledURL)
                
                // Create directory if it doesn't exist
                try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
                
                // Move compiled model to destination
                if fileManager.fileExists(atPath: appSupportCompiledURL.path) {
                    try? fileManager.removeItem(at: appSupportCompiledURL)
                }
                try fileManager.moveItem(at: tempCompiledURL, to: appSupportCompiledURL)
                
                let compiledModel = try MLModel(contentsOf: appSupportCompiledURL)
                self.model = compiledModel
                initializeState()
                isModelLoaded = true
                debugLog("✅ Silero VAD v5 model compiled and loaded successfully")
                return
            } catch {
                debugLog("❌ Failed to compile/load Silero VAD v5 model: \(error)")
            }
        }

        debugLog("⚠️ Silero VAD v5 model not found or failed to compile/load")
        isModelLoaded = false
    }

    /// Initialize LSTM state variables
    private func initializeState() {
        do {
            // Initialize hidden state (h) and cell state (c)
            // Shape: [2, 1, 64] for Silero VAD v5
            h = try MLMultiArray(shape: [2, 1, 64], dataType: .float32)
            c = try MLMultiArray(shape: [2, 1, 64], dataType: .float32)

            // Zero-initialize
            for i in 0..<h!.count {
                h![i] = 0.0
            }
            for i in 0..<c!.count {
                c![i] = 0.0
            }

            debugLog("🧠 Silero VAD state initialized")
        } catch {
            debugLog("❌ Failed to initialize VAD state: \(error)")
        }
    }

    /// Reset VAD state (call when starting new recording)
    func resetState() {
        initializeState()
        debugLog("🔄 Silero VAD state reset")
    }

    // MARK: - Speech Detection

    /// Detect speech in audio buffer using Silero VAD v5
    /// - Parameter buffer: Audio buffer (will be resampled to 16kHz if needed)
    /// - Returns: Speech probability (0.0 - 1.0)
    func detectSpeech(in buffer: AVAudioPCMBuffer) -> Float {
        guard isModelLoaded, let model = model else {
            debugLog("⚠️ Silero VAD model not loaded, cannot detect speech")
            return 0.0
        }

        // Resample to 16kHz if needed
        let processedBuffer: AVAudioPCMBuffer
        if buffer.format.sampleRate != config.sampleRate {
            guard let resampled = resample(buffer: buffer, to: config.sampleRate) else {
                debugLog("❌ Failed to resample audio")
                return 0.0
            }
            processedBuffer = resampled
        } else {
            processedBuffer = buffer
        }

        // Convert audio to MLMultiArray
        guard let audioArray = convertToMLMultiArray(buffer: processedBuffer) else {
            debugLog("❌ Failed to convert audio to MLMultiArray")
            return 0.0
        }

        // Run inference
        do {
            let input = SileroVADInput(audio: audioArray, h: h!, c: c!, sr: 16000)
            let output = try model.prediction(from: input)

            // Extract speech probability
            guard let outputFeatures = output.featureValue(for: "output"),
                  let probability = outputFeatures.multiArrayValue else {
                debugLog("❌ Failed to extract output from model")
                return 0.0
            }

            let speechProb = probability[0].floatValue

            // Update state for next frame
            if let newH = output.featureValue(for: "hn")?.multiArrayValue {
                h = newH
            }
            if let newC = output.featureValue(for: "cn")?.multiArrayValue {
                c = newC
            }

            return speechProb

        } catch {
            debugLog("❌ Silero VAD inference error: \(error)")
            return 0.0
        }
    }

    // MARK: - Audio Processing Helpers

    /// Resample audio buffer to target sample rate
    private func resample(buffer: AVAudioPCMBuffer, to targetSampleRate: Double) -> AVAudioPCMBuffer? {
        let inputFormat = buffer.format
        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: targetSampleRate,
                                               channels: 1,
                                               interleaved: false) else {
            return nil
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            return nil
        }

        let ratio = targetSampleRate / inputFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                                  frameCapacity: outputFrameCapacity) else {
            return nil
        }

        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if let error = error {
            debugLog("⚠️ Resampling error: \(error)")
            return nil
        }

        return outputBuffer
    }

    /// Convert AVAudioPCMBuffer to MLMultiArray for model input
    private func convertToMLMultiArray(buffer: AVAudioPCMBuffer) -> MLMultiArray? {
        guard let channelData = buffer.floatChannelData else { return nil }

        let frameCount = Int(buffer.frameLength)

        do {
            // Create MLMultiArray with shape [1, frameCount]
            let array = try MLMultiArray(shape: [1, NSNumber(value: frameCount)], dataType: .float32)

            // Copy audio data
            for i in 0..<frameCount {
                array[i] = NSNumber(value: channelData[0][i])
            }

            return array
        } catch {
            debugLog("❌ Failed to create MLMultiArray: \(error)")
            return nil
        }
    }

    // MARK: - Status

    func isReady() -> Bool {
        return isModelLoaded
    }

    func getModelInfo() -> String {
        return """
        Silero VAD v5 Engine
        Status: \(isModelLoaded ? "✅ Ready" : "❌ Not loaded")
        Sample Rate: \(config.sampleRate) Hz
        Frame Size: \(config.frameSize) samples
        Threshold: \(config.threshold)
        """
    }
}

// MARK: - Model Input/Output Helpers

/// Silero VAD v5 model input structure
class SileroVADInput: MLFeatureProvider {
    let audio: MLMultiArray
    let h: MLMultiArray
    let c: MLMultiArray
    let sr: Int

    init(audio: MLMultiArray, h: MLMultiArray, c: MLMultiArray, sr: Int) {
        self.audio = audio
        self.h = h
        self.c = c
        self.sr = sr
    }

    var featureNames: Set<String> {
        return ["input", "h", "c", "sr"]
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "input":
            return MLFeatureValue(multiArray: audio)
        case "h":
            return MLFeatureValue(multiArray: h)
        case "c":
            return MLFeatureValue(multiArray: c)
        case "sr":
            return MLFeatureValue(int64: Int64(sr))
        default:
            return nil
        }
    }
}

// MARK: - Integration Instructions

/*
 To integrate Silero VAD v5:

 1. Download the model:
    wget https://github.com/snakers4/silero-vad/releases/download/v5.0/silero_vad.onnx

 2. Install coremltools:
    pip install coremltools onnx

 3. Convert ONNX to CoreML:
    ```python
    import coremltools as ct
    from coremltools.models.neural_network import quantization_utils

    # Load ONNX model
    model = ct.converters.onnx.convert(
        model='silero_vad.onnx',
        minimum_deployment_target=ct.target.macOS14
    )

    # Save CoreML model
    model.save('silero_vad_v5.mlmodel')
    ```

 4. Add to Xcode:
    - Drag silero_vad_v5.mlmodel into Xcode project
    - Xcode will automatically compile it to .mlmodelc

 5. Update VADManager.swift to use Silero:
    ```swift
    case .sileroVAD:
        let probability = SileroVADEngine.shared.detectSpeech(in: buffer)
        let isSpeech = probability > 0.5
        return SpeechProbability(
            probability: probability,
            timestamp: Date(),
            rmsLevel: 0,
            isSpeech: isSpeech
        )
    ```

 6. Add settings UI to toggle between energy-based and Silero VAD

 Alternative: Use pre-converted CoreML model if available
 Check: https://github.com/snakers4/silero-vad/discussions
*/
