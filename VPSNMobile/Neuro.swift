

import TensorFlowLite
import UIKit

class Neuro {
    
    /// TensorFlow Lite `Interpreter` object for performing inference on a given model.
    var downloaded = false
    private var interpreter: Interpreter
    
    /// Dedicated DispatchQueue for TF Lite operations.
    private let tfLiteQueue: DispatchQueue
    
    /// TF Lite Model's input and output shapes.
    private let batchSize: Int
    private let inputImageWidth: Int
    private let inputImageHeight: Int
    private let inputPixelSize: Int
    
    
    // MARK: - Initialization
    static func newInstance(path: String, completion: @escaping ((Result<Neuro>) -> Void)) {
        let tfLiteQueue = DispatchQueue(label: "tfliteQueue")
        print("START: newInstance")
        tfLiteQueue.async {
            do {
                print("DEBUG:Create Inrepreter")
                let interpreter = try Interpreter(modelPath: path,
                                                  options: nil,
                                                  delegates: nil)
                print("DEBUG:interpreter, ", interpreter)
                
                try interpreter.allocateTensors()
                let inputShape = try interpreter.input(at: 0).shape
                let outputShape = try interpreter.output(at: 0).shape
                
                let segmentator = Neuro(
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
    
    func run(buf:CVPixelBuffer? = nil, useImage:UIImage? = nil, completion: @escaping ((Result<NResult>) -> Void)) {
        tfLiteQueue.async { [self] in
            var image: UIImage!
            if let ui = useImage {
                image = ui
            } else if let bf = buf {
                image = UIImage.createFromPB(pixelBuffer: bf)!.rotate(radians: .pi/2)!
            } else {
                return
            }
            var outputTensor: Tensor
            
            var gl = [VPSFloat16]()
            var key = [VPSFloat16]()
            var ld = [VPSFloat16]()
            var sc = [VPSFloat16]()
            do {
                let data = image.scaledData(with: CGSize(width: self.inputImageHeight, height: self.inputImageWidth))!
                try self.interpreter.copy(data, toInputAt: 0)
                
                try self.interpreter.invoke()
                _ = try self.interpreter.input(at: 0)
                
                outputTensor = try self.interpreter.output(at: 0)
                var arrayGL = outputTensor.data.toArray(type: Float32.self)
                let float16gl = float32to16(&arrayGL, count: arrayGL.count)
                gl = float16gl
                
                outputTensor = try self.interpreter.output(at: 1)
                var arrayKey = outputTensor.data.toArray(type: Float32.self)
                let float16key = float32to16(&arrayKey, count: arrayKey.count)
                key = float16key
                
                outputTensor = try self.interpreter.output(at: 2)
                var arrayLD = outputTensor.data.toArray(type: Float32.self)
                let float16ld = float32to16(&arrayLD, count: arrayLD.count)
                ld = float16ld
                
                outputTensor = try self.interpreter.output(at: 3)
                var arraySc = outputTensor.data.toArray(type: Float32.self)
                let float16sc = float32to16(&arraySc, count: arraySc.count)
                sc = float16sc
            } catch let error {
                print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.error(SegmentationError.internalError(error)))
                }
                return
            }
            let result = NResult(
                globalDescriptor: gl,
                keypoints: key,
                localDescriptors: ld,
                scores: sc
            )
            
            DispatchQueue.main.async {
                completion(.success(result))
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

