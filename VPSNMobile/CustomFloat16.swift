//
//  CustomFloat16.swift
//  VPSNMobile
//
//  Created by Evgeniy Smolyakov on 20.07.2021.
//

import Accelerate

typealias VPS_Float16 = UInt16


func float32to16(_ input: UnsafeMutablePointer<Float>,
                 count: Int) -> [VPS_Float16] {
    var output = [VPS_Float16](repeating: 0, count: count)
    float32to16(input: input, output: &output, count: count)
    return output
}

func float32to16(input: UnsafeMutablePointer<Float>,
                 output: UnsafeMutableRawPointer,
                 count: Int) {
    var bufferFloat32 = vImage_Buffer(data: input, height: 1, width: UInt(count), rowBytes: count * 4)
    var bufferFloat16 = vImage_Buffer(data: output, height: 1, width: UInt(count), rowBytes: count * 2)
    if vImageConvert_PlanarFtoPlanar16F(&bufferFloat32, &bufferFloat16, 0) != kvImageNoError {
        print("Error converting float32 to float16")
    }
}
