

import TensorFlowLite
import UIKit

struct NeuroName {
    static let mnv = "mnv_960x540x1_4096.tflite"
    static let msp = "msp_960x540x1_256_400.tflite"
}

class Neuro {
    var mnv:TFLite?
    var msp:TFLite?
    
    func tfLiteInit(mnv:URL,
                    msp:URL,
                    succes: (() -> Void)?,
                    failure: ((NSError) -> Void)?) {
        let neuroGroup = DispatchGroup()
        var err: NSError?
        
        neuroGroup.enter()
        TFLite.newInstance(path: mnv.path, metalEnabled: false) { result in
            switch result {
            case let .success(segmentator):
                self.mnv = segmentator
            case .error(_):
                err = makeErr(with: Errors.e1)
            }
            neuroGroup.leave()
        }
        
        neuroGroup.enter()
        TFLite.newInstance(path: msp.path, metalEnabled: true) { result in
            switch result {
            case let .success(segmentator):
                self.msp = segmentator
            case .error(_):
                err = makeErr(with: Errors.e1)
            }
            neuroGroup.leave()
        }
        
        neuroGroup.notify(queue: .main) {
            if let er = err {
                failure?(er)
            } else {
                succes?()
            }
        }
    }
    
    func run(buf:CVPixelBuffer? = nil,
             useImage:UIImage? = nil,
             completion: @escaping ((Result<NeuroData>) -> Void)) {
        guard let mnv = mnv, let msp = msp else {
            completion(.error(InitializationError.invalidModel("tflite")))
            return
        }
        var image: UIImage!
        if let ui = useImage {
            image = ui
        } else if let bf = buf {
            image = UIImage.createFromPB(pixelBuffer: bf)!.rotate(radians: .pi/2)!
        } else {
            completion(.error(SegmentationError.invalidImage))
            return
        }
        
        let group = DispatchGroup()
        var gl = [VPSFloat16]()
        var key = [VPSFloat16]()
        var ld = [VPSFloat16]()
        var sc = [VPSFloat16]()
        var errorNeuro:Error?
        group.enter()
        let mspData = image.scaledData(with: CGSize(width: msp.inputImageHeight, height: msp.inputImageWidth), gray: msp.inputPixelSize == 1)!
        msp.run(data: mspData) { res in
            switch res {
            case let .success(segmentationResult):
                key = segmentationResult[0]
                ld = segmentationResult[1]
                sc = segmentationResult[2]
            case let .error(error):
                errorNeuro = error
            }
            group.leave()
        }
        
        var mnvData:Data!
        if mnv.inputPixelSize == msp.inputPixelSize,
           mnv.inputImageHeight == msp.inputImageHeight,
           mnv.inputImageWidth == msp.inputImageWidth {
            mnvData = mspData
        } else {
            mnvData = image.scaledData(with: CGSize(width: mnv.inputImageHeight, height: mnv.inputImageWidth), gray: msp.inputPixelSize == 1)!
        }
        group.enter()
        mnv.run(data: mnvData) { res in
            switch res {
            case let .success(segmentationResult):
                gl = segmentationResult[0]
            case let .error(error):
                errorNeuro = error
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let er = errorNeuro {
                completion(.error(er))
            } else {
                let result = NeuroData(globalDescriptor: gl, keyPoints: key, scores: sc, desc: ld)
                completion(.success(result))
            }
        }
    }
}

class TFLite {
    
    /// TensorFlow Lite `Interpreter` object for performing inference on a given model.
    var downloaded = false
    private var interpreter: Interpreter
    
    /// Dedicated DispatchQueue for TF Lite operations.
    private let tfLiteQueue: DispatchQueue
    
    /// TF Lite Model's input and output shapes.
    private let batchSize: Int
    let inputImageWidth: Int
    let inputImageHeight: Int
    let inputPixelSize: Int
    
    
    // MARK: - Initialization
    static func newInstance(path: String,
                            metalEnabled:Bool = true,
                            completion: @escaping ((Result<TFLite>) -> Void)) {
        let tfLiteQueue = DispatchQueue(label: "tfliteQueue\(UUID().uuidString)")
        print("START: newInstance")
        tfLiteQueue.async {
            var delegates: [Delegate]?
            #if !targetEnvironment(simulator)
                  // Use GPU on real device for inference as this model is fully supported.
            if metalEnabled {
                delegates = [MetalDelegate()]
            }
            #endif
            do {
                print("DEBUG:Create Inrepreter")
                let interpreter = try Interpreter(modelPath: path,
                                                  options: nil,
                                                  delegates: delegates)
                print("DEBUG:interpreter, ", interpreter)
                
                try interpreter.allocateTensors()
                let inputShape = try interpreter.input(at: 0).shape
                let outputShape = try interpreter.output(at: 0).shape
                
                let segmentator = TFLite(
                    tfLiteQueue: tfLiteQueue,
                    interpreter: interpreter,
                    inputShape: inputShape,
                    outputShape: outputShape,
                    downloaded: true
                )
                print("DEBUG:segmentator, ", segmentator)
                DispatchQueue.main.async {
                    completion(.success(segmentator))
                }
            } catch let error {
                print("Failed to create the interpreter with error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.error(InitializationError.internalError(error)))
                }
                return
            }
        }
    }
    
    /// Initialize Image Segmentator instance.
    fileprivate init(
        tfLiteQueue: DispatchQueue,
        interpreter: Interpreter,
        inputShape: Tensor.Shape,
        outputShape: Tensor.Shape,
        downloaded: Bool
    ) {
        // Store TF Lite intepreter
        self.interpreter = interpreter
        
        // Read input shape from model.
        self.batchSize = inputShape.dimensions[0]
        self.inputImageWidth = inputShape.dimensions[1]
        self.inputImageHeight = inputShape.dimensions[2]
        self.inputPixelSize = inputShape.dimensions[3]
        
        self.tfLiteQueue = tfLiteQueue
        
        self.downloaded = downloaded
    }
    
    // MARK: - Image Segmentation
    
    func run(data:Data,
             completion: @escaping ((Result<[[VPSFloat16]]>) -> Void)) {
        tfLiteQueue.async { [self] in
            var outputTensor: Tensor
            
            var answer = [[VPSFloat16]]()
            do {
                
                let date = Date()
                try self.interpreter.copy(data, toInputAt: 0)
                
                try self.interpreter.invoke()
                _ = try self.interpreter.input(at: 0)
                
                for i in 0..<self.interpreter.outputTensorCount {
                    outputTensor = try self.interpreter.output(at: i)
                    var array32 = outputTensor.data.toArray(type: Float32.self)
                    let float16 = float32to16(&array32, count: array32.count)
                    answer.append(float16)
                }
                
            } catch let error {
                print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.error(SegmentationError.internalError(error)))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(answer))
            }
        }
        
    }
}
struct NResult {
    let globalDescriptor: [VPSFloat16]
    let keypoints: [VPSFloat16]
    let localDescriptors: [VPSFloat16]
    let scores: [VPSFloat16]
}

enum Result<T> {
    case success(T)
    case error(Error)
}

enum InitializationError: Error {
    case invalidModel(String)
    
    case internalError(Error)
}

enum SegmentationError: Error {
    case invalidImage
    
    case internalError(Error)
    
    case resultVisualizationError
}

