//
//  ViewController.swift
//  App
//
//  Created by Tomoya Hirano on 2020/07/26.
//

import UIKit
import RealityKit
import BlueDress

class ViewController: UIViewController {
    @IBOutlet var arView: ARView!
    let handTracker = HandTracker()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        // Load the "Box" scene from the "Experience" Reality File
//        let boxAnchor = try! Experience.loadBox()
//
//        // Add the box anchor to the scene
//        arView.scene.anchors.append(boxAnchor)
    }
}
