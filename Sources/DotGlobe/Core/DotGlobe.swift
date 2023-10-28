//
//  File.swift
//
//
//  Created by Demirhan Mehmet Atabey on 25.05.2023.
//

import Foundation
import SceneKit
import CoreImage
import SwiftUI
import MapKit

public typealias GenericController = UIViewController
public typealias GenericColor = UIColor
public typealias GenericImage = UIImage

public class GlobeViewController: GenericController {
    public var earthNode: SCNNode!
    private var sceneView : SCNView!
    private var cameraNode: SCNNode!

    private var worldMapImage : CGImage {
        guard let path = Bundle.module.path(forResource: "earth-dark", ofType: "jpg") else { fatalError("Could not locate world map image.") }
        guard let image = GenericImage(contentsOfFile: path)?.cgImage else { fatalError() }
        return image
    }

    private lazy var imgData: CFData = {
        guard let imgData = worldMapImage.dataProvider?.data else { fatalError("Could not fetch data from world map image.") }
        return imgData
    }()

    private lazy var worldMapWidth: Int = {
        return worldMapImage.width
    }()

    public let earthRadius: Double = 1.0

    public var dotSize: CGFloat = 0.005 {
        didSet {
            if dotSize != oldValue {
                setupDotGeometry()
            }
        }
    }
    
    public var earthColor: Color = .earthColor {
        didSet {
            if let earthNode = earthNode {
                earthNode.geometry?.firstMaterial?.diffuse.contents = earthColor
            }
        }
    }
    
    public var glowColor: Color = .earthGlow {
        didSet {
            if let earthNode = earthNode {
                earthNode.geometry?.firstMaterial?.emission.contents = glowColor
            }
        }
    }
    
    public var reflectionColor: Color = .earthReflection {
        didSet {
            if let earthNode = earthNode {
                earthNode.geometry?.firstMaterial?.emission.contents = glowColor
            }
        }
    }

    public var glowShininess: CGFloat = 1.0 {
        didSet {
            if let earthNode = earthNode {
                earthNode.geometry?.firstMaterial?.shininess = glowShininess
            }
        }
    }

    private var dotRadius: CGFloat {
        if dotSize > 0 {
             return dotSize
        }
        else {
            return 0.01 * CGFloat(earthRadius) / 1.0
        }
    }

    private var dotCount: Int = 8000

    public init(earthRadius: Double) {
        super.init(nibName: nil, bundle: nil)
    }
    
    public init(earthRadius: Double, dotCount: Int?) {
        self.dotCount = dotCount ?? self.dotCount
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        setupCamera()
        setupGlobe()
        setupDotGeometry()
    }
    
    private func setupScene() {
        let scene = SCNScene()
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sceneView)

        sceneView.scene = scene
        sceneView.allowsCameraControl = false
    }
    
    private func setupCamera() {
        self.cameraNode = SCNNode()
        
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 6)
        cameraNode.camera?.fieldOfView = 25

//        let constraint = SCNLookAtConstraint(target: sceneView.scene?.rootNode)
//        constraint.isGimbalLockEnabled = true  // This prevents any unwanted rotations
//        cameraNode.constraints = [constraint]

        sceneView.scene?.rootNode.addChildNode(cameraNode)
    }
    
    private func setupGlobe() {
        self.earthNode = EarthNode(radius: earthRadius, earthColor: Color(white: 0.1),
                                   earthGlow: Color(white: 0.2),
                                   earthReflection: Color(white: 0.2))
        sceneView.scene?.rootNode.addChildNode(earthNode)
    }
    
    private func setupDotGeometry() {
        let textureMap = generateTextureMap(dots: dotCount, sphereRadius: CGFloat(earthRadius))
//
//        self.generateTextureMap(radius: CGFloat(earthRadius)) { textureMap in

        // New York City
        let newYork = CLLocationCoordinate2D(latitude: 40.7826, longitude: -73.9656)
        let siouxFalls = CLLocationCoordinate2D(latitude: 43.5460, longitude: -96.7313)
        //33.9249° S, 18.4241° E
        let capeTown = CLLocationCoordinate2D(latitude: -33.9249, longitude: 18.4241)
        let newYorkDot = closestDotPosition(to: newYork, in: textureMap)

        let dotColor = GenericColor(white: 1, alpha: 1)
        let oceanColor = GenericColor(cgColor: UIColor.systemRed.cgColor)
        let highlightColor = GenericColor(cgColor: UIColor.systemRed.cgColor)

        // threshold to determine if the pixel in the earth-dark.jpg represents terrain (0.03 represents rgb(7.65,7.65,7.65), which is almost black)
        let threshold: CGFloat = 0.03

        let dotGeometry = SCNSphere(radius: dotRadius)
        dotGeometry.firstMaterial?.diffuse.contents = dotColor
        dotGeometry.firstMaterial?.lightingModel = SCNMaterial.LightingModel.constant

        let highlightGeometry = SCNSphere(radius: dotRadius * 5)
        highlightGeometry.firstMaterial?.diffuse.contents = highlightColor
        highlightGeometry.firstMaterial?.lightingModel = SCNMaterial.LightingModel.constant

        let oceanGeometry = SCNSphere(radius: dotRadius)
        oceanGeometry.firstMaterial?.diffuse.contents = oceanColor
        oceanGeometry.firstMaterial?.lightingModel = SCNMaterial.LightingModel.constant

        var positions = [SCNVector3]()
        var dotNodes = [SCNNode]()

        var highlightedNode: SCNNode? = nil

        for i in 0...textureMap.count - 1 {
            let u = textureMap[i].x
            let v = textureMap[i].y

            let pixelColor = self.getPixelColor(x: Int(u), y: Int(v))
            let isHighlight = u == newYorkDot.x && v == newYorkDot.y

//                guard isHighlight || (pixelColor.red < threshold && pixelColor.green < threshold && pixelColor.blue < threshold) else { continue }

            if (isHighlight) {
                print("FOUND HIGHLIGHT")
                dump(newYorkDot)
            }

            if (isHighlight) {
                let dotNode = SCNNode(geometry: highlightGeometry)
                dotNode.position = textureMap[i].position
                positions.append(dotNode.position)
                dotNodes.append(dotNode)

                highlightedNode = dotNode
            } else if (pixelColor.red < threshold && pixelColor.green < threshold && pixelColor.blue < threshold) {
                let dotNode = SCNNode(geometry: dotGeometry)
                dotNode.position = textureMap[i].position
                positions.append(dotNode.position)
                dotNodes.append(dotNode)
            } else {
//                let dotNode = SCNNode(geometry: oceanGeometry)
//                dotNode.position = textureMap[i].position
//                positions.append(dotNode.position)
//                dotNodes.append(dotNode)
            }

        }

        DispatchQueue.main.async {
            let dotPositions = positions as NSArray
            let dotIndices = NSArray()
            let source = SCNGeometrySource(vertices: dotPositions as! [SCNVector3])
            let element = SCNGeometryElement(indices: dotIndices as! [Int32], primitiveType: .point)

            let pointCloud = SCNGeometry(sources: [source], elements: [element])

            let pointCloudNode = SCNNode(geometry: pointCloud)
            for dotNode in dotNodes {
                pointCloudNode.addChildNode(dotNode)
            }

            self.sceneView.scene?.rootNode.addChildNode(pointCloudNode)

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if let highlightedNode = highlightedNode {
                    self.alignPointToPositiveZ(for: pointCloudNode, targetPoint: highlightedNode.position)
                }
            }
        }
//        }
    }

    

    func alignPointToPositiveZ(for sphereNode: SCNNode, targetPoint: SCNVector3) {
//        // Calculate Yaw (ψ) - Rotation around the node's Y-axis
//        let psi = atan2(targetPoint.y, targetPoint.x)
//
//        // Calculate Pitch (θ) - Rotation around the node's X-axis
//        let r = sqrt(targetPoint.x * targetPoint.x + targetPoint.y * targetPoint.y)
//        let theta = atan2(r, targetPoint.z)
//
//        // Set Euler angles to the sphere node
//        sphereNode.eulerAngles = SCNVector3(-theta, psi, 0)





//        // Reset rotations
//        sphereNode.eulerAngles = SCNVector3(0, 0, 0)
//
//            // Calculate Yaw (around Y-axis)
//            let psi = atan2(targetPoint.x, targetPoint.z)
//
//            // Calculate Pitch (around X-axis) with current Yaw already applied
//            let rotatedTarget = sphereNode.convertPosition(targetPoint, from: nil)
//            let r = sqrt(rotatedTarget.x * rotatedTarget.x + rotatedTarget.z * rotatedTarget.z)
//            let theta = atan2(rotatedTarget.y, r)
//
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            sphereNode.eulerAngles.y = -psi
//        }
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//            sphereNode.eulerAngles.z = -theta
//        }

        // Compute normalized vector from Earth's center to the target point
            let targetDirection = targetPoint.normalized()

            // Compute quaternion rotation
            let up = SCNVector3(0, 0, 1)
            let rotationQuaternion = SCNQuaternion.fromVectorRotate(from: up, to: targetDirection)

            sphereNode.orientation = rotationQuaternion







//        // Calculate Yaw (around Y-axis) - this will rotate the Earth to make the target point face the camera
//        let psi = atan2(targetPoint.x, targetPoint.z)
//
//        // Calculate Pitch (around X-axis)
//        let r = sqrt(targetPoint.x * targetPoint.x + targetPoint.z * targetPoint.z)
//        let theta = atan2(targetPoint.y, r)
//
//            // Set Euler angles to the earth node with North remaining up
//        sphereNode.eulerAngles = SCNVector3(theta, -psi, 0)  // Only yaw is set. Pitch and Roll remain 0
    }

    func centerCameraOnDot(dotPosition: SCNVector3) {
        let targetPhi = atan2(dotPosition.x, dotPosition.z)
        let targetTheta = asin(dotPosition.y / dotPosition.length())

        // Convert spherical coordinates back to Cartesian
        let newX = 1 * sin(targetTheta) * sin(targetPhi)
        let newY = 1 * cos(targetTheta)
        let newZ = 1 * sin(targetTheta) * cos(targetPhi)

        let fixedDistance: Float = 6.0
        let newCameraPosition = SCNVector3(newX, newY, newZ).normalized().scaled(to: fixedDistance)

        let moveAction = SCNAction.move(to: newCameraPosition, duration: 0.3)
        cameraNode.runAction(moveAction)

    }
//
//    private func generateTextureMap(radius: CGFloat, completion: ([(position: SCNVector3, x: Int, y: Int)]) -> ()) {
//        let phi = (sqrt(5.0) + 1.0) / 2.0 - 1.0  // golden ratio
//        let goldenAngle = CGFloat(2.0 * .pi) * phi
//
//        let floatWorldMapImageHeight = CGFloat(worldMapImage.height)
//        let floatWorldMapImageWidth = CGFloat(worldMapImage.width)
//
//        var positions: [(position: SCNVector3, x: Int, y: Int)] = []
//
//        for i in 0..<dotCount {
//            let lat = asin(-1.0 + 2.0 * Double(i) / Double(dotCount))
//            let lon = goldenAngle * CGFloat(i)
//
//            let x = radius * cos(CGFloat(lat)) * cos(lon)
//            let y = radius * cos(CGFloat(lat)) * sin(lon)
//            let z = radius * sin(CGFloat(lat))
//
//            // Convert 3D coordinates (lon, lat) to 2D coordinates on the map
//            let mapX = (lon + .pi) / (2 * .pi) * floatWorldMapImageWidth
//            let mapY = (.pi / 2.0 - CGFloat(lat)) / .pi * floatWorldMapImageHeight
//
//            print("Map X,Y: \(x), \(y)")
//
//            positions.append((position: SCNVector3(x: Float(x), y:Float(y), z: Float(z)), x: Int(mapX), y: Int(mapY)))
//        }
//
//        completion(positions)
//    }

    typealias MapDot = (position: SCNVector3, x: Int, y: Int)

    private func generateTextureMap(dots: Int, sphereRadius: CGFloat) -> [MapDot] {

        let phi = Double.pi * (sqrt(5) - 1)
        var positions = [MapDot]()

        for i in 0..<dots {

            let y = 1.0 - (Double(i) / Double(dots - 1)) * 2.0 // y is 1 to -1
            let radiusY = sqrt(1 - y * y)
            let theta = phi * Double(i) // Golden angle increment
            
            let x = cos(theta) * radiusY
            let z = sin(theta) * radiusY

            let vector = SCNVector3(x: Float(sphereRadius * x),
                                    y: Float(sphereRadius * y),
                                    z: Float(sphereRadius * z))

            let pixel = equirectangularProjection(point: Point3D(x: x, y: y, z: z), 
                                                  imageWidth: 2048,
                                                  imageHeight: 1024)
//            dump(pixel)

            let position = MapDot(position: vector, x: pixel.u, y: pixel.v)
            positions.append(position)
        }
        return positions
    }

    struct Point3D {
        let x: Double
        let y: Double
        let z: Double
    }

    struct Pixel {
        let u: Int
        let v: Int
    }

    func equirectangularProjection(point: Point3D, imageWidth: Int, imageHeight: Int) -> Pixel {
        let theta = asin(point.y)
        let phi = atan2(point.x, point.z)

        let u = Double(imageWidth) / (2.0 * .pi) * (phi + .pi)
        let v = Double(imageHeight) / .pi * (.pi / 2.0 - theta)

        return Pixel(u: Int(u), v: Int(v))
    }

    private func getPixelColor(x: Int, y: Int) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
//        print("GETTING PIXEL DATA FOR (\(x), \(y)")
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(imgData)
        let pixelInfo: Int = ((worldMapWidth * y) + x) * 4

//        return (0, 0, 0, 0)

        let r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
        let g = CGFloat(data[pixelInfo + 1]) / CGFloat(255.0)
        let b = CGFloat(data[pixelInfo + 2]) / CGFloat(255.0)
        let a = CGFloat(data[pixelInfo + 3]) / CGFloat(255.0)

//        print(String(format: "%.2f %.2f %.2f %.2f", r, g, b, a))

        return (r, g, b, a)
    }

    private func distanceBetweenPoints(x1: Int, y1: Int, x2: Int, y2: Int) -> Double {
        let dx = Double(x2 - x1)
        let dy = Double(y2 - y1)
        return sqrt(dx * dx + dy * dy)
    }

    private func closestDotPosition(to coordinate: CLLocationCoordinate2D, in positions: [(position: SCNVector3, x: Int, y: Int)]) -> (x: Int, y: Int) {
        let pixelPositionDouble = getEquirectangularProjectionPosition(for: coordinate)
        let pixelPosition = (x: Int(pixelPositionDouble.x), y: Int(pixelPositionDouble.y))
//        let pixelPosition = (x: 1000, y: 1000)

        print("PIXEL POSITION")
        dump(pixelPosition)

//        positions.forEach {
//            let dist = distanceBetweenPoints(x1: pixelPosition.x, y1: pixelPosition.y, x2: $0.x, y2: $0.y)
////            print("Distance to dot at (\($0.x), \($0.y)) is \(dist)")
//        }

        let nearestDotPosition = positions.min { p1, p2 in
            distanceBetweenPoints(x1: pixelPosition.x, y1: pixelPosition.y, x2: p1.x, y2: p1.y) <
                distanceBetweenPoints(x1: pixelPosition.x, y1: pixelPosition.y, x2: p2.x, y2: p2.y)
        }

        print("NEAREST DOT")
        dump(nearestDotPosition)

        return (x: nearestDotPosition?.x ?? 0, y: nearestDotPosition?.y ?? 0)
    }

    ///     let hues = ["Heliotrope": 296, "Coral": 16, "Aquamarine": 156]
    ///     let leastHue = hues.min { a, b in a.value < b.value }
    ///     print(leastHue)
    ///     // Prints "Optional((key: "Coral", value: 16))"

    /// Convert a coordinate to an (x, y) coordinate on the world map image
    private func getEquirectangularProjectionPosition(
        for coordinate: CLLocationCoordinate2D
    ) -> CGPoint {
        let imageHeight = CGFloat(worldMapImage.height)
        let imageWidth = CGFloat(worldMapImage.width)

        // Normalize longitude to [0, 360). Longitude in MapKit is [-180, 180)
        let normalizedLong = coordinate.longitude + 180
        // Calculate x and y positions
        let xPosition = (normalizedLong / 360) * imageWidth
        // Note: Latitude starts from top, hence the `-` sign
        let yPosition = (-(coordinate.latitude - 90) / 180) * imageHeight
        return CGPoint(x: xPosition, y: yPosition)
    }
}

private extension Color {
    static var earthColor: Color {
        return Color(red: 0.227, green: 0.133, blue: 0.541)
    }
    
    static var earthGlow: Color {
        Color(red: 0.133, green: 0.0, blue: 0.22)
    }
    
    static var earthReflection: Color {
        Color(red: 0.227, green: 0.133, blue: 0.541)
    }
}

extension SCNVector3 {
    func length() -> Float {
        return sqrtf(x*x + y*y + z*z)
    }

    func normalized() -> SCNVector3 {
        let len = length()
        return SCNVector3(x: x/len, y: y/len, z: z/len)
    }

    func scaled(to length: Float) -> SCNVector3 {
        return SCNVector3(x: x * length, y: y * length, z: z * length)
    }

    func dot(_ v: SCNVector3) -> Float {
        return x * v.x + y * v.y + z * v.z
    }

    func cross(_ v: SCNVector3) -> SCNVector3 {
        return SCNVector3(y * v.z - z * v.y, z * v.x - x * v.z, x * v.y - y * v.x)
    }
}

extension SCNQuaternion {
    static func fromVectorRotate(from start: SCNVector3, to end: SCNVector3) -> SCNQuaternion {
        let c = start.cross(end)
        let d = start.dot(end)
        let s = sqrt((1 + d) * 2)
        let invs = 1 / s

        return SCNQuaternion(x: c.x * invs, y: c.y * invs, z: c.z * invs, w: s * 0.5)
    }
}
