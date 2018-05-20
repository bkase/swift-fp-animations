//
//  ViewController.swift
//  Animationpresentation
//
//  Created by Brandon Kase on 5/19/18.
//  Copyright © 2018 Brandon Kase. All rights reserved.
//

import UIKit

import Foundation
import AnimationsCore

class CircleMaskView : UIView {
    override init(frame:CGRect) {
        super.init(frame:frame)
        self.isOpaque = false
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func draw(_ rect: CGRect) {
        let con = UIGraphicsGetCurrentContext()
        UIColor.black.setFill()
        con?.fillEllipse(in: rect)
    }
}



class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let driver = Drive(maxSteps: 500)
        
        func circle(x: Int, y: Int, radius: Int) -> UIView {
            let view = UIView(frame: .init(x: x - radius, y: y - radius, width: radius*2, height: radius*2))
            let mask = CircleMaskView(frame:view.bounds)
            view.mask = mask
            return view
        }
        
        let actor = circle(x: 200, y: 200, radius: 100)
        actor.backgroundColor = .blue
        
        let container = UIView(frame: .init(x: 0, y: 0, width: 400, height: 400))
        container.backgroundColor = .white
        container.addSubview(actor)
    
        self.view.addSubview(container)
        
        
        func circleCurve(from: CGFloat, to: CGFloat) -> Animation<CGFloatAverage> {
            
            return
                (linear(from: from, to: to, in: 2)
                    .transformTime(easeInOut) * const(value: CGFloatAverage(to), duration: 0.3))
        }
        
        let growCircle =
            circleCurve(from: 10, to: 200)
                .do { x in
                    let rect = CGRect(origin: .zero, size: CGSize(width: x.avg, height: x.avg))
                    (actor.mask!.frame = rect)
                    (actor.bounds = rect)
        }
        let fadeOut =
            circleCurve(from: 1, to: 0)
                .bind(actor, with: \.alpha)
        
        let final = (growCircle * fadeOut).repeating(count: 1)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            driver.append(animation: final)
            
            Renderer.render(filename: "movie-test", animation: final, fps: 60, canvas: container) {
                print($0)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

