//
//  SwiftUIView.swift
//  
//
//  Created by Demirhan Mehmet Atabey on 25.05.2023.
//

import SwiftUI
import SceneKit

public struct GlobeView: View {
  public var dotCount: Int?
  public var dotSize: Float?

  public init() {}

  public init(
    dotCount: Int? = nil,
    dotSize: Float? = nil
  ) {
    self.dotCount = dotCount
    self.dotSize = dotSize
  }

  public var body: some View {
    GlobeViewControllerRepresentable(
      dotCount: dotCount,
      dotSize: dotSize
    )
  }
}


private struct GlobeViewControllerRepresentable: UIViewControllerRepresentable {
    var dotCount: Int?
    var dotSize: Float?
    
    public init(
        dotCount: Int? = nil,
        dotSize: Float? = nil
    ) {
        self.dotCount = dotCount
        self.dotSize = dotSize
    }
    
    public init() {}

    func makeUIViewController(context: Context) -> GlobeViewController {
        let globeController = GlobeViewController(earthRadius: 1, dotCount: dotCount)
        updateGlobeController(globeController)
        return globeController
    }
    
    func updateUIViewController(_ uiViewController: GlobeViewController, context: Context) {
        updateGlobeController(uiViewController)
    }
    
    private func updateGlobeController(_ globeController: GlobeViewController) {
        if let dotSize = dotSize {
            globeController.dotSize = CGFloat(dotSize)
        }
    }
}
