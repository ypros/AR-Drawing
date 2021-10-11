
import ARKit

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    
    var arePlanesHidden = true {
        didSet {
            planeNodes.forEach { $0.isHidden = arePlanesHidden }
        }
    }
    
    let configuration = ARWorldTrackingConfiguration()
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    var objectMode: ObjectPlacementMode = .freeform
    
    var objectNodes: [SCNNode] = []
    
    var planeNodes: [SCNNode] = []
    
    var selectedNode: SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadConfiguraion()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
            arePlanesHidden = true
        case 1:
            objectMode = .plane
            arePlanesHidden = false
        case 2:
            objectMode = .image
            arePlanesHidden = true
        default:
            break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
    
    func reloadConfiguraion() {
        objectNodes.forEach { $0.removeFromParentNode() }
        objectNodes.removeAll()
        
        planeNodes.forEach { $0.removeFromParentNode() }
        planeNodes.removeAll()
        
        // Hide all future planes
        arePlanesHidden = false
        
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        print(#function)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first, let selectedNode = selectedNode else { return }
        let point = touch.location(in: sceneView)
        
        switch objectMode {
        case .freeform:
            addNodeInFront(selectedNode)
        case .image:
            break
        case .plane:
            addNode(selectedNode, at: point)
        }
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first, let currentNode = objectNodes.last else { return }
        let location = touch.location(in: sceneView)
        let previousLocation = touch.previousLocation(in: sceneView)
        
        switch objectMode {
        case .freeform:
            rotateNode(currentNode, eulerAngles: SCNVector3(location.x - previousLocation.x, 0, location.y - previousLocation.y))
        case .image:
            break
        case .plane:
            moveNode(currentNode, vector: SCNVector3(location.x - previousLocation.x, 0, location.y - previousLocation.y))
        }
        
        
    }
    
    func addNode(_ node: SCNNode, at point: CGPoint) {
        guard let hitResult = sceneView.hitTest(point, types: .existingPlaneUsingExtent).first else { return }
        guard let anchor = hitResult.anchor as? ARPlaneAnchor, anchor.alignment == .horizontal else { return }
        
        node.simdTransform = hitResult.worldTransform
        addNodeToSceneRoot(node)
    }
    
    func addNode(_ node: SCNNode, to parentNode: SCNNode) {
        let clonedNode = node.clone()
        
        sceneView.scene.rootNode.addChildNode(clonedNode)
        
        objectNodes.append(clonedNode)
    }
    
    func addNodeToSceneRoot(_ node: SCNNode) {
        addNode(node, to: sceneView.scene.rootNode)
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
    
    func moveNode(_ node: SCNNode, vector: SCNVector3) {
        let k: Float = 300
        var translation = matrix_identity_float4x4
        translation.columns.3.x = vector.x / k
        translation.columns.3.y = vector.y / k
        translation.columns.3.z = vector.z / k
        
        node.simdTransform = matrix_multiply(node.simdTransform , translation)
        
    }
    
    func rotateNode(_ node: SCNNode, eulerAngles: SCNVector3) {
        let k: Float = 30
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
}

extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        dismiss(animated: true, completion: nil)
        
        selectedNode = node
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
    }
    
    func undoLastObject() {
        
    }
    
    func resetScene() {
        dismiss(animated: true, completion: nil)
    }
    
}

extension ViewController: ARSCNViewDelegate {
    
    func createFloor(planeAnchor: ARPlaneAnchor) -> SCNNode {
        let extent = planeAnchor.extent
        
        let width = CGFloat(extent.x)
        let height = CGFloat(extent.z)
        
        let plane = SCNPlane(width: width, height: height)
        plane.firstMaterial?.diffuse.contents = UIColor.green
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x -= .pi/2
        planeNode.opacity = 0.15
        
        return planeNode
        
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        let planeNode = createFloor(planeAnchor: anchor)
        planeNodes.append(planeNode)
        
        node.addChildNode(planeNode)
        
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
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        switch anchor {
        case let planeAnchor as ARPlaneAnchor:
            nodeAdded(node, for: planeAnchor)
            print(#function, planeNodes.count)
        default:
            break
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
