//
//  Function.swift
//  VPSNMobile
//
//  Created by Eugene Smolyakov on 20.11.2020.
//

import Foundation

func modelPath(name:String, folder: String) -> URL? {
    guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
    let writePath = NSURL(fileURLWithPath: path).appendingPathComponent(folder) else { return nil }
    try? FileManager.default.createDirectory(atPath: writePath.path, withIntermediateDirectories: true)
    let file = writePath.appendingPathComponent(name)
    if (FileManager.default.fileExists(atPath: file.path)){
        return file
    } else {
        return nil
    }
}

func saveModel(from:URL, name:String, folder: String) -> URL? {
    guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first,
    let writePath = NSURL(fileURLWithPath: path).appendingPathComponent(folder) else { return nil }
    do {
        try FileManager.default.createDirectory(atPath: writePath.path, withIntermediateDirectories: true)
    } catch let error {
        print("err1",error)
    }
    let file = writePath.appendingPathComponent(name)
    if (FileManager.default.fileExists(atPath: file.path)){
         try! FileManager.default.removeItem(atPath: file.path)
    }
    print("from",from.path)
    print("path2",file.path)
    do {
        try FileManager.default.moveItem(at: from, to: file)
        return file
    } catch  let error {
        print("err",error)
        return nil
    }
}
