
import ARKit

class ViewController: UIViewController {

    // MARK: - Variables
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var selectionTransformMenu: UIVisualEffectView!
    
    var arePlanesHidden = true {
        didSet {
            planeNodes.forEach { $0.isHidden = arePlanesHidden }
        }
    }
    
    let configuration = ARWorldTrackingConfiguration()
    
    enum ObjectPlacementMode {
        case freeform, plane, image, transform
    }
    
    enum ObjectTransformMode {
        case move, rotate, scale
    }
    
    var objectMode: ObjectPlacementMode = .freeform
    var transformMode: ObjectTransformMode = .move
    
    var objectNodes: [SCNNode] = []
    
    var planeNodes: [SCNNode] = []
    
    var selectedNode: SCNNode?
    
    var hittedNode: SCNNode? {
        didSet {
            oldValue?.opacity = 1
            hittedNode?.opacity = 0.8
        }
    }
    
    // MARK: - View Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Actions
    
    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        
        switch sender.selectedSegmentIndex {
        
        case 0:
            objectMode = .freeform
        case 1:
            objectMode = .plane
        case 2:
            objectMode = .image
        case 3:
            objectMode = .transform
        default:
            break
        }
        
        hittedNode = nil
        arePlanesHidden = (objectMode != .plane)
        selectionTransformMenu.isHidden = (objectMode != .transform)
        
    }
    
    @IBAction func changeTranformationMode(_ sender: UISegmentedControl) {
        
        switch sender.selectedSegmentIndex {
        
        case 0:
            transformMode = .move
        case 1:
            transformMode = .rotate
        case 2:
            transformMode = .scale
        default:
            break
        }
        
    }
    
    // MARK: - Methods
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
    
    func reloadConfiguration(reset: Bool = false) {
            // Clear objects placed
            objectNodes.forEach { $0.removeFromParentNode() }
            objectNodes.removeAll()
            
            // Clear placed planes
            planeNodes.forEach { $0.removeFromParentNode() }
            planeNodes.removeAll()
            
            // Hide all future planes
            arePlanesHidden = true
            
            // Remove existing anchors if reset is true
            let options: ARSession.RunOptions = reset ? .removeExistingAnchors : []
            
            // Reload configuration
            configuration.detectionImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil)
            configuration.planeDetection = .horizontal
            sceneView.session.run(configuration, options: options)
        }
    
    // MARK: - Touch Methods
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first, let selectedNode = selectedNode else { return }
        let point = touch.location(in: sceneView)
        
        switch objectMode {
        case .freeform:
            addNodeInFront(selectedNode)
        case .image:
            addNodeToImage(selectedNode, at: point)
        case .plane:
            addNodeToPlane(selectedNode, at: point)
        case .transform:
            findNode(at: point)
        }
        
    }
    
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: sceneView)
        let previousLocation = touch.previousLocation(in: sceneView)
        let transformX = location.x - previousLocation.x
        let transformY = location.y - previousLocation.y
        
        switch objectMode {
        case .freeform:
            guard let currentNode = objectNodes.last else { return }
            rotateNode(currentNode, eulerAngles: SCNVector3(transformX, 0, transformY))
            
        case .image:
            break
            
        case .plane:
            guard let currentNode = objectNodes.last else { return }
            moveNode(currentNode, vector: SCNVector3(transformX, 0, transformY))
            
        case .transform:
            guard let currentNode = hittedNode else { return }
            
            switch transformMode {
            
            case .move:
                moveNode(currentNode, vector: SCNVector3(transformX, 0, transformY))
            case .rotate:
                rotateNode(currentNode, eulerAngles: SCNVector3(transformX, 0, transformY))
            case .scale:
                scaleNode(currentNode, vector: SCNVector3(transformX, 0, transformY))
            }
            
        }
        
        
    }
    
    // MARK: - Node Methods
    
    func addNodeToSceneRoot(_ node: SCNNode) {
   
        let clonedNode = node.clone()
        
        sceneView.scene.rootNode.addChildNode(clonedNode)
        
        objectNodes.append(clonedNode)
        
    }
    
    func addNodeToPlane(_ node: SCNNode, at point: CGPoint) {
        
        
        guard let query = sceneView.raycastQuery(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal) else {
            return
        }
        
        let results = sceneView.session.raycast(query)
        guard let hitResult = results.first else {
            print(#line, #function, "No surface found")
            return
        }
        
        guard (hitResult.anchor as? ARPlaneAnchor) != nil else {
            return
        }
        
        node.simdTransform = hitResult.worldTransform
        addNodeToSceneRoot(node)
    }
    
    func addNodeToImage(_ node: SCNNode, at point: CGPoint) {
        guard let result = sceneView.hitTest(point, options: [:]).first else { return }
        guard result.node.name == "image" else { return }
        node.transform = result.node.worldTransform
        node.eulerAngles.x += .pi/2
        addNodeToSceneRoot(node)
    }
    
    func addNodeInFront(_ node: SCNNode) {
        guard let frame = sceneView.session.currentFrame else { return }
        
        let transform = frame.camera.transform
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.5
        
        translation.columns.0.x = 0
        translation.columns.1.y = 0
        translation.columns.0.y = 1
        translation.columns.1.x = -1
        
        
        node.simdTransform = matrix_multiply(transform, translation)
        addNodeToSceneRoot(node)
    }
    
    func findNode(at point: CGPoint) {
        let results = sceneView.hitTest(point, options: [.searchMode : SCNHitTestSearchMode.all.rawValue])
        
        guard let result = results.filter( { $0.node.name != "floor" &&  $0.node.name != "image"}).first else { return }
        
        let hitResult = objectNodes.contains(result.node) ? result.node : result.node.parent
        
        if hittedNode == hitResult {
            hittedNode = nil
        }
        else {
            hittedNode = hitResult
        }
        
    }
    
    // MARK: - Transform Methods
    
    func moveNode(_ node: SCNNode, vector: SCNVector3) {
        guard sceneView.session.currentFrame != nil else { return }
        
        let k: Float = 200
        var translation = matrix_identity_float4x4
        translation.columns.3.x = vector.x / k
        //translation.columns.3.y = vector.y / k
        translation.columns.3.z = vector.z / k
        
        node.simdTransform = matrix_multiply(node.simdTransform , translation)
        
    }
    
    
    func rotateNode(_ node: SCNNode, eulerAngles: SCNVector3) {
        let k: Float = 50
        var translationX = matrix_identity_float4x4
        translationX.columns.1.y = cos(eulerAngles.x / k)
        translationX.columns.1.z = sin(eulerAngles.x / k)
        translationX.columns.2.y = -sin(eulerAngles.x / k)
        translationX.columns.2.z = cos(eulerAngles.x / k)
        
        node.simdTransform = matrix_multiply(node.simdTransform , translationX)
        
        var translationY = matrix_identity_float4x4
        translationY.columns.0.x = cos(eulerAngles.y / k)
        translationY.columns.0.z = -sin(eulerAngles.y / k)
        translationY.columns.2.x = sin(eulerAngles.y / k)
        translationY.columns.2.z = cos(eulerAngles.y / k)
        
        node.simdTransform = matrix_multiply(node.simdTransform , translationY)
        
        var translationZ = matrix_identity_float4x4
        translationZ.columns.0.x = cos(eulerAngles.z / k)
        translationZ.columns.0.y = sin(eulerAngles.z / k)
        translationZ.columns.1.x = -sin(eulerAngles.z / k)
        translationZ.columns.1.y = cos(eulerAngles.z / k)
        
        node.simdTransform = matrix_multiply(node.simdTransform , translationZ)
        
    }
    
    func scaleNode(_ node: SCNNode, vector: SCNVector3) {
        guard sceneView.session.currentFrame != nil else { return }
        
        let size = 1 + (vector.z / 50)

        var translation = matrix_identity_float4x4
        translation.columns.0.x = size
        translation.columns.1.y = size
        translation.columns.2.z = size
        
        node.simdTransform = matrix_multiply(node.simdTransform , translation)
        
    }
    
    
}

extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        dismiss(animated: true, completion: nil)
        
        selectedNode = node
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
        
        guard objectMode == .plane else { return }
        arePlanesHidden.toggle()
    }
    
    func undoLastObject() {
        if let lastObject = objectNodes.last {
            lastObject.removeFromParentNode()
            objectNodes.removeLast()
        } else {
            dismiss(animated: true)
        }
    }
    
    func resetScene() {
        reloadConfiguration(reset: true)
        dismiss(animated: true, completion: nil)
    }
    
}

extension ViewController: ARSCNViewDelegate {
    
    func createFloor(with size: CGSize, opacity: CGFloat = 0.25) -> SCNNode {
            let plane = SCNPlane(width: size.width, height: size.height)
        
            plane.firstMaterial?.diffuse.contents = UIColor.green
            
            let planeNode = SCNNode(geometry: plane)
            planeNode.eulerAngles.x -= .pi/2
            planeNode.opacity = opacity
            
            return planeNode
        }
    
    func updateFloor(for node: SCNNode, anchor: ARPlaneAnchor) {
            guard let planeNode = node.childNodes.first, let plane = planeNode.geometry as? SCNPlane else {
                print(#line, #function, "Can't find SCNPlane at node \(node)")
                return
            }
            
            let extent = anchor.extent
            plane.width = CGFloat(extent.x)
            plane.height = CGFloat(extent.z)
            
            // Position the plane in the center
            planeNode.simdPosition = anchor.center

        }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        let extent = anchor.extent
        let size = CGSize(width: CGFloat(extent.x), height: CGFloat(extent.z))
        let planeNode = createFloor(with: size)
        planeNode.isHidden = arePlanesHidden
        planeNode.name = "floor"
        
        // Add plane node to the list of plane nodes
        planeNodes.append(planeNode)
        
        node.addChildNode(planeNode)
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor) {
        let size = anchor.referenceImage.physicalSize
        let coverNode = createFloor(with: size, opacity: 0.01)
        coverNode.name = "image"
        node.addChildNode(coverNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            switch anchor {
            case let imageAnchor as ARImageAnchor:
                nodeAdded(node, for: imageAnchor)
            case let planeAnchor as ARPlaneAnchor:
                nodeAdded(node, for: planeAnchor)
            default:
                print(#line, #function, "Unknown anchor type \(anchor) is found")
            }
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            switch anchor {
            case is ARImageAnchor:
                break
            case let planeAnchor as ARPlaneAnchor:
                updateFloor(for: node, anchor: planeAnchor)
            default:
                print(#line, #function, "Unknown anchor type \(anchor) is updated")
            }
        }
}
