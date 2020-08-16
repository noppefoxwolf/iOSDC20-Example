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
    let handTracker = try! HandTracker()
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
    var pointerEntity: Entity { scene.pointer! }
    var labelEntity: Entity { scene.label! }
    var buttonEntity: Entity { scene.button! }
    
    override func loadView() {
        super.loadView()
        view.addSubview(arView)
        arView.fillLayout()
        view.addSubview(pointerView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        arView.session.delegate = self
        arView.session.run(configuration, options: .resetTracking)
        
        handTracker?.delegate = self
        handTracker?.startGraph()
        
        arView.scene.addAnchor(scene)
        
        /// setup physics
        var physics: PhysicsBodyComponent = pointerEntity.components[PhysicsBodyComponent]!
        physics.mode = .kinematic
        pointerEntity.components.set(physics)
        
        scene.actions.onTap.onAction = { _ in
            self.onTap()
        }
        
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(onGesture(_:)))
        arView.addGestureRecognizer(gesture)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        viewBounds = view.bounds
    }
    
    @objc func onGesture(_ sender: UIPanGestureRecognizer) {
        let location = sender.location(in: arView)
        setTransform(from: location)
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
    
    private func setTransform(from location: CGPoint) {
        DispatchQueue.main.async {
            self.pointerView.center = location
        }
        guard let query = arView.makeRaycastQuery(from: location, allowing: .existingPlaneInfinite, alignment: .horizontal) else { return }
        guard let raycastResult = arView.session.raycast(query).first else { return }
        
        //        self.targetEntity.setTransformMatrix(lowpassTransform, relativeTo: nil)
        let position = lowPassFilter.filtered(value: raycastResult.worldTransform.position)
        pointerEntity.setPosition(position, relativeTo: nil)
        
//        self.targetEntity.setPosition(raycastResult.worldTransform.position, relativeTo: nil)
        
//        DispatchQueue.main.async {
//            let transform = Transform(matrix: raycastResult.worldTransform)
//            self.targetEntity.move(to: transform, relativeTo: nil)
//            self.targetEntity.move(to: raycastResult.worldTransform, relativeTo: nil, duration: 1.0 / 60.0 * 4.0)
//        }
    }
    
    private func onTap() {
        count += 1
        
        var modelComponent: ModelComponent = labelEntity.children[0].children[0].components[ModelComponent]!
        modelComponent.mesh = .generateText("            \(count)", //雑に位置調整
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
        self.setTransform(from: screenLocation)
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
