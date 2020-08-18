//
//  ViewController.swift
//  App
//
//  Created by Tomoya Hirano on 2020/07/26.
//

import UIKit
import ARKit
import RealityKit
import BlueDress
import simd

class ViewController: UIViewController {
    let arView: ARView = .init(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
    let handTracker = HandTracker()
    let converter = try! YCbCrImageBufferConverter()
    let pointerView: UIView = {
        let v = UIView(frame: .init(x: 0, y: 0, width: 20, height: 20))
        v.backgroundColor = UIColor.red.withAlphaComponent(0.2)
        v.layer.cornerRadius = 10.0
        return v
    }()
    
    let configuration: ARConfiguration = {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            configuration.frameSemantics = .personSegmentation
        }
        return configuration
    }()
    var viewBounds: CGRect = .zero
    let queue = DispatchQueue.global(qos: .background)
    let lowPassFilter = LowPassFilter()
    var count: Int = 0
    let scene = try! Counter.loadScene()
    var labelEntity: Entity { scene.label! }
    var buttonEntity: Entity { scene.button! }
    var isPress: Bool = false {
        didSet {
            if oldValue != isPress {
                if isPress {
                    self.press()
                } else {
                    self.unpress()
                }
            }
        }
    }
    
    override func loadView() {
        super.loadView()
        view.addSubview(arView)
        arView.fillLayout()
        view.addSubview(pointerView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.motionEffects = []
        arView.session.delegate = self
        arView.session.run(configuration, options: .resetTracking)
        
        handTracker?.delegate = self
        handTracker?.startGraph()
        
        arView.scene.addAnchor(scene)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        viewBounds = view.bounds
    }
    
    private func convertScreenLocation(from imageLocation: CGPoint) -> CGPoint {
        let imageResolution = configuration.videoFormat.imageResolution
        let ratio: CGFloat = imageResolution.height / imageResolution.width
        let imageWidthInScreen: CGFloat = viewBounds.height * ratio
        let xOffset: CGFloat = (imageWidthInScreen - viewBounds.width) / 2.0
        
        return CGPoint(
            x: (imageWidthInScreen * imageLocation.x) - xOffset,
            y: viewBounds.height * imageLocation.y
        )
    }
    
    private func unpress() {
        self.scene.notifications.unpress.post()
    }
    
    private func press() {
        self.scene.notifications.press.post()
        count += 1
        changeText("            \(count)") //雑に位置調整
    }
    
    private func changeText(_ text: String) {
        var modelComponent: ModelComponent = labelEntity.children[0].children[0].components[ModelComponent]!
        modelComponent.mesh = .generateText(text,
                                            extrusionDepth: 0.01,
                                            font: .systemFont(ofSize: 0.08),
                                            containerFrame: CGRect.zero,
                                                 alignment: .center,
                                             lineBreakMode: .byCharWrapping)
        labelEntity.children[0].children[0].components.set(modelComponent)
    }
}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        queue.sync {
            let captureImage = frame.capturedImage
            let _captureImage = try! self.converter.convertToBGRA(imageBuffer: captureImage)
            self.handTracker?.processVideoFrame(_captureImage)
        }
    }
}

extension ViewController: TrackerDelegate {
    func handTracker(_ handTracker: HandTracker!, didOutputLandmarks landmarks: [Landmark]!) {
        let indexFinderPosition = landmarks[8]
        let imageLocation = CGPoint(
            x: 1.0 - CGFloat(indexFinderPosition.y),
            y: CGFloat(indexFinderPosition.x)
        )
        let screenLocation = self.convertScreenLocation(from: imageLocation)
        DispatchQueue.main.async {
            self.pointerView.center = screenLocation
            
            if self.arView.entities(at: screenLocation).contains(where: { $0.id == self.buttonEntity.id }) {
                self.isPress = true
            } else {
                self.isPress = false
            }
        }
        
    }
    
    func handTracker(_ handTracker: HandTracker!, didOutputPixelBuffer pixelBuffer: CVPixelBuffer!) {
        
    }
}


class LowPassFilter {
    var previous: SIMD3<Float>? = nil
    
    func filtered(value: SIMD3<Float>) -> SIMD3<Float> {
        if let previous = previous {
            let rate: Float = 0.5
            let output = rate * value + (1.0 - rate) * previous
            self.previous = output
            return output
        } else {
            previous = value
            return value
        }
    }
}

extension matrix_float4x4 {
    var position: SIMD3<Float> {
        SIMD3<Float>.init(x: columns.3.x, y: columns.3.y, z: columns.3.z)
    }
}
