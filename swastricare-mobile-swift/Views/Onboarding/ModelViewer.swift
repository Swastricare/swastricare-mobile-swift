//
//  ModelViewer.swift
//  swastricare-mobile-swift
//
//  Created by Assistant on 06/01/26.
//

import SwiftUI
import SceneKit
import Foundation

struct ModelViewer: UIViewRepresentable {
    let modelName: String
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        
        // Try supported formats in order of preference
        let supportedExtensions = ["usdz", "scn", "dae"]
        var scene: SCNScene? = nil
        
        // First try supported 3D formats
        for ext in supportedExtensions {
            if let url = Bundle.main.url(forResource: modelName, withExtension: ext) {
                do {
                    scene = try SCNScene(url: url, options: nil)
                    break
                } catch {
                    print("Failed to load \(modelName).\(ext): \(error.localizedDescription)")
                }
            }
        }
        
        // If no supported format found, create themed 3D placeholder
        if scene == nil {
            scene = createThemedPlaceholder(for: modelName)
        }
        
        if let loadedScene = scene {
            // Add professional lighting
            addLighting(to: loadedScene)
            
            // Add rotation animation
            let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 8)
            let repeatRotation = SCNAction.repeatForever(rotation)
            loadedScene.rootNode.runAction(repeatRotation)
            
            scnView.scene = loadedScene
        }
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update if needed
    }
    
    // MARK: - Themed 3D Placeholders
    
    private func createThemedPlaceholder(for name: String) -> SCNScene {
        let scene = SCNScene()
        
        switch name {
        case "doc":
            // Health tracking - Heart shape with pulse
            createHealthIcon(in: scene)
        case "love":
            // AI companion - Brain/chip shape
            createAIIcon(in: scene)
        case "vault":
            // Security - Shield/lock shape
            createVaultIcon(in: scene)
        default:
            // Generic sphere
            createDefaultIcon(in: scene)
        }
        
        return scene
    }
    
    private func createHealthIcon(in scene: SCNScene) {
        // Create a stylized heart using spheres
        let containerNode = SCNNode()
        
        // Main heart body (two overlapping spheres at top)
        let leftSphere = SCNSphere(radius: 0.6)
        leftSphere.firstMaterial?.diffuse.contents = UIColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1.0)
        leftSphere.firstMaterial?.specular.contents = UIColor.white
        let leftNode = SCNNode(geometry: leftSphere)
        leftNode.position = SCNVector3(-0.4, 0.3, 0)
        containerNode.addChildNode(leftNode)
        
        let rightSphere = SCNSphere(radius: 0.6)
        rightSphere.firstMaterial?.diffuse.contents = UIColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1.0)
        rightSphere.firstMaterial?.specular.contents = UIColor.white
        let rightNode = SCNNode(geometry: rightSphere)
        rightNode.position = SCNVector3(0.4, 0.3, 0)
        containerNode.addChildNode(rightNode)
        
        // Heart bottom (cone pointing down)
        let cone = SCNCone(topRadius: 0.9, bottomRadius: 0, height: 1.4)
        cone.firstMaterial?.diffuse.contents = UIColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1.0)
        cone.firstMaterial?.specular.contents = UIColor.white
        let coneNode = SCNNode(geometry: cone)
        coneNode.position = SCNVector3(0, -0.4, 0)
        coneNode.eulerAngles = SCNVector3(Float.pi, 0, 0)
        containerNode.addChildNode(coneNode)
        
        // Add pulsing animation
        let scaleUp = SCNAction.scale(to: 1.1, duration: 0.5)
        let scaleDown = SCNAction.scale(to: 1.0, duration: 0.5)
        let pulse = SCNAction.sequence([scaleUp, scaleDown])
        containerNode.runAction(SCNAction.repeatForever(pulse))
        
        scene.rootNode.addChildNode(containerNode)
    }
    
    private func createAIIcon(in scene: SCNScene) {
        let containerNode = SCNNode()
        
        // Central brain/chip - rounded box
        let box = SCNBox(width: 1.2, height: 1.2, length: 0.4, chamferRadius: 0.15)
        box.firstMaterial?.diffuse.contents = UIColor(red: 0.18, green: 0.19, blue: 0.57, alpha: 1.0) // Royal blue
        box.firstMaterial?.specular.contents = UIColor.white
        box.firstMaterial?.emission.contents = UIColor(red: 0.1, green: 0.8, blue: 0.8, alpha: 0.3)
        let boxNode = SCNNode(geometry: box)
        containerNode.addChildNode(boxNode)
        
        // Neural connection points (small spheres around the edges)
        let connectionPositions: [SCNVector3] = [
            SCNVector3(-0.7, 0.4, 0),
            SCNVector3(-0.7, -0.4, 0),
            SCNVector3(0.7, 0.4, 0),
            SCNVector3(0.7, -0.4, 0),
            SCNVector3(0, 0.7, 0),
            SCNVector3(0, -0.7, 0)
        ]
        
        for pos in connectionPositions {
            let sphere = SCNSphere(radius: 0.12)
            sphere.firstMaterial?.diffuse.contents = UIColor(red: 0.1, green: 1.0, blue: 1.0, alpha: 1.0)
            sphere.firstMaterial?.emission.contents = UIColor(red: 0.1, green: 1.0, blue: 1.0, alpha: 0.5)
            let node = SCNNode(geometry: sphere)
            node.position = pos
            containerNode.addChildNode(node)
        }
        
        // Center glow sphere
        let centerGlow = SCNSphere(radius: 0.25)
        centerGlow.firstMaterial?.diffuse.contents = UIColor(red: 0.1, green: 1.0, blue: 1.0, alpha: 0.8)
        centerGlow.firstMaterial?.emission.contents = UIColor(red: 0.1, green: 1.0, blue: 1.0, alpha: 1.0)
        let glowNode = SCNNode(geometry: centerGlow)
        glowNode.position = SCNVector3(0, 0, 0.25)
        containerNode.addChildNode(glowNode)
        
        scene.rootNode.addChildNode(containerNode)
    }
    
    private func createVaultIcon(in scene: SCNScene) {
        let containerNode = SCNNode()
        
        // Shield base
        let shield = SCNBox(width: 1.0, height: 1.2, length: 0.3, chamferRadius: 0.1)
        shield.firstMaterial?.diffuse.contents = UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0)
        shield.firstMaterial?.specular.contents = UIColor.white
        let shieldNode = SCNNode(geometry: shield)
        containerNode.addChildNode(shieldNode)
        
        // Lock body
        let lockBody = SCNBox(width: 0.5, height: 0.4, length: 0.15, chamferRadius: 0.05)
        lockBody.firstMaterial?.diffuse.contents = UIColor(red: 0.9, green: 0.75, blue: 0.3, alpha: 1.0)
        lockBody.firstMaterial?.specular.contents = UIColor.white
        let lockNode = SCNNode(geometry: lockBody)
        lockNode.position = SCNVector3(0, -0.15, 0.2)
        containerNode.addChildNode(lockNode)
        
        // Lock shackle (torus)
        let shackle = SCNTorus(ringRadius: 0.18, pipeRadius: 0.05)
        shackle.firstMaterial?.diffuse.contents = UIColor(red: 0.9, green: 0.75, blue: 0.3, alpha: 1.0)
        shackle.firstMaterial?.specular.contents = UIColor.white
        let shackleNode = SCNNode(geometry: shackle)
        shackleNode.position = SCNVector3(0, 0.15, 0.2)
        shackleNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        containerNode.addChildNode(shackleNode)
        
        // Keyhole
        let keyhole = SCNCylinder(radius: 0.06, height: 0.16)
        keyhole.firstMaterial?.diffuse.contents = UIColor.darkGray
        let keyholeNode = SCNNode(geometry: keyhole)
        keyholeNode.position = SCNVector3(0, -0.2, 0.25)
        containerNode.addChildNode(keyholeNode)
        
        scene.rootNode.addChildNode(containerNode)
    }
    
    private func createDefaultIcon(in scene: SCNScene) {
        let sphere = SCNSphere(radius: 0.8)
        sphere.firstMaterial?.diffuse.contents = UIColor.systemBlue
        sphere.firstMaterial?.specular.contents = UIColor.white
        let node = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(node)
    }
    
    private func addLighting(to scene: SCNScene) {
        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.5, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        // Main directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.color = UIColor(white: 1.0, alpha: 1.0)
        directionalLight.position = SCNVector3(5, 10, 10)
        directionalLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalLight)
        
        // Fill light from below
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.color = UIColor(white: 0.3, alpha: 1.0)
        fillLight.position = SCNVector3(-5, -5, 5)
        fillLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillLight)
    }
}
