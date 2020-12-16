//
//  CameraViewController.swift
//  PassioTakeHome
//
//  Created by Justin Brady on 12/14/20.
//  Copyright © 2020 Justin Brady. All rights reserved.
//
// mostly cribbed from https://developer.apple.com/documentation/vision/recognizing_objects_in_live_capture

import Foundation
import UIKit
import AVFoundation
import CoreML
import Vision

class CameraViewController: UIViewController {
    
    private static let kControlHeight = Int(128.0)
    
    private var avCaptureSession: AVCaptureSession!
    private var avCaptureDeviceInput: AVCaptureDeviceInput!
    private var avCaptureOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var previewView: UIView!
    private var captureOutputQueue = DispatchQueue(label: "cameraQueue")
    private var waitingForCapture = false
    
    private var requests = [VNRequest]()
    
    private var infoLabel: UILabel!
    private var controlStackView: UIStackView!

    private var kButtonTop  = Int(64.0)
    private var kButtonLeft  = Int(32.0)
    private let kControlsHeight = CGFloat(128.0)
    
    private var myyModel = ObjectDetector()
    static let kCapturePrefix = "passioCaptureImage"
    
    static var saveDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        return paths[0]
    }
    
    // MARK: -- methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        avCaptureSession = AVCaptureSession()
        
        avCaptureSession?.sessionPreset = .vga640x480
        
        let previewView = UIView(frame: CGRect.zero)
        
        view.addSubview(previewView)
        
        self.previewView = previewView
        
        prepareModel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video),
            let avCaptureDeviceInput = try? AVCaptureDeviceInput(device: backCamera),
            let captureSession = avCaptureSession,
            let previewView = previewView
            else {
                print("Unable to access back camera!")
                return
        }
        
        avCaptureSession?.addInput(avCaptureDeviceInput)
        
        avCaptureOutput.setSampleBufferDelegate(self, queue: captureOutputQueue)
        avCaptureSession?.addOutput(avCaptureOutput)
        
        previewView.frame = view.bounds
    
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        self.previewLayer = previewLayer
        
        previewView.layer.addSublayer(previewLayer)

        previewView.frame = CGRect(x: CGFloat(0), y: CGFloat(kControlsHeight), width: view.bounds.width, height: view.bounds.height)
        
        previewLayer.videoGravity = .resizeAspect
        previewLayer.connection?.videoOrientation = .portrait
        previewView.layer.addSublayer(previewLayer)
        previewLayer.frame = previewView.bounds
        
        avCaptureSession?.startRunning()
        
        // control stack view above camera preview view
        controlStackView = UIStackView()
        controlStackView.translatesAutoresizingMaskIntoConstraints = false
        controlStackView.axis = .vertical
        view.addSubview(controlStackView)
        
        controlStackView.addConstraint(controlStackView.heightAnchor.constraint(equalToConstant: kControlsHeight))
        
        view.addConstraints([
            controlStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 128),
            controlStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // add controls to the stack view
        
        // button for history
        let historyButton = UIButton()
        historyButton.setTitle("History -->", for: .normal)
        historyButton.titleLabel?.textColor = UIColor.blue
        historyButton.frame = CGRect(x: 0, y: 0, width: 128, height: 64)
        historyButton.addTarget(self, action: #selector(onHistory(_:)), for: .touchUpInside)
        controlStackView.addArrangedSubview(historyButton)
        
        // button for capture
        let captureButton = UIButton()
        captureButton.setTitle("Capture", for: .normal)
        captureButton.titleLabel?.textColor = UIColor.blue
        captureButton.frame = CGRect(x: 0, y: 0, width: 128, height: 64)
        captureButton.addTarget(self, action: #selector(onCapture(_:)), for: .touchUpInside)
        controlStackView.addArrangedSubview(captureButton)
        
        // label to indicate visible contents
        infoLabel = UILabel()
        infoLabel.text = "???"
        infoLabel.textColor = UIColor.blue
        infoLabel.frame = CGRect(x: 0, y: 0, width: 128, height: 64)
        controlStackView.addArrangedSubview(infoLabel)
    }
}

// MARK: -- AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
        
        if waitingForCapture {
            waitingForCapture = false
            
            let imageBuffer = CIImage(cvPixelBuffer: pixelBuffer)
            let image = UIImage(ciImage: imageBuffer)
            
            writeImageToDocumentsWithLabel(image)
        }
    }
}

// MARK: -- helpers
extension CameraViewController {
    
    private func prepareModel() {
        // Setup Vision parts
        
        guard let modelURL = Bundle.main.url(forResource: "ObjectDetector", withExtension: "mlmodelc") else {
            fatalError("Model file is missing")
        }
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    // perform all the UI updates on the main queue
                    if let results = request.results {
                        self.drawVisionRequestResults(results)
                    }
                })
            })
            self.requests = [objectRecognition]
        } catch let _ as NSError {
            fatalError("model failed to load")
        }
    }
    
    private func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
    
    private func drawVisionRequestResults(_ results: [Any]) {
        //print("drawVisionRequestResults: \(results)")
        
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        if results.count == 0 {
            infoLabel?.text = "???"
        }
        
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            
            infoLabel?.text = "\(objectObservation.labels.first?.identifier ?? "???")" + "  confidence:\(objectObservation.confidence.significand)"
        }
        
        CATransaction.commit()
    }
}

// MARK: -- button handler
extension CameraViewController {
    
    @objc private func onCapture(_ sender: Any) {
        print("capturing...")
        
        guard let previewBounds = previewView?.bounds else {
            return
        }
        
        waitingForCapture = true
    }
    
    @objc private func onHistory(_ sender: Any) {
        let vc = HistoryViewController()
        self.present(vc, animated: true) {
            // ignored
        }
    }
    
    private func writeImageToDocumentsWithLabel(_ image: UIImage) {
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        if let data = image.jpegData(compressionQuality: 1.0) {
            do {
                let path = documentsURL.appendingPathComponent("\(CameraViewController.kCapturePrefix)+\(Date()).jpg")
                try data.write(to: path)
                print("wrote image data to \(path)")
            }
            catch {
                print("failed to write image data")
            }
        }
    }
}
